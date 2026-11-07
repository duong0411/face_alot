#import "FaceNcnnPlugin.h"

void FaceNcnnTouch(void) {
  // Real references — prevents dead-strip of C API from the static pod.
  volatile void* keep[] = {
      (void*)&face_ncnn_init,
      (void*)&face_ncnn_release,
      (void*)&face_ncnn_detect_embed,
      (void*)&face_ncnn_cosine,
  };
  (void)keep;
}

__attribute__((constructor)) static void FaceNcnnCtor(void) {
  FaceNcnnTouch();
}

@implementation FaceNcnnPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FaceNcnnTouch();
}
@end
