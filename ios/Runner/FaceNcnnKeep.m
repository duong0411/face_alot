#import <Foundation/Foundation.h>

// Ensure linker pulls face_ncnn C symbols into the app binary for Dart FFI.
#ifdef __cplusplus
extern "C" {
#endif
int face_ncnn_init(const char*, const char*, const char*, const char*);
void face_ncnn_release(void);
int face_ncnn_detect_embed(const unsigned char*, int, int, float*, float*, float*);
float face_ncnn_cosine(const float*, const float*, int);
#ifdef __cplusplus
}
#endif

__attribute__((used)) static void FaceNcnnKeepSymbols(void) {
  volatile void* keep[] = {
      (void*)&face_ncnn_init,
      (void*)&face_ncnn_release,
      (void*)&face_ncnn_detect_embed,
      (void*)&face_ncnn_cosine,
  };
  (void)keep;
}
