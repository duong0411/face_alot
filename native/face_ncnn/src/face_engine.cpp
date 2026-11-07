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
constexpr int kDetSize = 320;
constexpr float kDetConf = 0.7f;

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

// YuNet-style decode for strides 8/16/32 (simplified, bbox only).
void decode_stride(const ncnn::Mat& cls, const ncnn::Mat& obj, const ncnn::Mat& bbox,
                   int stride, int img_w, int img_h, float scale_x, float scale_y,
                   std::vector<Face>& faces) {
  const int feat_h = kDetSize / stride;
  const int feat_w = kDetSize / stride;
  const int num = feat_h * feat_w;
  if (cls.w * cls.h * cls.c < num) return;

  const float* cls_ptr = (const float*)cls.data;
  const float* obj_ptr = (const float*)obj.data;
  const float* box_ptr = (const float*)bbox.data;

  for (int y = 0; y < feat_h; y++) {
    for (int x = 0; x < feat_w; x++) {
      const int i = y * feat_w + x;
      const float score = cls_ptr[i] * obj_ptr[i];
      if (score < kDetConf) continue;

      // YuNet bbox: dx, dy, dw, dh relative to grid (approx)
      const float* b = box_ptr + i * 4;
      const float cx = (x + b[0]) * stride;
      const float cy = (y + b[1]) * stride;
      const float w = std::exp(b[2]) * stride;
      const float h = std::exp(b[3]) * stride;

      Face f;
      f.x1 = clampf((cx - w * 0.5f) / scale_x, 0.f, float(img_w - 1));
      f.y1 = clampf((cy - h * 0.5f) / scale_y, 0.f, float(img_h - 1));
      f.x2 = clampf((cx + w * 0.5f) / scale_x, 0.f, float(img_w - 1));
      f.y2 = clampf((cy + h * 0.5f) / scale_y, 0.f, float(img_h - 1));
      f.score = score;
      if (f.x2 - f.x1 >= 12 && f.y2 - f.y1 >= 12) faces.push_back(f);
    }
  }
}

void nms(std::vector<Face>& faces, float iou_thr = 0.45f) {
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
  const float scale_x = float(kDetSize) / float(width);
  const float scale_y = float(kDetSize) / float(height);

  ncnn::Mat in = ncnn::Mat::from_pixels_resize(rgba, ncnn::Mat::PIXEL_RGBA2BGR, width,
                                               height, kDetSize, kDetSize);
  const float mean[3] = {0.f, 0.f, 0.f};
  const float norm[3] = {1.f / 255.f, 1.f / 255.f, 1.f / 255.f};
  in.substract_mean_normalize(mean, norm);

  ncnn::Extractor ex = g_det.create_extractor();
  ex.input("input", in);

  ncnn::Mat cls8, cls16, cls32, obj8, obj16, obj32, b8, b16, b32;
  ex.extract("cls_8", cls8);
  ex.extract("cls_16", cls16);
  ex.extract("cls_32", cls32);
  ex.extract("obj_8", obj8);
  ex.extract("obj_16", obj16);
  ex.extract("obj_32", obj32);
  ex.extract("bbox_8", b8);
  ex.extract("bbox_16", b16);
  ex.extract("bbox_32", b32);

  std::vector<Face> faces;
  decode_stride(cls8, obj8, b8, 8, width, height, scale_x, scale_y, faces);
  decode_stride(cls16, obj16, b16, 16, width, height, scale_x, scale_y, faces);
  decode_stride(cls32, obj32, b32, 32, width, height, scale_x, scale_y, faces);
  nms(faces);
  return faces;
}

bool embed_face(const unsigned char* rgba, int width, int height, const Face& f,
                float* out_emb) {
  int x1 = int(f.x1), y1 = int(f.y1), x2 = int(f.x2), y2 = int(f.y2);
  int bw = x2 - x1, bh = y2 - y1;
  if (bw < 8 || bh < 8) return false;

  // margin 20%
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
  // MobileFaceNet converted input name
  ex.input("x", in);
  ncnn::Mat out;
  if (ex.extract("fetch_name_0", out) != 0) {
    // fallback first blob
    return false;
  }
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
