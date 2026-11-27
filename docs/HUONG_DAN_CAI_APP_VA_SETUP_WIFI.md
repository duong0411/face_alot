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

### iOS (IPA)

IPA bản này **chưa ký App Store** (build `--no-codesign`). Cần công cụ sideload phù hợp máy bạn (ví dụ AltStore, Sideloadly, TrollStore… tùy iOS).

1. Cài IPA bằng công cụ sideload.
2. Trong **Cài đặt → Tổng quan → Quản lý VPN & thiết bị** (hoặc tương đương): tin cậy chứng chỉ nhà phát triển nếu hệ thống yêu cầu.
3. Mở app → đăng ký / đăng nhập.

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
| iOS không mở được IPA | Cần sideload + tin cậy chứng chỉ; IPA không cài trực tiếp như App Store |
| Android chặn APK | Bật “Cài từ nguồn không xác định” cho File / Chrome |

---

## 9. Ghi chú kỹ thuật (ngắn)

- SoftAP portal: SSID **`SmartHome`**, IP **`192.168.4.1`**, không mật khẩu AP.
- Double-reset xóa danh sách WiFi đã lưu rồi mở portal (dùng khi muốn cấu hình lại sạch).
- Firmware: `firmware/SmartHome_ESP32/`.
- App điều khiển: màn Smart Control / Home sau khi đăng nhập.
