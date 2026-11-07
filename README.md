# Face AIoT (`face_alot`)

App Flutter nhà thông minh: **đăng nhập API Docker**, **đăng ký khuôn mặt**, **nhận diện realtime** → MQTT mở cửa ESP8266.

## Tính năng

- Auth: login / register / quên mật khẩu → `https://duynguyen.io.vn/api/auth/*`
- Face **detect + recognize** chạy **C/C++ NCNN**, gọi qua **Dart FFI**
- Đăng ký mặt trước → camera realtime match → publish MQTT mở cửa
- Broker: `wss://mqtt.duynguyen.io.vn/mqtt`
  - `cmnd/123_face_livingroom/POWER` JSON `{"name","action":"OPEN"}`
  - `cmnd/123_door_livingroom1/POWER` = `ON`

## Model (từ `stem_chamcong_face` → NCNN)

| Vai trò | Nguồn | Runtime |
|--------|--------|---------|
| Detect (nhẹ) | OpenCV **YuNet** ~213KB (thay BlazeFace TFLite — MediaPipe không convert NCNN trực tiếp) | `face_detect.param/.bin` |
| Recognize | **MobileFaceNet_128.onnx** → `onnx2ncnn` | `mobilefacenet.param/.bin` |
| Match | Cosine, ngưỡng `0.45` | FFI |

Chuyển model:

```bat
tools\ncnn_bin\onnx2ncnn.exe assets\models\MobileFaceNet_128.sim.onnx assets\models\mobilefacenet.param assets\models\mobilefacenet.bin
```

## Chạy local

```bat
flutter pub get
flutter run
```

Android build kèm NCNN (CMake FetchContent — lần đầu lâu):

```bat
flutter build apk --release
```

## API Docker

Backend AloT đã chạy Docker/Cloudflare. App gọi:

- `POST /api/auth/login`
- `POST /api/auth/register`
- `POST /api/auth/check-phone-exists`
- `POST /api/auth/reset-password`

Đổi host: `--dart-define=API_BASE=https://...`

## CI

GitHub Actions: `.github/workflows/build.yml` → artifact **APK** + **IPA** (unsigned, cần Apple cert để ký).

## Cấu trúc

```
lib/                 Flutter UI + FFI
native/face_ncnn/    C++ NCNN engine
assets/models/       NCNN weights
android/             CMake → libface_ncnn.so
```
