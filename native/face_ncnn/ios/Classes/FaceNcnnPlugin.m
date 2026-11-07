#import "FaceNcnnPlugin.h"

@implementation FaceNcnnPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  // No MethodChannel — Dart uses FFI. Keep symbols alive:
  volatile void* keep[] = {
      (void*)&face_ncnn_init,
      (void*)&face_ncnn_release,
      (void*)&face_ncnn_detect_embed,
      (void*)&face_ncnn_cosine,
  };
  (void)keep;
}
@end
