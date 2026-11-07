#import <Flutter/Flutter.h>

@interface FaceNcnnPlugin : NSObject <FlutterPlugin>
@end

/// Force-link C API so Dart FFI can dlsym from the process.
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
