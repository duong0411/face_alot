#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define FACE_API __declspec(dllexport)
#else
#define FACE_API __attribute__((visibility("default")))
#endif

/** Init engines. Paths are absolute to .param/.bin files. Returns 0 on success. */
FACE_API int face_ncnn_init(const char* detect_param, const char* detect_bin,
                            const char* recog_param, const char* recog_bin);

FACE_API void face_ncnn_release(void);

/**
 * Detect + embed largest face.
 * rgba: width*height*4 (RGBA8888)
 * out_box: [x1,y1,x2,y2] float
 * out_emb: 128 floats (L2-normalized), or nullptr to skip embed
 * Returns number of faces (0..n). Negative = error.
 */
FACE_API int face_ncnn_detect_embed(const unsigned char* rgba, int width, int height,
                                    float* out_box, float* out_emb, float* out_score);

/** Cosine similarity between two 128-d embeddings. */
FACE_API float face_ncnn_cosine(const float* a, const float* b, int dim);

#ifdef __cplusplus
}
#endif
