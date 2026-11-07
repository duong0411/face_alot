#import "FaceNcnnPlugin.h"
#import <stdint.h>
#import <stdlib.h>

// Strong refs so the linker must pull face_engine.o from this static pod.
void FaceNcnnTouch(void) {
  volatile intptr_t keep = 0;
  keep ^= (intptr_t)(void*)&face_ncnn_init;
  keep ^= (intptr_t)(void*)&face_ncnn_release;
  keep ^= (intptr_t)(void*)&face_ncnn_detect_embed;
  keep ^= (intptr_t)(void*)&face_ncnn_cosine;
  if (keep == 0x7fffffff) {
    // Unreachable — prevents the compiler from deleting the XOR chain.
    abort();
  }
}

@implementation FaceNcnnPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FaceNcnnTouch();
}
@end
