Pod::Spec.new do |s|
  s.name             = 'face_ncnn'
  s.version          = '1.0.1'
  s.summary          = 'Face detect/recognize NCNN FFI for Face AIoT'
  s.description      = 'C API face_ncnn_* backed by ncnn'
  s.homepage         = 'https://github.com/duong0411/face_alot'
  s.license          = { :type => 'MIT' }
  s.author           = { 'duong0411' => 'duong0411@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'

  s.source_files = [
    'Classes/**/*.{h,m,mm,cpp}',
    '../src/face_engine.cpp',
    '../include/face_ncnn_api.h',
  ]
  s.public_header_files = '../include/face_ncnn_api.h', 'Classes/FaceNcnnPlugin.h'
  s.header_mappings_dir = '../include'

  s.dependency 'Flutter'
  s.library = 'c++'
  s.static_framework = true

  # Download ncnn iOS (no vulkan) once
  s.prepare_command = <<-CMD
    set -e
    if [ ! -d "ncnn.xcframework" ]; then
      echo "Downloading ncnn iOS xcframework..."
      curl -L -o ncnn-ios.zip "https://github.com/Tencent/ncnn/releases/download/20250916/ncnn-20250916-ios.zip"
      unzip -qo ncnn-ios.zip
      # find xcframework
      FOUND=$(find . -maxdepth 3 -type d -name "ncnn.xcframework" | head -n 1)
      if [ -z "$FOUND" ]; then
        FOUND=$(find . -maxdepth 4 -type d -name "*.xcframework" | head -n 1)
      fi
      if [ -n "$FOUND" ] && [ "$FOUND" != "./ncnn.xcframework" ]; then
        rm -rf ncnn.xcframework
        mv "$FOUND" ./ncnn.xcframework
      fi
      rm -f ncnn-ios.zip
      # cleanup extract dirs except xcframework
      find . -maxdepth 1 -type d -name "ncnn-*" -exec rm -rf {} +
    fi
    test -d ncnn.xcframework
  CMD

  s.vendored_frameworks = 'ncnn.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../include" "${PODS_TARGET_SRCROOT}/Classes"',
    'OTHER_CPLUSPLUSFLAGS' => '-frtti -fexceptions',
    # Keep C symbols for Dart FFI DynamicLibrary.process()
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-all_load',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
  }
end

