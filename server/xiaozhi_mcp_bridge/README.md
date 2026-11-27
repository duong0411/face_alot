# Xiaozhi MCP ↔ SmartHome ESP32

Bridge Docker: Xiaozhi gọi tool MCP → publish MQTT tới firmware `SmartHome_ESP32` (`CHIP_ID=esp32`).

Hỗ trợ trò chuyện về: **đèn, bơm, quạt, cửa, độ ẩm không khí/đất, mực nước HC-SR04, mưa, gas, AUTO/MANUAL**.

## Chạy Docker (public image)

```bat
cd D:\duongpv\face_alot\server\xiaozhi_mcp_bridge
copy .env.example .env
REM dán XIAOZHI_URL đầy đủ token vào .env

docker pull duong0411/xiaozhi-mcp-smarthome:latest
docker compose up -d
docker compose logs -f
```

Build + push Hub (máy dev đã login Docker Desktop):

```bat
docker compose build
docker push duong0411/xiaozhi-mcp-smarthome:latest
```

Health: http://localhost:8790/health

## Chạy local (không Docker)

```bat
cd D:\duongpv\face_alot\server\xiaozhi_mcp_bridge
npm install
npm start
```

## Tools MCP

| Tool | Việc |
|------|------|
| `control_light` | Bật/tắt đèn |
| `control_pump` | Bật/tắt bơm |
| `control_fan` | Bật/tắt quạt |
| `control_door` | Mở/đóng cửa |
| `control_all_devices` | Đèn+bơm+quạt |
| `set_control_mode` | MANUAL / AUTO |
| `set_auto_rules` | Rule đất/nước/mưa/nhiệt/gas |
| `read_home_status` | Toàn bộ trạng thái |
| `read_temperature` | Nhiệt độ °C (DHT11) |
| `read_humidity` | Độ ẩm KK + đất |
| `read_water_level` | Mực nước (cm) |

## MQTT map (CHIP_ID=esp32)

- `cmnd/esp32_led1/POWER` ON|OFF
- `cmnd/esp32_pump/POWER` ON|OFF
- `cmnd/esp32_fan/POWER` ON|OFF
- `cmnd/esp32_door_livingroom1/POWER` ON|OFF
- `cmnd/esp32_mode/POWER` AUTO|MANUAL
- `cmnd/esp32_rules/SET` JSON
- `tele/esp32_vitals/status` cache cảm biến

## Prompt Xiaozhi

Dán nội dung `XIAOZHI_SMART_HOME_PROMPT.md` vào System prompt agent trên xiaozhi.me (agent đã gắn MCP endpoint này).

## Bảo mật

- File `.env` chứa token JWT — **không commit**.
- Token hết hạn thì lấy endpoint mới trên xiaozhi.me và cập nhật `XIAOZHI_URL`.
