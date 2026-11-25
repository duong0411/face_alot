# SmartHome ESP32

Firmware ESP32: **đèn + bơm + quạt**, mưa / đất / HC-SR04 + Kalman, còi gas & hết nước, **AUTO / MANUAL**.

Chip ID MQTT: **`esp32`** (khác ESP8266 `123`).

## Pinout

| STT | Linh kiện | Chân linh kiện | Chân ESP32 | Nguồn & lưu ý |
|-----|-----------|----------------|------------|----------------|
| 1 | OLED 0.96" I2C (SSD1306) | VCC / GND / SCL / SDA | 3.3V / GND / **GPIO22** / **GPIO21** | I2C |
| 2 | DHT11 | VCC / GND / DATA | 3.3V / GND / **GPIO4** | |
| 3 | Cảm biến quang (D0) | VCC / GND / D0 | 3.3V / GND / **GPIO27** | |
| 4 | Cảm biến Gas (D0) | VCC / GND / D0 | **VIN 5V** / GND / **GPIO26** | |
| 5 | Còi (Buzzer) | Signal / GND | **GPIO25** / GND | |
| 6 | Relay 2 kênh | VCC / GND / IN1 / IN2 | **VIN 5V** / GND / **GPIO32** / **GPIO33** | ACTIVE HIGH; **IN1=Bơm (32), IN2=Đèn (33)** |
| 7 | Relay quạt (1 kênh, mua sau) | VCC / GND / IN | **VIN 5V** / GND / **GPIO19** | Quạt; cùng logic ACTIVE HIGH |
| 8 | Cảm biến đất (A0) | VCC / GND / A0 | 3.3V / GND / **GPIO34** | ADC1 |
| 9 | Cảm biến mưa (D0) | VCC / GND / D0 | 3.3V / GND / **GPIO35** | |
| 10 | HC-SR04 | VCC / GND / TRIG / ECHO | **VIN 5V** / GND / **GPIO13** / **GPIO14** | ECHO nên chia áp |
| 11 | Servo SG90 | Signal / VCC / GND | **GPIO18** / **VIN 5V** / GND | ESP32Servo |

### MQTT thiết bị

| Thiết bị | Topic |
|----------|--------|
| Đèn (GPIO33 / IN2) | `esp32_led1` |
| Bơm (GPIO32 / IN1) | `esp32_pump` |
| Quạt (GPIO19) | `esp32_fan_livingroom` |

## AUTO

- Tối → đèn
- Hết nước / đất khô → bơm (mưa → dừng bơm)
- Nhiệt cao / gas → quạt
- Gas → còi (+ mở cửa nếu bật rule)

## WiFi portal

Double-reset → AP `SmartHome` → `192.168.4.1`.
