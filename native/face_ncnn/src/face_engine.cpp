#include "face_ncnn_api.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include "net.h"

namespace {

std::mutex g_mu;
ncnn::Net g_det;
ncnn::Net g_rec;
bool g_ready = false;

constexpr int kEmbDim = 128;
// SCRFD-500m — model detect nhỏ nhất (nihui/ncnn-assets)
constexpr int kDetTarget = 320;  // letterbox; multiple of 32
constexpr float kDetConf = 0.3f;
constexpr float kNmsIou = 0.45f;

struct Face {
  float x1, y1, x2, y2, score;
};

float clampf(float v, float lo, float hi) {
  return std::max(lo, std::min(hi, v));
}

void l2_normalize(float* v, int n) {
  double s = 0;
  for (int i = 0; i < n; i++) s += double(v[i]) * double(v[i]);
  s = std::sqrt(s) + 1e-9;
  for (int i = 0; i < n; i++) v[i] = float(v[i] / s);
}

// insightface SCRFD anchor generator
ncnn::Mat generate_anchors(int base_size, float scale0, float scale1) {
  ncnn::Mat anchors;
  anchors.create(4, 2);
  const float cx = 0.f, cy = 0.f;
  const float ar = 1.f;
  int r_w = (int)std::round(base_size / std::sqrt(ar));
  int r_h = (int)std::round(r_w * ar);
  float scales[2] = {scale0, scale1};
  for (int j = 0; j < 2; j++) {
    float rs_w = r_w * scales[j];
    float rs_h = r_h * scales[j];
    float* a = anchors.row(j);
    a[0] = cx - rs_w * 0.5f;
    a[1] = cy - rs_h * 0.5f;
    a[2] = cx + rs_w * 0.5f;
    a[3] = cy + rs_h * 0.5f;
  }
  return anchors;
}

void generate_proposals(const ncnn::Mat& anchors, int feat_stride,
                        const ncnn::Mat& score_blob, const ncnn::Mat& bbox_blob,
                        float prob_threshold, std::vector<Face>& out) {
  const int w = score_blob.w;
  const int h = score_blob.h;
  const int num_anchors = anchors.h;

  for (int q = 0; q < num_anchors; q++) {
    const float* anchor = anchors.row(q);
    const ncnn::Mat score = score_blob.channel(q);
    const ncnn::Mat bbox = bbox_blob.channel_range(q * 4, 4);

    float anchor_y = anchor[1];
    const float anchor_w = anchor[2] - anchor[0];
    const float anchor_h = anchor[3] - anchor[1];

    for (int i = 0; i < h; i++) {
      float anchor_x = anchor[0];
      for (int j = 0; j < w; j++) {
        const int index = i * w + j;
        const float prob = score[index];
        if (prob >= prob_threshold) {
          const float dx = bbox.channel(0)[index] * feat_stride;
          const float dy = bbox.channel(1)[index] * feat_stride;
          const float dw = bbox.channel(2)[index] * feat_stride;
          const float dh = bbox.channel(3)[index] * feat_stride;

          const float cx = anchor_x + anchor_w * 0.5f;
          const float cy = anchor_y + anchor_h * 0.5f;
          Face f;
          f.x1 = cx - dx;
          f.y1 = cy - dy;
          f.x2 = cx + dw;
          f.y2 = cy + dh;
          f.score = prob;
          out.push_back(f);
        }
        anchor_x += feat_stride;
      }
      anchor_y += feat_stride;
    }
  }
}

void nms(std::vector<Face>& faces, float iou_thr) {
  std::sort(faces.begin(), faces.end(),
            [](const Face& a, const Face& b) { return a.score > b.score; });
  std::vector<int> keep;
  std::vector<char> removed(faces.size(), 0);
  for (size_t i = 0; i < faces.size(); i++) {
    if (removed[i]) continue;
    keep.push_back(int(i));
    for (size_t j = i + 1; j < faces.size(); j++) {
      if (removed[j]) continue;
      const float xx1 = std::max(faces[i].x1, faces[j].x1);
      const float yy1 = std::max(faces[i].y1, faces[j].y1);
      const float xx2 = std::min(faces[i].x2, faces[j].x2);
      const float yy2 = std::min(faces[i].y2, faces[j].y2);
      const float w = std::max(0.f, xx2 - xx1);
      const float h = std::max(0.f, yy2 - yy1);
      const float inter = w * h;
      const float uni =
          (faces[i].x2 - faces[i].x1) * (faces[i].y2 - faces[i].y1) +
          (faces[j].x2 - faces[j].x1) * (faces[j].y2 - faces[j].y1) - inter;
      if (uni > 0 && inter / uni > iou_thr) removed[j] = 1;
    }
  }
  std::vector<Face> out;
  out.reserve(keep.size());
  for (int idx : keep) out.push_back(faces[idx]);
  faces.swap(out);
}

std::vector<Face> detect_faces(const unsigned char* rgba, int width, int height) {
  // letterbox → target (giữ tỉ lệ), pad bội 32
  int w = width;
  int h = height;
  float scale = 1.f;
  if (w > h) {
    scale = float(kDetTarget) / float(w);
    w = kDetTarget;
    h = int(h * scale);
  } else {
    scale = float(kDetTarget) / float(h);
    h = kDetTarget;
    w = int(w * scale);
  }
  if (w < 1) w = 1;
  if (h < 1) h = 1;

  ncnn::Mat in = ncnn::Mat::from_pixels_resize(rgba, ncnn::Mat::PIXEL_RGBA2RGB, width,
                                               height, w, h);

  const int wpad = (w + 31) / 32 * 32 - w;
  const int hpad = (h + 31) / 32 * 32 - h;
  ncnn::Mat in_pad;
  ncnn::copy_make_border(in, in_pad, hpad / 2, hpad - hpad / 2, wpad / 2,
                         wpad - wpad / 2, ncnn::BORDER_CONSTANT, 0.f);

  const float mean[3] = {127.5f, 127.5f, 127.5f};
  const float norm[3] = {1.f / 128.f, 1.f / 128.f, 1.f / 128.f};
  in_pad.substract_mean_normalize(mean, norm);

  ncnn::Extractor ex = g_det.create_extractor();
  ex.input("input.1", in_pad);

  std::vector<Face> proposals;

  // blob names: scrfd_500m-opt2 (ncnn examples/scrfd.cpp)
  {
    ncnn::Mat score, bbox;
    ex.extract("412", score);
    ex.extract("415", bbox);
    ncnn::Mat anchors = generate_anchors(16, 1.f, 2.f);
    generate_proposals(anchors, 8, score, bbox, kDetConf, proposals);
  }
  {
    ncnn::Mat score, bbox;
    ex.extract("474", score);
    ex.extract("477", bbox);
    ncnn::Mat anchors = generate_anchors(64, 1.f, 2.f);
    generate_proposals(anchors, 16, score, bbox, kDetConf, proposals);
  }
  {
    ncnn::Mat score, bbox;
    ex.extract("536", score);
    ex.extract("539", bbox);
    ncnn::Mat anchors = generate_anchors(256, 1.f, 2.f);
    generate_proposals(anchors, 32, score, bbox, kDetConf, proposals);
  }

  nms(proposals, kNmsIou);

  // map về toạ độ ảnh gốc
  const float pad_x = wpad / 2.f;
  const float pad_y = hpad / 2.f;
  for (auto& f : proposals) {
    float x1 = (f.x1 - pad_x) / scale;
    float y1 = (f.y1 - pad_y) / scale;
    float x2 = (f.x2 - pad_x) / scale;
    float y2 = (f.y2 - pad_y) / scale;
    f.x1 = clampf(x1, 0.f, float(width - 1));
    f.y1 = clampf(y1, 0.f, float(height - 1));
    f.x2 = clampf(x2, 0.f, float(width - 1));
    f.y2 = clampf(y2, 0.f, float(height - 1));
  }

  // bỏ box quá nhỏ
  std::vector<Face> faces;
  faces.reserve(proposals.size());
  for (const auto& f : proposals) {
    if (f.x2 - f.x1 >= 12 && f.y2 - f.y1 >= 12) faces.push_back(f);
  }
  return faces;
}

bool embed_face(const unsigned char* rgba, int width, int height, const Face& f,
                float* out_emb) {
  int x1 = int(f.x1), y1 = int(f.y1), x2 = int(f.x2), y2 = int(f.y2);
  int bw = x2 - x1, bh = y2 - y1;
  if (bw < 8 || bh < 8) return false;

  const int mx = int(bw * 0.2f), my = int(bh * 0.2f);
  x1 = std::max(0, x1 - mx);
  y1 = std::max(0, y1 - my);
  x2 = std::min(width - 1, x2 + mx);
  y2 = std::min(height - 1, y2 + my);
  bw = x2 - x1;
  bh = y2 - y1;

  std::vector<unsigned char> crop(bw * bh * 4);
  for (int y = 0; y < bh; y++) {
    memcpy(crop.data() + y * bw * 4, rgba + ((y1 + y) * width + x1) * 4, bw * 4);
  }

  ncnn::Mat in =
      ncnn::Mat::from_pixels_resize(crop.data(), ncnn::Mat::PIXEL_RGBA2RGB, bw, bh, 112, 112);
  const float mean[3] = {127.5f, 127.5f, 127.5f};
  const float norm[3] = {1.f / 128.f, 1.f / 128.f, 1.f / 128.f};
  in.substract_mean_normalize(mean, norm);

  ncnn::Extractor ex = g_rec.create_extractor();
  ex.input("x", in);
  ncnn::Mat out;
  if (ex.extract("fetch_name_0", out) != 0) return false;
  const int dim = std::min(kEmbDim, out.w * out.h * out.c);
  memcpy(out_emb, out.data, sizeof(float) * dim);
  for (int i = dim; i < kEmbDim; i++) out_emb[i] = 0;
  l2_normalize(out_emb, kEmbDim);
  return true;
}

}  // namespace

extern "C" {

FACE_API int face_ncnn_init(const char* detect_param, const char* detect_bin,
                            const char* recog_param, const char* recog_bin) {
  std::lock_guard<std::mutex> lock(g_mu);
  g_det.clear();
  g_rec.clear();
  g_ready = false;
  g_det.opt.use_vulkan_compute = false;
  g_rec.opt.use_vulkan_compute = false;
  if (g_det.load_param(detect_param) != 0) return -1;
  if (g_det.load_model(detect_bin) != 0) return -2;
  if (g_rec.load_param(recog_param) != 0) return -3;
  if (g_rec.load_model(recog_bin) != 0) return -4;
  g_ready = true;
  return 0;
}

FACE_API void face_ncnn_release(void) {
  std::lock_guard<std::mutex> lock(g_mu);
  g_det.clear();
  g_rec.clear();
  g_ready = false;
}

FACE_API int face_ncnn_detect_embed(const unsigned char* rgba, int width, int height,
                                    float* out_box, float* out_emb, float* out_score) {
  std::lock_guard<std::mutex> lock(g_mu);
  if (!g_ready || !rgba || width <= 0 || height <= 0) return -1;
  auto faces = detect_faces(rgba, width, height);
  if (faces.empty()) return 0;
  const Face& best = faces[0];
  if (out_box) {
    out_box[0] = best.x1;
    out_box[1] = best.y1;
    out_box[2] = best.x2;
    out_box[3] = best.y2;
  }
  if (out_score) *out_score = best.score;
  if (out_emb) {
    if (!embed_face(rgba, width, height, best, out_emb)) return -2;
  }
  return int(faces.size());
}

FACE_API float face_ncnn_cosine(const float* a, const float* b, int dim) {
  if (!a || !b || dim <= 0) return 0.f;
  double s = 0;
  for (int i = 0; i < dim; i++) s += double(a[i]) * double(b[i]);
  return float(s);
}

}  // extern "C"
