# Hướng dẫn cài app (APK / IPA) và cấu hình WiFi nhà thông minh

Tài liệu dành cho khi **đổi WiFi mới** (đổi mật khẩu router, chuyển nhà, lắp mạng mới) hoặc lần đầu bật ESP32 + cài app lên điện thoại.

---

## 1. Tải và cài app

Release mới nhất: **[v1.1.7](https://github.com/duong0411/face_alot/releases/tag/v1.1.7)**

| File | Link |
|------|------|
| Android APK | [face_alot-v1.1.7.apk](https://github.com/duong0411/face_alot/releases/download/v1.1.7/face_alot-v1.1.7.apk) |
| iOS IPA (unsigned) | [face_alot-v1.1.7-ios.ipa](https://github.com/duong0411/face_alot/releases/download/v1.1.7/face_alot-v1.1.7-ios.ipa) |

### Android (APK)

1. Tải file `.apk` về máy.
2. Cho phép **Cài đặt từ nguồn không xác định** (theo từng máy).
3. Mở file APK → **Cài đặt** → mở app Face AIoT.
4. Đăng ký / đăng nhập tài khoản.

### iOS (IPA) — cài bằng Sideloadly + Apple ID (iCloud)

IPA bản này **chưa ký App Store** (build `--no-codesign`). Cách khuyến nghị: **Sideloadly** trên Windows/Mac, dùng **Apple ID / iCloud** miễn phí (giới hạn ~7 ngày, cần cài lại khi hết hạn).

#### A. Chuẩn bị trên máy tính

1. Tải **Sideloadly**: https://sideloadly.io/
2. Cài **iTunes** (Windows: bản từ Apple, không dùng Microsoft Store) để nhận diện iPhone qua USB.
3. Tải file IPA: [face_alot-v1.1.7-ios.ipa](https://github.com/duong0411/face_alot/releases/download/v1.1.7/face_alot-v1.1.7-ios.ipa)
4. Cắm iPhone vào máy bằng cáp USB → trên iPhone chọn **Tin cậy máy tính này** nếu hỏi.

#### B. Cài IPA bằng Sideloadly

1. Mở **Sideloadly**.
2. Kéo thả file `face_alot-v1.1.7-ios.ipa` vào cửa sổ Sideloadly (hoặc bấm chọn IPA).
3. Ô **Apple account / Apple ID**: nhập email **iCloud / Apple ID** của bạn (tài khoản dùng để đăng nhập iPhone).
4. Chọn đúng **thiết bị iPhone** trong danh sách (nếu có nhiều thiết bị).
5. (Tuỳ chọn) bật **Advanced options** nếu cần — mặc định để nguyên là được với IPA unsigned.
6. Bấm **Start** → nhập **mật khẩu Apple ID** khi Sideloadly hỏi (có thể nhận mã xác minh 2FA trên iPhone).
7. Đợi trạng thái **Done / Success**. App Face AIoT sẽ xuất hiện trên màn hình iPhone.

> Lần đầu Apple có thể gửi email “App được cài bằng tài khoản phát triển” — bình thường với sideload.

#### C. Tin cậy tài khoản nhà phát triển trên iPhone (VPN & Device Management)

1. Mở **Cài đặt (Settings)**.
2. Vào **Tổng quan (General)** → **VPN & Quản lý thiết bị**  
   (*General → VPN & Device Management* — tên có thể hơi khác theo phiên bản iOS).
3. Trong mục **Nhà phát triển ứng dụng (Developer App)**, chọn **Apple ID** vừa dùng trên Sideloadly.
4. Bấm **Tin cậy “Apple ID…”** → xác nhận **Tin cậy**.

Không tin cậy thì mở app sẽ báo không xác minh được nhà phát triển.

#### D. Bật Chế độ nhà phát triển (Developer Mode)

Trên iOS 16+ (và nhiều máy mới hơn) cần bật Developer Mode mới chạy app sideload:

1. **Cài đặt → Quyền riêng tư & Bảo mật (Privacy & Security)**.
2. Kéo xuống mục **Chế độ nhà phát triển (Developer Mode)** → **Bật**.
3. Máy yêu cầu **Khởi động lại** → khởi động lại iPhone.
4. Sau khi mở lại: xác nhận **Bật** Developer Mode (có thể hỏi Face ID / mật mã).

Rồi mở app Face AIoT → đăng ký / đăng nhập.

#### E. Ghi nhớ sau khi cài

| Việc | Chi tiết |
|------|----------|
| Hạn chứng chỉ free | Apple ID miễn phí ~**7 ngày** — hết hạn app không mở được → cắm USB, Sideloadly **Start** lại cùng Apple ID |
| Đổi Apple ID | Cần xóa app cũ / tin cậy tài khoản mới trong VPN & Device Management |
| Không cần App Store | App không cập nhật qua App Store; tải IPA mới từ GitHub Release rồi Sideloadly lại |

---

## 2. Khi nào cần cấu hình lại WiFi trên ESP32?

Làm lại portal WiFi khi:

- Đổi tên hoặc mật khẩu WiFi nhà
- Chuyển sang mạng WiFi khác
- ESP32 mới / vừa nạp firmware / chưa từng lưu WiFi
- OLED hiện **WiFi PORTAL** hoặc nhà không online trên app

Chip ID MQTT mặc định của bản SmartHome này: **`esp32`** (điền đúng trên app).

---

## 3. Mở cổng cấu hình WiFi (portal) trên ESP32

### Cách khuyến nghị: double-reset

1. Cắm nguồn ESP32 (hoặc đang chạy).
2. Nhấn nút **RESET** (EN) **2 lần liên tiếp**, cách nhau khoảng **1–2 giây** (double-reset).
3. Quan sát OLED:
   - Dòng kiểu **WiFi PORTAL**
   - **SSID: SmartHome**
   - **192.168.4.1**

Portal cũng tự mở nếu:

- Chưa có WiFi nào trong bộ nhớ, hoặc
- Kết nối WiFi nhà thất bại nhiều lần liên tiếp

---

## 4. Kết nối điện thoại vào WiFi của ESP32

1. Mở **Cài đặt WiFi** trên điện thoại.
2. Chọn mạng **`SmartHome`** (không mật khẩu).
3. Đợi điện thoại báo đã kết nối (có thể hiện “Không có Internet” — bình thường).
4. Mở trình duyệt (Chrome / Safari) → vào địa chỉ:

```text
http://192.168.4.1
```

Trang **SmartHome ESP32 WiFi** hiện ra.

> Nếu không vào được: tắt dữ liệu di động tạm thời, rồi mở lại `http://192.168.4.1`.

---

## 5. Chọn WiFi nhà mới và lưu

Trên trang portal:

1. Bấm **Quet mang** (Quét mạng).
2. Chạm tên WiFi nhà trong danh sách (điền sẵn ô tên).
3. Nhập **mật khẩu** WiFi nhà.
4. Bấm **Ket noi** (Kết nối).
5. Đợi thông báo **OK restart...** — ESP32 sẽ khởi động lại và nối WiFi nhà.

Sau khi restart:

1. OLED không còn trang portal; có dấu kết nối WiFi / MQTT (ví dụ `W` / `M` trên thanh trạng thái).
2. Điện thoại **rời mạng SmartHome**, nối lại **WiFi nhà** (cùng mạng với ESP32, có Internet).
3. Mở app Face AIoT.

---

## 6. Kết nối nhà trên app (sau khi WiFi OK)

1. Mở app → đăng nhập.
2. Vào màn hình nhà / điều khiển thông minh.
3. Ô **Chip ID** nhập: **`esp32`** (trừ khi firmware đổi ID khác).
4. Lưu Chip ID / bấm kết nối nhà.
5. Trạng thái kiểu **Đã kết nối · esp32** → điều khiển đèn, bơm, cửa, AUTO…

App nói chuyện với nhà qua MQTT:

```text
wss://mqtt.duynguyen.io.vn/mqtt
```

Điện thoại và ESP32 **không cần cùng WiFi** miễn cả hai đều ra Internet (ESP32 qua WiFi nhà; điện thoại có thể dùng 4G). Cùng WiFi nhà thường ổn định hơn khi demo tại chỗ.

---

## 7. Checklist nhanh khi “mạng mới”

| Bước | Việc cần làm |
|------|----------------|
| 1 | Double-reset ESP32 → OLED hiện portal |
| 2 | Điện thoại nối WiFi `SmartHome` |
| 3 | Vào `http://192.168.4.1` → quét → chọn WiFi mới → nhập mật khẩu → Kết nối |
| 4 | Đợi ESP32 restart; điện thoại về WiFi nhà |
| 5 | Cài / mở app APK hoặc IPA |
| 6 | App: Chip ID = `esp32` → kết nối nhà |

---

## 8. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|------------|------------|
| Không thấy SSID `SmartHome` | Double-reset lại; chờ 5–10 giây; đứng gần ESP32 |
| Vào `192.168.4.1` không được | Đang dính 4G — tắt dữ liệu di động; thử trình duyệt khác |
| Portal báo fail khi Kết nối | Sai mật khẩu WiFi; WiFi 5 GHz-only (ưu tiên băng 2.4 GHz); đứng gần router |
| App không kết nối nhà | Kiểm tra Chip ID `esp32`; ESP32 đã có WiFi + MQTT; thử mở lại app / kết nối lại |
| iOS không mở được IPA | Cài bằng **Sideloadly** + Apple ID; **Tin cậy** tài khoản trong *VPN & Quản lý thiết bị*; bật **Developer Mode** rồi khởi động lại |
| App iOS báo hết hạn / không xác minh | Sideloadly cài lại cùng Apple ID (chứng chỉ free ~7 ngày) |
| Sideloadly không thấy iPhone | Cài iTunes (bản Apple), cáp USB tốt, trên iPhone bấm Tin cậy máy tính |
| Android chặn APK | Bật “Cài từ nguồn không xác định” cho File / Chrome |

---

## 9. Ghi chú kỹ thuật (ngắn)

- SoftAP portal: SSID **`SmartHome`**, IP **`192.168.4.1`**, không mật khẩu AP.
- Double-reset xóa danh sách WiFi đã lưu rồi mở portal (dùng khi muốn cấu hình lại sạch).
- Firmware: `firmware/SmartHome_ESP32/`.
- App điều khiển: màn Smart Control / Home sau khi đăng nhập.
