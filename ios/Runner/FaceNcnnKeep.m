#import <Foundation/Foundation.h>

// Declared in face_ncnn pod; call from AppDelegate so Runner links the static framework.
void FaceNcnnTouch(void);

__attribute__((constructor))
static void FaceNcnnKeepCtor(void) {
  FaceNcnnTouch();
}

void FaceNcnnKeepFromRunner(void) {
  FaceNcnnTouch();
}
