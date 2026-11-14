# Face AIoT (`face_alot`)

App Flutter nhà thông minh: **đăng nhập API Docker**, **đăng ký khuôn mặt**, **nhận diện realtime** → MQTT mở cửa ESP8266.

## Tính năng

- Auth: login / register / quên mật khẩu → `https://duynguyen.io.vn/api/auth/*`
- Face **detect + recognize** chạy **C/C++ NCNN**, gọi qua **Dart FFI**
- Nhận diện **1:N**: probe so khớp toàn gallery (max cosine / người, top-K + ngưỡng + margin)
- Đăng ký nhiều người / nhiều mẫu → realtime identify → MQTT mở cửa
- Smart home **MANUAL / AUTO** (đèn, quạt, rule nhiệt/gas/LDR)
- **Cảnh báo gas khi tắt app** (FCM **Android**; iOS chỉ khi app mở) — [docs/FCM_SETUP.md](docs/FCM_SETUP.md)
- Broker: `wss://mqtt.duynguyen.io.vn/mqtt`
  - `cmnd/123_face_livingroom/POWER` JSON `{"name","action":"OPEN"}`
  - `cmnd/123_door_livingroom1/POWER` = `ON`
  - `cmnd/123_mode/POWER` `AUTO|MANUAL`
  - `cmnd/123_rules/SET` JSON rules

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

Sau khi cấu hình Firebase (xem `docs/FCM_SETUP.md`):

```bat
flutter run --dart-define=FIREBASE_CONFIGURED=true
```

Gas push bridge (MQTT → FCM):

```bat
cd server\gas_fcm_bridge
npm install
npm start
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

## CI / Release

GitHub Actions (`.github/workflows/build.yml`):
- Push `main` → build artifact APK + IPA unsigned
- Push tag `v*` → **tạo GitHub Release** kèm APK (+ IPA unsigned)

```bat
git tag v1.0.1
git push origin v1.0.1
```

Face gallery 1:N lưu **MongoDB Docker**, matching từ xa qua `https://duynguyen.io.vn/api/faces/*`.

## Cấu trúc

```
lib/                 Flutter UI + FFI
native/face_ncnn/    C++ NCNN engine
assets/models/       NCNN weights
android/             CMake → libface_ncnn.so
```
