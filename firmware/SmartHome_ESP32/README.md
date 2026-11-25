# SmartHome ESP32

Firmware chuyển từ ESP8266 → ESP32 theo sơ đồ chân mới: **bơm thay quạt**, thêm **mưa / đất / HC-SR04 + Kalman**, còi cảnh báo gas & hết nước, chế độ **AUTO / MANUAL**.

## Board & thư viện (Arduino IDE / PlatformIO)

- Board: **ESP32 Dev Module** (hoặc tương đương)
- Thư viện:
  - `Adafruit SH110X` + `Adafruit GFX`
  - `DHT sensor library` (Adafruit)
  - `ESP32Servo`
  - `WebSockets` (Links2004)
  - `MQTTPubSubClient` (hideakitai)

## Pinout

| Linh kiện | ESP32 |
|-----------|-------|
| OLED SDA / SCL | 21 / 22 |
| DHT11 | 4 |
| LDR D0 | 27 |
| Gas D0 | 26 (module 5V) |
| Buzzer | 25 |
| Relay IN1 / IN2 | 32 / 33 (ACTIVE LOW, VCC 5V) |
| Đất A0 | 34 |
| Mưa D0 | 35 |
| HC-SR04 TRIG / ECHO | 13 / 14 (ECHO nên chia áp 5V→3.3V) |
| Servo | 18 (VCC 5V) |

- **IN1** = Đèn → MQTT `123_led1`
- **IN2** = Bơm → MQTT `123_fan_livingroom` (topic cũ của quạt)

## AUTO

- Tối (LDR) → bật đèn
- Hết nước (`waterCm >= waterEmptyCm`) → còi + **tự bơm**
- Đất khô (ADC) → tự bơm (tắt khi đủ ẩm / mưa)
- Gas D0 LOW → còi (+ mở cửa nếu bật rule)

## Hiệu chỉnh mực nước

Đặt cảm biến cố định phía trên bể/chậu, đo khoảng cách thực tế khi cạn / khi đầy, rồi gửi rule:

```json
{"waterEmptyCm":25,"waterOkCm":18,"autoPumpEmpty":1,"buzzerOnEmpty":1}
```

Khoảng cách **lớn** = mực nước **thấp/hết**.

## WiFi portal

Double-reset nhanh → AP `SmartHome` → `192.168.4.1`.
