#import <Flutter/Flutter.h>

/// Force-link C API so Dart FFI can dlsym from the process.
@interface FaceNcnnPlugin : NSObject <FlutterPlugin>
@end

#ifdef __cplusplus
extern "C" {
#endif
/// Call once at app start so linker cannot dead-strip face_ncnn_*.
void FaceNcnnTouch(void);

int face_ncnn_init(const char*, const char*, const char*, const char*);
void face_ncnn_release(void);
int face_ncnn_detect_embed(const unsigned char*, int, int, float*, float*, float*);
float face_ncnn_cosine(const float*, const float*, int);
#ifdef __cplusplus
}
#endif
