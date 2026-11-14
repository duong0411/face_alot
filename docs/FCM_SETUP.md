# Cảnh báo gas khi tắt app — **Android + FCM**

iOS (không Apple Developer / IPA unsigned): **không hỗ trợ push**.  
Trên iOS chỉ báo khi app đang mở (MQTT + local notification).

```
ESP → MQTT → gas_fcm_bridge → Firebase FCM → Android (app tắt vẫn hiện)
```

## 1. Firebase (chỉ Android)

1. Mở tạo project: https://console.firebase.google.com/u/0/  
   (hoặc trực tiếp: https://console.firebase.google.com/project/_/overview → **Add project**)
2. Add app **Android**, package: `vn.duynguyen.face_alot`  
3. Tải `google-services.json` → đặt vào `android/app/google-services.json`  
4. (Khuyến nghị) chạy:

```bat
npm i -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
cd D:\duongpv\face_alot
flutterfire configure --platforms=android
```

5. Build / run với cờ bật FCM:

```bat
flutter run --dart-define=FIREBASE_CONFIGURED=true
flutter build apk --release --dart-define=FIREBASE_CONFIGURED=true
```

`flutterfire configure` sẽ ghi `lib/firebase_options.dart`. Giữ `--dart-define=FIREBASE_CONFIGURED=true` khi build.

## 2. Bridge MQTT → FCM (server)

1. Firebase → Project settings → **Service accounts** → Generate private key  
   → `server/gas_fcm_bridge/serviceAccount.json`
2. Chạy:

```bat
cd server\gas_fcm_bridge
npm install
npm start
```

- `POST /api/push/register` — app Android đăng ký FID + chipId  
- MQTT `tele/+/status` (topic `*_vitals`) — `gasAlert=1` → gửi FCM  

Proxy `/api/push/*` về bridge, hoặc:

```bat
--dart-define=PUSH_API_BASE=https://push.duynguyen.io.vn
```

## 3. GitHub Actions (APK)

Thêm secret repo:

| Secret | Nội dung |
|--------|----------|
| `GOOGLE_SERVICES_JSON` | Toàn bộ nội dung file `google-services.json` |

Workflow Android sẽ ghi file đó trước `flutter build apk` và truyền `FIREBASE_CONFIGURED=true`.

## 4. Test trên Android

1. Cài APK / `flutter run --dart-define=FIREBASE_CONFIGURED=true`  
2. Cho phép thông báo  
3. Log: `FCM FID: ...` và `FCM registered chip=...`  
4. Bridge: `[register] chip=...`  
5. **Vuốt tắt app**  
6. ESP / MQTT `gasAlert: 1` → thông báo hệ thống hiện  

Gửi thử: Firebase Console → Messaging → tạo notification tới app.

## 5. Chưa có Firebase

App vẫn chạy. FCM tắt. Cảnh báo gas khi **app mở** vẫn qua MQTT + `GasAlert`.

## File chính

| Path | Vai trò |
|------|---------|
| `lib/core/push/fcm_service.dart` | FCM Android-only |
| `lib/core/api/push_api.dart` | Đăng ký FID lên bridge |
| `server/gas_fcm_bridge/` | MQTT → FCM |
| `android/app/google-services.json` | Config Android (secret / local, không commit) |
