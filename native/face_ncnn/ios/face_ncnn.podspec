Pod::Spec.new do |s|
  s.name             = 'face_ncnn'
  s.version          = '1.0.7'
  s.summary          = 'Face detect/recognize NCNN FFI for Face AIoT'
  s.description      = 'C API face_ncnn_* backed by ncnn'
  s.homepage         = 'https://github.com/duong0411/face_alot'
  s.license          = { :type => 'MIT' }
  s.author           = { 'duong0411' => 'duong0411@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '15.0'

  # Keep C++ under this pod folder — CocoaPods path pods often drop ../src.
  s.source_files = [
    'Classes/**/*.{h,m,mm,cpp}',
    'Sources/**/*.{h,cpp}',
  ]
  s.public_header_files = 'Sources/face_ncnn_api.h', 'Classes/FaceNcnnPlugin.h'

  s.dependency 'Flutter'
  s.libraries = 'c++'
  s.static_framework = true

  # ncnn-20250916-ios.zip ships classic .framework (NOT .xcframework)
  s.prepare_command = <<-CMD
    set -e
    test -f Sources/face_engine.cpp
    test -f Sources/face_ncnn_api.h
    if [ ! -d "ncnn.framework" ] || [ ! -d "openmp.framework" ]; then
      echo "Downloading ncnn iOS frameworks..."
      curl -fL --retry 3 -o ncnn-ios.zip "https://github.com/Tencent/ncnn/releases/download/20250916/ncnn-20250916-ios.zip"
      unzip -qo ncnn-ios.zip
      rm -f ncnn-ios.zip
    fi
    test -d ncnn.framework
    test -d openmp.framework
  CMD

  s.vendored_frameworks = 'ncnn.framework', 'openmp.framework'

  # Do NOT use -all_load / -force_load here — CocoaPods already links the
  # static framework once; force_load caused "5 duplicate symbols" on CI.
  # AppDelegate calls FaceNcnnTouch() so face_engine.o is pulled in.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
    'GCC_INLINES_ARE_PRIVATE_EXTERN' => 'NO',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Sources" "${PODS_TARGET_SRCROOT}/Classes" "${PODS_TARGET_SRCROOT}/ncnn.framework/Headers"',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}"',
    'OTHER_CPLUSPLUSFLAGS' => '-frtti -fexceptions -fvisibility=default',
    'OTHER_CFLAGS' => '-fvisibility=default',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
  }
end
