/*
 * SmartHome ESP32 — OLED + AUTO/MANUAL + Face Door + Bơm + Mực nước Kalman
 *
 * PINOUT (theo sơ đồ):
 *  OLED SDA/SCL → GPIO21 / GPIO22
 *  DHT11 DATA   → GPIO4
 *  LDR (D0)     → GPIO27
 *  Gas (D0)     → GPIO26   (module cấp 5V)
 *  Buzzer       → GPIO25
 *  Relay IN1/IN2→ GPIO32 / GPIO33  (VCC relay = 5V, ACTIVE HIGH)
 *  Relay quat IN → GPIO19 (them relay 1 kenh khi mua quat)
 *  Đất (A0)     → GPIO34   (ADC1)
 *  Mưa (D0)     → GPIO35
 *  HC-SR04 TRIG/ECHO → GPIO13 / GPIO14  (VCC=5V; ECHO nên chia áp)
 *  Servo cửa    → GPIO18   (VCC=5V)
 *
 * Relay: IN1 = Đèn (topic led1), IN2 = Bơm (topic fan → thay quạt)
 *
 * MQTT (giữ tương thích app):
 *  cmnd/esp32_mode/POWER          AUTO|MANUAL
 *  cmnd/esp32_rules/SET           JSON ngưỡng auto
 *  cmnd/esp32_led1/POWER          ON|OFF   (đèn, chỉ MANUAL)
 *  cmnd/esp32_fan_livingroom/POWER ON|OFF  (bơm, chỉ MANUAL)
 *  cmnd/esp32_door_livingroom1 / esp32_face_livingroom
 *  tele/... vitals gồm soil, rain, waterCm, waterEmpty, pump
 */

#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <WebSocketsClient.h>
#include <MQTTPubSubClient.h>
#include "DHT.h"
#include <ESP32Servo.h>

using MqttClient512 = arduino::mqtt::PubSubClient<512>;

// ─── Pins ────────────────────────────────────────────────────
#define PIN_OLED_SDA   21
#define PIN_OLED_SCL   22
#define PIN_DHT         4
#define PIN_LDR        27
#define PIN_GAS        26   // D0 digital
#define PIN_BUZZER     25
#define PIN_RELAY1     32   // IN1 — Đèn  (topic led1)
#define PIN_RELAY2     33   // Relay2ch IN2 — Bom (pump)
#define PIN_FAN        19   // Relay quat IN — Quat (fan) them sau
#define PIN_SOIL       34   // A0 analog ADC1
#define PIN_RAIN       35   // D0 digital (input-only)
#define PIN_TRIG       13
#define PIN_ECHO       14
#define PIN_DOOR       18

#define DHTTYPE        DHT11

// Module relay 2 kênh ACTIVE HIGH (đảo lại theo phần cứng thực tế)
#define RELAY_ON       HIGH
#define RELAY_OFF      LOW

#define OLED_ADDR      0x3C
#define SCREEN_W       128
#define SCREEN_H       64
#define OLED_ROTATION  2

#define AP_SSID        "SmartHome"
#define AP_PASSWORD    ""
IPAddress apIP(192, 168, 4, 1);
const byte DNS_PORT = 53;

#define MQTT_HOST      "mqtt.duynguyen.io.vn"
#define MQTT_PORT      443
#define MQTT_PATH      "/mqtt"
#define CHIP_ID        "esp32"

#define DEV_TEMP       "esp32_temp_livingroom"
#define DEV_HUMI       "esp32_humi_living_room"
#define DEV_LIGHT      "esp32_led1"
#define DEV_PUMP       "esp32_pump"
#define DEV_FAN        "esp32_fan_livingroom"
#define DEV_DOOR       "esp32_door_livingroom1"
#define DEV_FACE       "esp32_face_livingroom"
#define DEV_GAS        "esp32_gas_livingroom"
#define DEV_LDR        "esp32_ldr_livingroom"
#define DEV_SOIL       "esp32_soil"
#define DEV_RAIN       "esp32_rain"
#define DEV_WATER      "esp32_water"
#define DEV_MODE       "esp32_mode"
#define DEV_RULES      "esp32_rules"
#define DEV_VITALS     "esp32_vitals"

#define EEPROM_SIZE    512
#define MAX_WIFI       5
#define RULES_EEPROM_ADDR 400
#define RULES_MAGIC    0xB3   // bump khi đổi struct AutoRules

struct WifiEntry { char ssid[32]; char pass[32]; };
WifiEntry wifiList[MAX_WIFI];
int wifiCount = 0;

enum ControlMode : uint8_t { MODE_MANUAL = 0, MODE_AUTO = 1 };

struct AutoRules {
  uint8_t  magic;
  uint8_t  mode;
  float    soilDryOn;       // ADC đất >= → khô → bơm (AUTO)
  float    soilWetOff;      // ADC đất <= → đủ ẩm → tắt bơm
  uint8_t  darkLightOn;     // 1: tối → bật đèn
  uint16_t gasThreshold;    // giữ field cho app; gas ESP32 đọc D0
  uint8_t  gasOpenDoor;     // 1: gas → mở cửa
  uint8_t  gasPumpOn;       // 1: gas → bật bơm (tuỳ chọn)
  uint8_t  doorHoldSec;
  uint8_t  buzzerOnGas;
  uint8_t  buzzerOnEmpty;   // 1: hết nước → còi
  float    waterEmptyCm;    // khoảng cách >= → hết / thấp nước
  float    waterOkCm;       // khoảng cách <= → đủ nước (hysteresis)
  uint8_t  autoPumpEmpty;   // 1: hết nước → tự bơm (AUTO)
  uint8_t  autoPumpSoil;    // 1: đất khô → tự bơm (AUTO)
  uint8_t  stopPumpRain;    // 1: mua -> khong bom
  uint8_t  gasFanOn;        // 1: gas -> bat quat
  float    tempFanOn;       // >= bat quat
  float    tempFanOff;      // <= tat quat
};

AutoRules rules;

#define TELEMETRY_MS     5000
#define SENSOR_FAST_MS    300
#define HEARTBEAT_MS    30000
#define RECONNECT_MS    10000
#define OLED_MS           400
#define DOOR_OPEN_ANGLE    90
#define DOOR_CLOSE_ANGLE    0
#define SOIL_ADC_MAX     4095
#define WATER_MAX_CM      400.0f
#define US_TIMEOUT_US   30000UL

DHT dht(PIN_DHT, DHTTYPE);
Servo servoDoor;
WebServer webServer(80);
DNSServer dnsServer;
WebSocketsClient wsClient;
MqttClient512 mqttClient;
Adafruit_SSD1306 display(SCREEN_W, SCREEN_H, &Wire, -1);

bool portalActive = false;
bool oledOk = false;
int doorAngle = 0;
String lightState = "OFF";
String pumpState  = "OFF";
String fanState   = "OFF";
bool isGasAlert = false;
bool isDark = false;
bool isRaining = false;
bool isWaterEmpty = false;
bool isSoilDry = false;
bool doorAutoClose = false;
unsigned long doorCloseAt = 0;
char lastFaceName[24] = "";
unsigned long faceMsgUntil = 0;
float lastTemp = NAN;
float lastHumi = NAN;
int lastSoilRaw = 0;
float lastWaterCm = NAN;
float lastWaterFilt = NAN;
uint8_t oledPage = 0;
unsigned long lastPageFlip = 0;
unsigned long showRulesUntil = 0;

unsigned long lastTelemetry = 0;
unsigned long lastFastRead = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastReconnect = 0;
unsigned long lastOled = 0;
int wifiRetries = 0;

// Còi pattern (không block loop)
bool buzzerWant = false;
unsigned long buzzerNextToggle = 0;
bool buzzerPhase = false;

void saveRules();
void loadRules();
void pubMode();
void pubRules();
void pubVitals();
void pubLight();
void pubPump();
void pubFan();
void pubDoor();
void applyAutoLogic();
void mqttCallback(const String& topicStr, const String& payload);

// ─── Kalman 1D cho HC-SR04 ───────────────────────────────────
class Kalman1D {
public:
  float x = 0;      // ước lượng
  float p = 1;      // covariance
  float q = 0.08f;  // process noise
  float r = 2.5f;   // measurement noise (cm^2)
  bool  primed = false;

  float update(float z) {
    if (!primed || isnan(x)) {
      x = z;
      p = 1;
      primed = true;
      return x;
    }
    // predict
    p = p + q;
    // update
    float k = p / (p + r);
    x = x + k * (z - x);
    p = (1.0f - k) * p;
    return x;
  }

  void reset() { primed = false; x = 0; p = 1; }
};

Kalman1D waterKalman;

// ─── GPIO helpers ────────────────────────────────────────────
String relayRead(uint8_t pin) {
  return (digitalRead(pin) == RELAY_ON) ? "ON" : "OFF";
}

void setLight(bool on) {
  digitalWrite(PIN_RELAY1, on ? RELAY_ON : RELAY_OFF);
  lightState = on ? "ON" : "OFF";
}

void setPump(bool on) {
  digitalWrite(PIN_RELAY2, on ? RELAY_ON : RELAY_OFF);
  pumpState = on ? "ON" : "OFF";
}

void setFan(bool on) {
  digitalWrite(PIN_FAN, on ? RELAY_ON : RELAY_OFF);
  fanState = on ? "ON" : "OFF";
}

void adjustDoorAngle(int angle) {
  doorAngle = constrain(angle, 0, 180);
  servoDoor.write(doorAngle);
}

void closeDoorNow() {
  doorAutoClose = false;
  doorCloseAt = 0;
  adjustDoorAngle(DOOR_CLOSE_ANGLE);
}

unsigned long doorHoldMs() {
  uint8_t sec = rules.doorHoldSec;
  if (sec < 1) sec = 5;
  if (sec > 60) sec = 60;
  return (unsigned long)sec * 1000UL;
}

void openDoorForAccess(const char* who) {
  if (who && who[0]) {
    strncpy(lastFaceName, who, sizeof(lastFaceName) - 1);
    lastFaceName[sizeof(lastFaceName) - 1] = '\0';
  } else {
    strncpy(lastFaceName, "Guest", sizeof(lastFaceName) - 1);
  }
  faceMsgUntil = millis() + 4000;
  adjustDoorAngle(DOOR_OPEN_ANGLE);
  doorAutoClose = true;
  doorCloseAt = millis() + doorHoldMs();
  Serial.printf("Door OPEN by %s hold=%us\n", lastFaceName, (unsigned)rules.doorHoldSec);
}

void beep(uint16_t ms = 80) {
  digitalWrite(PIN_BUZZER, HIGH);
  delay(ms);
  digitalWrite(PIN_BUZZER, LOW);
}

void updateBuzzer() {
  // Ưu tiên: gas liên tục; hết nước nhịp 400ms
  bool need = false;
  unsigned long period = 200;
  if (isGasAlert && rules.buzzerOnGas) {
    need = true;
    period = 120;   // nhanh khi gas/CO2
  } else if (isWaterEmpty && rules.buzzerOnEmpty) {
    need = true;
    period = 400;   // chậm khi hết nước
  }

  buzzerWant = need;
  if (!need) {
    digitalWrite(PIN_BUZZER, LOW);
    buzzerPhase = false;
    return;
  }
  unsigned long now = millis();
  if ((long)(now - buzzerNextToggle) >= 0) {
    buzzerPhase = !buzzerPhase;
    digitalWrite(PIN_BUZZER, buzzerPhase ? HIGH : LOW);
    buzzerNextToggle = now + period;
  }
}

// ─── Sensors ─────────────────────────────────────────────────
/** Gas MQ D0: LOW = vượt ngưỡng (phổ biến trên module). */
bool readGasAlert() {
  return digitalRead(PIN_GAS) == LOW;
}

int readSoilAvg() {
  long sum = 0;
  const int n = 12;
  for (int i = 0; i < n; i++) {
    sum += analogRead(PIN_SOIL);
    delayMicroseconds(500);
  }
  int avg = (int)(sum / n);
  if (avg < 0) avg = 0;
  if (avg > SOIL_ADC_MAX) avg = SOIL_ADC_MAX;
  return avg;
}

/** HC-SR04 → cm. Trả NAN nếu lỗi. */
float readUltrasonicCm() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  unsigned long dur = pulseIn(PIN_ECHO, HIGH, US_TIMEOUT_US);
  if (dur == 0) return NAN;
  float cm = (dur * 0.0343f) / 2.0f;
  if (cm < 2.0f || cm > WATER_MAX_CM) return NAN;
  return cm;
}

float readWaterKalman() {
  // trung bình 3 lần đo thô rồi Kalman
  float sum = 0;
  int ok = 0;
  for (int i = 0; i < 3; i++) {
    float d = readUltrasonicCm();
    if (!isnan(d)) {
      sum += d;
      ok++;
    }
    delay(15);
  }
  if (ok == 0) return lastWaterFilt;  // giữ giá trị cũ
  float raw = sum / ok;
  lastWaterCm = raw;
  lastWaterFilt = waterKalman.update(raw);
  return lastWaterFilt;
}

void defaultRules() {
  rules.magic = RULES_MAGIC;
  rules.mode = MODE_MANUAL;
  rules.soilDryOn = 2800.0f;    // ADC cao = khô (tùy module)
  rules.soilWetOff = 2200.0f;
  rules.darkLightOn = 1;
  rules.gasThreshold = 1;       // D0: chỉ dùng làm flag app
  rules.gasOpenDoor = 1;
  rules.gasPumpOn = 0;
  rules.doorHoldSec = 5;
  rules.buzzerOnGas = 1;
  rules.buzzerOnEmpty = 1;
  rules.waterEmptyCm = 25.0f;   // xa hơn → mực thấp / hết nước
  rules.waterOkCm = 18.0f;      // gần hơn → đủ nước
  rules.autoPumpEmpty = 1;
  rules.autoPumpSoil = 1;
  rules.stopPumpRain = 1;
  rules.gasFanOn = 1;
  rules.tempFanOn = 30.0f;
  rules.tempFanOff = 28.0f;
}

void saveRules() {
  rules.magic = RULES_MAGIC;
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(RULES_EEPROM_ADDR, rules);
  EEPROM.commit();
  EEPROM.end();
}

void loadRules() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.get(RULES_EEPROM_ADDR, rules);
  EEPROM.end();
  if (rules.magic != RULES_MAGIC) {
    defaultRules();
    saveRules();
  }
  if (rules.soilWetOff >= rules.soilDryOn) rules.soilWetOff = rules.soilDryOn - 200.0f;
  if (rules.waterOkCm >= rules.waterEmptyCm) rules.waterOkCm = rules.waterEmptyCm - 3.0f;
  if (rules.doorHoldSec < 1 || rules.doorHoldSec > 60) rules.doorHoldSec = 5;
  if (rules.tempFanOff >= rules.tempFanOn) rules.tempFanOff = rules.tempFanOn - 2.0f;
}

// ─── OLED ────────────────────────────────────────────────────
void drawRoundBadge(int x, int y, int w, int h, const char* txt, bool on) {
  if (on) {
    display.fillRoundRect(x, y, w, h, 3, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK);
  } else {
    display.drawRoundRect(x, y, w, h, 3, SSD1306_WHITE);
    display.setTextColor(SSD1306_WHITE);
  }
  display.setCursor(x + 3, y + 3);
  display.print(txt);
  display.setTextColor(SSD1306_WHITE);
}

void i2cScan() {
  Serial.println(F("I2C scan..."));
  byte found = 0;
  for (byte a = 1; a < 127; a++) {
    Wire.beginTransmission(a);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  found 0x%02X\n", a);
      found++;
    }
  }
  if (!found) Serial.println(F("  (khong thay thiet bi I2C)"));
}

void oledInit() {
  Serial.println(F("OLED SSD1306 init (0.96 inch)..."));
  Wire.begin(PIN_OLED_SDA, PIN_OLED_SCL);
  Wire.setClock(100000);
  Wire.setTimeOut(50);
  i2cScan();
  oledOk = display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR);
  if (!oledOk) {
    Serial.println(F("OLED 0x3C fail — thu 0x3D..."));
    oledOk = display.begin(SSD1306_SWITCHCAPVCC, 0x3D);
  }
  if (!oledOk) {
    Serial.println(F("OLED not found — tiep tuc khong man hinh"));
    return;
  }
  display.setRotation(OLED_ROTATION);
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(18, 18);
  display.println(F("SmartHome ESP32"));
  display.setCursor(10, 34);
  display.println(F("Dang khoi dong..."));
  display.drawRoundRect(4, 8, 120, 48, 6, SSD1306_WHITE);
  display.display();
  display.invertDisplay(false);
  display.dim(false);
  Serial.println(F("OLED SSD1306 OK"));
}

void oledDrawPortal() {
  display.clearDisplay();
  display.drawRoundRect(0, 0, 128, 64, 4, SSD1306_WHITE);
  display.setCursor(28, 8);
  display.println(F("WiFi PORTAL"));
  display.drawFastHLine(8, 20, 112, SSD1306_WHITE);
  display.setCursor(10, 28);
  display.println(F("SSID: SmartHome"));
  display.setCursor(10, 42);
  display.println(F("192.168.4.1"));
  display.display();
}

void oledDrawHome() {
  display.clearDisplay();

  display.fillRect(0, 0, 128, 14, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setCursor(4, 3);
  display.print(F("SmartHome32"));
  display.setCursor(78, 3);
  display.print(rules.mode == MODE_AUTO ? F("AUTO") : F("MAN"));
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(4, 18);
  if (!isnan(lastTemp)) {
    display.setTextSize(2);
    display.printf("%.0f", lastTemp);
    display.setTextSize(1);
    display.print(F("C"));
  } else {
    display.setTextSize(2);
    display.print(F("--"));
    display.setTextSize(1);
  }
  display.setCursor(52, 18);
  if (!isnan(lastWaterFilt)) {
    display.setTextSize(2);
    display.printf("%.0f", lastWaterFilt);
    display.setTextSize(1);
    display.print(F("cm"));
  } else {
    display.setTextSize(2);
    display.print(F("--"));
    display.setTextSize(1);
  }

  drawRoundBadge(2, 40, 30, 12, lightState == "ON" ? "DEN*" : "DEN", lightState == "ON");
  drawRoundBadge(34, 40, 30, 12, pumpState == "ON" ? "BOM*" : "BOM", pumpState == "ON");
  drawRoundBadge(66, 40, 30, 12, fanState == "ON" ? "QUAT*" : "QUAT", fanState == "ON");
  drawRoundBadge(98, 40, 28, 12,
                 isGasAlert ? "GAS" : (isWaterEmpty ? "HET" : "OK"),
                 isGasAlert || isWaterEmpty);

  display.setCursor(4, 55);
  display.printf("%s%s S:%d%s%s",
                 WiFi.status() == WL_CONNECTED ? "W" : "-",
                 mqttClient.isConnected() ? "M" : "-",
                 lastSoilRaw / 100,
                 isRaining ? " R" : "",
                 isDark ? " T" : " S");

  if (millis() < faceMsgUntil && lastFaceName[0]) {
    display.fillRect(0, 52, 128, 12, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK);
    display.setCursor(4, 54);
    display.printf("Hi %s", lastFaceName);
    display.setTextColor(SSD1306_WHITE);
  }

  display.display();
}

void oledDrawRules() {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 14, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setCursor(4, 3);
  display.print(rules.mode == MODE_AUTO ? F("RULES*AUTO") : F("RULES*MAN"));
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(4, 18);
  display.printf("Dat %.0f/%.0f", rules.soilDryOn, rules.soilWetOff);
  display.setCursor(4, 30);
  display.printf("Nuoc >=%.0fcm het", rules.waterEmptyCm);
  display.setCursor(4, 42);
  display.printf("Den:%s BomE:%d BomS:%d",
                 rules.darkLightOn ? "TOI" : "OFF",
                 rules.autoPumpEmpty, rules.autoPumpSoil);
  display.setCursor(4, 54);
  display.printf("%s%s hold%ds",
                 rules.gasOpenDoor ? "DOOR " : "",
                 rules.buzzerOnGas ? "BZZ " : "",
                 (int)rules.doorHoldSec);
  display.display();
}

void forceOledRulesPage(unsigned long holdMs = 8000) {
  oledPage = 1;
  lastPageFlip = millis();
  showRulesUntil = millis() + holdMs;
}

void oledDraw() {
  if (!oledOk) return;
  if (portalActive) {
    oledDrawPortal();
    return;
  }
  if (showRulesUntil != 0 && (long)(millis() - showRulesUntil) < 0) {
    oledPage = 1;
  } else if (millis() - lastPageFlip > 5000) {
    lastPageFlip = millis();
    oledPage = (oledPage + 1) % 2;
    showRulesUntil = 0;
  }
  if (oledPage == 0) oledDrawHome();
  else oledDrawRules();
}

// ─── EEPROM WiFi ─────────────────────────────────────────────
void saveWifiList() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(0, wifiCount);
  int addr = sizeof(wifiCount);
  for (int i = 0; i < MAX_WIFI; i++) {
    EEPROM.put(addr, wifiList[i]);
    addr += sizeof(WifiEntry);
  }
  EEPROM.commit();
  EEPROM.end();
}

void loadWifiList() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.get(0, wifiCount);
  if (wifiCount < 0 || wifiCount > MAX_WIFI) wifiCount = 0;
  int addr = sizeof(wifiCount);
  for (int i = 0; i < MAX_WIFI; i++) {
    EEPROM.get(addr, wifiList[i]);
    addr += sizeof(WifiEntry);
  }
  EEPROM.end();
}

void addOrUpdateWifi(String ssid, String pass) {
  for (int i = 0; i < wifiCount; i++) {
    if (String(wifiList[i].ssid) == ssid) {
      pass.toCharArray(wifiList[i].pass, 32);
      saveWifiList();
      return;
    }
  }
  if (wifiCount >= MAX_WIFI) {
    for (int i = 0; i < MAX_WIFI - 1; i++) wifiList[i] = wifiList[i + 1];
    wifiCount = MAX_WIFI - 1;
  }
  ssid.toCharArray(wifiList[wifiCount].ssid, 32);
  pass.toCharArray(wifiList[wifiCount].pass, 32);
  wifiCount++;
  saveWifiList();
}

bool connectBestWifi() {
  Serial.println(F("\nQuet WiFi..."));
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  if (wifiCount == 0) return false;

  int n = WiFi.scanNetworks();
  int bestIdx = -1, bestRSSI = -999;
  if (n > 0) {
    for (int i = 0; i < n; i++) {
      String scannedSSID = WiFi.SSID(i);
      int rssi = WiFi.RSSI(i);
      for (int w = 0; w < wifiCount; w++) {
        if (String(wifiList[w].ssid) == scannedSSID && rssi > bestRSSI) {
          bestRSSI = rssi;
          bestIdx = w;
        }
      }
    }
    WiFi.scanDelete();
  }
  if (bestIdx < 0) bestIdx = wifiCount - 1;

  WiFi.begin(wifiList[bestIdx].ssid, wifiList[bestIdx].pass);
  for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print('.');
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi OK " + WiFi.localIP().toString());
    return true;
  }
  return false;
}

// ─── AUTO logic ──────────────────────────────────────────────
void applyAutoLogic() {
  if (rules.mode != MODE_AUTO) return;

  // Đèn theo LDR
  if (rules.darkLightOn) {
    bool wantLight = isDark;
    if ((lightState == "ON") != wantLight) {
      setLight(wantLight);
      pubLight();
    }
  }

  // Bơm: hết nước (HC-SR04) và/hoặc đất khô — hysteresis đất qua isSoilDry
  bool wantPump = false;
  if (rules.autoPumpEmpty && isWaterEmpty) wantPump = true;
  if (rules.autoPumpSoil && isSoilDry) wantPump = true;
  if (rules.gasPumpOn && isGasAlert) wantPump = true;
  if (rules.stopPumpRain && isRaining) wantPump = false;

  if ((pumpState == "ON") != wantPump) {
    setPump(wantPump);
    pubPump();
    Serial.printf("AUTO pump => %s empty=%d soilDry=%d rain=%d\n",
                  wantPump ? "ON" : "OFF", isWaterEmpty, isSoilDry, isRaining);
  }


  // Quat theo nhiet + gas
  bool wantFan = false;
  if (!isnan(lastTemp)) {
    if (fanState == "ON") wantFan = (lastTemp > rules.tempFanOff);
    else wantFan = (lastTemp >= rules.tempFanOn);
  }
  if (rules.gasFanOn && isGasAlert) wantFan = true;
  if ((fanState == "ON") != wantFan) {
    setFan(wantFan);
    pubFan();
  }

  if (rules.gasOpenDoor && isGasAlert && doorAngle < 45) {
    openDoorForAccess("GasAlert");
    pubDoor();
  }
}

// ─── MQTT ────────────────────────────────────────────────────
void mqttPub(const char* device, const String& payload) {
  if (!mqttClient.isConnected()) return;
  mqttClient.publish(String("tele/") + device + "/status", payload, false, 0);
}

void pubOnline() { mqttPub(CHIP_ID, "online"); }
void pubTemp(float t) { mqttPub(DEV_TEMP, "{\"value\":" + String(t, 1) + "}"); }
void pubHumi(float h) { mqttPub(DEV_HUMI, "{\"value\":" + String(h, 1) + "}"); }
void pubLight() {
  lightState = relayRead(PIN_RELAY1);
  mqttPub(DEV_LIGHT, "{\"value\":\"" + lightState + "\"}");
}
void pubPump() {
  pumpState = relayRead(PIN_RELAY2);
  mqttPub(DEV_PUMP, "{\"value\":\"" + pumpState + "\"}");
}
void pubFan() {
  fanState = relayRead(PIN_FAN);
  mqttPub(DEV_FAN, "{\"value\":\"" + fanState + "\"}");
}
void pubDoor() { mqttPub(DEV_DOOR, "{\"value\":" + String(doorAngle) + "}"); }
void pubGas() {
  mqttPub(DEV_GAS, isGasAlert ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}");
}
void pubLdr() {
  mqttPub(DEV_LDR, isDark ? "{\"value\":\"DARK\"}" : "{\"value\":\"LIGHT\"}");
}
void pubSoil() {
  mqttPub(DEV_SOIL, "{\"value\":" + String(lastSoilRaw) +
                    ",\"dry\":" + String(isSoilDry ? 1 : 0) + "}");
}
void pubRain() {
  mqttPub(DEV_RAIN, isRaining ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}");
}
void pubWater() {
  String j = "{";
  j += "\"cm\":" + String(isnan(lastWaterFilt) ? 0 : lastWaterFilt, 1) + ",";
  j += "\"raw\":" + String(isnan(lastWaterCm) ? 0 : lastWaterCm, 1) + ",";
  j += "\"empty\":" + String(isWaterEmpty ? 1 : 0);
  j += "}";
  mqttPub(DEV_WATER, j);
}
void pubFaceEvent(const char* name, const char* action) {
  mqttPub(DEV_FACE, String("{\"name\":\"") + name + "\",\"action\":\"" + action + "\"}");
}
void pubMode() {
  mqttPub(DEV_MODE, rules.mode == MODE_AUTO ? "{\"value\":\"AUTO\"}" : "{\"value\":\"MANUAL\"}");
}
void pubRules() {
  String j = "{";
  j += "\"mode\":\"" + String(rules.mode == MODE_AUTO ? "AUTO" : "MANUAL") + "\",";
  j += "\"soilDryOn\":" + String(rules.soilDryOn, 0) + ",";
  j += "\"soilWetOff\":" + String(rules.soilWetOff, 0) + ",";
  j += "\"darkLightOn\":" + String(rules.darkLightOn ? 1 : 0) + ",";
  j += "\"gasThreshold\":" + String(rules.gasThreshold) + ",";
  j += "\"gasOpenDoor\":" + String(rules.gasOpenDoor ? 1 : 0) + ",";
  j += "\"gasPumpOn\":" + String(rules.gasPumpOn ? 1 : 0) + ",";
  j += "\"gasFanOn\":" + String(rules.gasPumpOn ? 1 : 0) + ","; // alias app cũ
  j += "\"doorHoldSec\":" + String(rules.doorHoldSec) + ",";
  j += "\"buzzerOnGas\":" + String(rules.buzzerOnGas ? 1 : 0) + ",";
  j += "\"buzzerOnEmpty\":" + String(rules.buzzerOnEmpty ? 1 : 0) + ",";
  j += "\"waterEmptyCm\":" + String(rules.waterEmptyCm, 1) + ",";
  j += "\"waterOkCm\":" + String(rules.waterOkCm, 1) + ",";
  j += "\"autoPumpEmpty\":" + String(rules.autoPumpEmpty ? 1 : 0) + ",";
  j += "\"autoPumpSoil\":" + String(rules.autoPumpSoil ? 1 : 0) + ",";
  j += "\"stopPumpRain\":" + String(rules.stopPumpRain ? 1 : 0) + ",";
  j += "\"gasFanOn\":" + String(rules.gasFanOn ? 1 : 0) + ",";
  j += "\"tempFanOn\":" + String(rules.tempFanOn, 1) + ",";
  j += "\"tempFanOff\":" + String(rules.tempFanOff, 1);
  j += "}";
  mqttPub(DEV_RULES, j);
}
void pubVitals() {
  String j = "{";
  j += "\"temp\":" + String(isnan(lastTemp) ? 0 : lastTemp, 1) + ",";
  j += "\"humi\":" + String(isnan(lastHumi) ? 0 : lastHumi, 1) + ",";
  j += "\"gasAlert\":" + String(isGasAlert ? 1 : 0) + ",";
  j += "\"dark\":" + String(isDark ? 1 : 0) + ",";
  j += "\"light\":\"" + lightState + "\",";
  j += "\"fan\":\"" + fanState + "\",";
  j += "\"pump\":\"" + pumpState + "\",";
  j += "\"door\":" + String(doorAngle) + ",";
  j += "\"soil\":" + String(lastSoilRaw) + ",";
  j += "\"soilDry\":" + String(isSoilDry ? 1 : 0) + ",";
  j += "\"rain\":" + String(isRaining ? 1 : 0) + ",";
  j += "\"waterCm\":" + String(isnan(lastWaterFilt) ? 0 : lastWaterFilt, 1) + ",";
  j += "\"waterEmpty\":" + String(isWaterEmpty ? 1 : 0) + ",";
  j += "\"mode\":\"" + String(rules.mode == MODE_AUTO ? "AUTO" : "MANUAL") + "\"";
  j += "}";
  mqttPub(DEV_VITALS, j);
}

String jsonValueToken(const String& s, const char* key) {
  String k = String("\"") + key + "\"";
  int i = s.indexOf(k);
  if (i < 0) return "";
  int c = s.indexOf(':', i + k.length());
  if (c < 0) return "";
  int p = c + 1;
  while (p < (int)s.length() && (s[p] == ' ' || s[p] == '\t' || s[p] == '\n' || s[p] == '\r')) p++;
  int end = p;
  while (end < (int)s.length()) {
    char ch = s[end];
    if (ch == ',' || ch == '}' || ch == ']' || ch == ' ') break;
    end++;
  }
  return s.substring(p, end);
}

float jsonFloat(const String& s, const char* key, float defv) {
  String tok = jsonValueToken(s, key);
  if (tok.length() == 0) return defv;
  return tok.toFloat();
}

int jsonInt(const String& s, const char* key, int defv) {
  String tok = jsonValueToken(s, key);
  if (tok.length() == 0) return defv;
  return tok.toInt();
}

bool jsonHasKey(const String& s, const char* key) {
  return s.indexOf(String("\"") + key + "\"") >= 0;
}

void handleModePayload(String cmd) {
  cmd.trim();
  cmd.toUpperCase();
  if (cmd.indexOf("AUTO") >= 0) rules.mode = MODE_AUTO;
  else if (cmd.indexOf("MANUAL") >= 0 || cmd.indexOf("MAN") >= 0) rules.mode = MODE_MANUAL;
  else if (cmd == "ON" || cmd == "1") rules.mode = MODE_AUTO;
  else if (cmd == "OFF" || cmd == "0") rules.mode = MODE_MANUAL;
  saveRules();
  pubMode();
  pubRules();
  pubVitals();
  if (rules.mode == MODE_AUTO) applyAutoLogic();
  forceOledRulesPage();
  beep(40);
  Serial.printf("Mode => %s\n", rules.mode == MODE_AUTO ? "AUTO" : "MANUAL");
}

void handleRulesPayload(String cmd) {
  cmd.trim();
  Serial.printf("Rules RX (%u): %s\n", (unsigned)cmd.length(), cmd.c_str());
  if (cmd.length() < 2) return;

  if (!jsonHasKey(cmd, "soilDryOn") && !jsonHasKey(cmd, "waterEmptyCm") &&
      !jsonHasKey(cmd, "gasThreshold") && !jsonHasKey(cmd, "doorHoldSec") &&
      !jsonHasKey(cmd, "tempFanOn") &&
      (cmd.indexOf("AUTO") >= 0 || cmd.indexOf("MANUAL") >= 0) &&
      !cmd.startsWith("{")) {
    handleModePayload(cmd);
    return;
  }

  if (cmd.startsWith("{") || jsonHasKey(cmd, "soilDryOn") || jsonHasKey(cmd, "waterEmptyCm") ||
      jsonHasKey(cmd, "gasThreshold") || jsonHasKey(cmd, "tempFanOn")) {
    if (jsonHasKey(cmd, "mode")) {
      String m = jsonValueToken(cmd, "mode");
      m.replace("\"", "");
      m.toUpperCase();
      if (m.indexOf("AUTO") >= 0) rules.mode = MODE_AUTO;
      else if (m.indexOf("MANUAL") >= 0) rules.mode = MODE_MANUAL;
    }
    // Đất — ưu tiên key mới; map tempFan* nếu app cũ còn gửi
    if (jsonHasKey(cmd, "soilDryOn")) rules.soilDryOn = jsonFloat(cmd, "soilDryOn", rules.soilDryOn);
    else if (jsonHasKey(cmd, "tempFanOn")) rules.soilDryOn = jsonFloat(cmd, "tempFanOn", rules.soilDryOn) * 100.0f;
    if (jsonHasKey(cmd, "soilWetOff")) rules.soilWetOff = jsonFloat(cmd, "soilWetOff", rules.soilWetOff);
    else if (jsonHasKey(cmd, "tempFanOff")) rules.soilWetOff = jsonFloat(cmd, "tempFanOff", rules.soilWetOff) * 100.0f;

    if (jsonHasKey(cmd, "darkLightOn")) rules.darkLightOn = jsonInt(cmd, "darkLightOn", rules.darkLightOn) ? 1 : 0;
    if (jsonHasKey(cmd, "gasThreshold")) {
      int g = jsonInt(cmd, "gasThreshold", rules.gasThreshold);
      if (g < 0) g = 0;
      rules.gasThreshold = (uint16_t)g;
    }
    if (jsonHasKey(cmd, "gasOpenDoor")) rules.gasOpenDoor = jsonInt(cmd, "gasOpenDoor", rules.gasOpenDoor) ? 1 : 0;
    if (jsonHasKey(cmd, "gasPumpOn")) rules.gasPumpOn = jsonInt(cmd, "gasPumpOn", rules.gasPumpOn) ? 1 : 0;
    if (jsonHasKey(cmd, "gasFanOn")) rules.gasFanOn = jsonInt(cmd, "gasFanOn", rules.gasFanOn) ? 1 : 0;
    if (jsonHasKey(cmd, "tempFanOn")) rules.tempFanOn = jsonFloat(cmd, "tempFanOn", rules.tempFanOn);
    if (jsonHasKey(cmd, "tempFanOff")) rules.tempFanOff = jsonFloat(cmd, "tempFanOff", rules.tempFanOff);
    if (jsonHasKey(cmd, "doorHoldSec")) {
      int s = jsonInt(cmd, "doorHoldSec", rules.doorHoldSec);
      if (s < 1) s = 1;
      if (s > 60) s = 60;
      rules.doorHoldSec = (uint8_t)s;
    }
    if (jsonHasKey(cmd, "buzzerOnGas")) rules.buzzerOnGas = jsonInt(cmd, "buzzerOnGas", rules.buzzerOnGas) ? 1 : 0;
    if (jsonHasKey(cmd, "buzzerOnEmpty")) rules.buzzerOnEmpty = jsonInt(cmd, "buzzerOnEmpty", rules.buzzerOnEmpty) ? 1 : 0;
    if (jsonHasKey(cmd, "waterEmptyCm")) rules.waterEmptyCm = jsonFloat(cmd, "waterEmptyCm", rules.waterEmptyCm);
    if (jsonHasKey(cmd, "waterOkCm")) rules.waterOkCm = jsonFloat(cmd, "waterOkCm", rules.waterOkCm);
    if (jsonHasKey(cmd, "autoPumpEmpty")) rules.autoPumpEmpty = jsonInt(cmd, "autoPumpEmpty", rules.autoPumpEmpty) ? 1 : 0;
    if (jsonHasKey(cmd, "autoPumpSoil")) rules.autoPumpSoil = jsonInt(cmd, "autoPumpSoil", rules.autoPumpSoil) ? 1 : 0;
    if (jsonHasKey(cmd, "stopPumpRain")) rules.stopPumpRain = jsonInt(cmd, "stopPumpRain", rules.stopPumpRain) ? 1 : 0;
  } else {
    Serial.println(F("Rules: payload khong nhan dien JSON"));
    return;
  }

  if (rules.soilWetOff >= rules.soilDryOn) rules.soilWetOff = rules.soilDryOn - 200.0f;
  if (rules.waterOkCm >= rules.waterEmptyCm) rules.waterOkCm = rules.waterEmptyCm - 3.0f;
  saveRules();
  pubRules();
  pubMode();
  pubVitals();
  if (rules.mode == MODE_AUTO) applyAutoLogic();
  forceOledRulesPage(12000);
  digitalWrite(PIN_BUZZER, HIGH);
  delay(30);
  digitalWrite(PIN_BUZZER, LOW);
  Serial.printf("Rules OK soil=%.0f/%.0f water=%.1f/%.1f mode=%s\n",
                rules.soilDryOn, rules.soilWetOff, rules.waterEmptyCm, rules.waterOkCm,
                rules.mode == MODE_AUTO ? "AUTO" : "MANUAL");
}

void handleFacePayload(String cmd) {
  cmd.trim();
  String name = "Guest";
  if (cmd.startsWith("{")) {
    int nKey = cmd.indexOf("\"name\"");
    if (nKey >= 0) {
      int q1 = cmd.indexOf('"', nKey + 6);
      q1 = cmd.indexOf('"', q1 + 1);
      int q2 = cmd.indexOf('"', q1 + 1);
      if (q1 >= 0 && q2 > q1) name = cmd.substring(q1 + 1, q2);
    }
    String up = cmd; up.toUpperCase();
    if (up.indexOf("\"CLOSE\"") >= 0 || up.indexOf("\"OFF\"") >= 0) {
      closeDoorNow(); pubDoor(); pubFaceEvent(name.c_str(), "CLOSE"); return;
    }
  } else {
    String up = cmd; up.toUpperCase();
    if (up == "OFF" || up == "CLOSE" || up == "0") {
      closeDoorNow(); pubDoor(); pubFaceEvent("System", "CLOSE"); return;
    }
    if (up != "ON" && up != "OPEN" && up != "1" && cmd.length() > 0) name = cmd;
  }
  beep(60);
  openDoorForAccess(name.c_str());
  pubDoor();
  pubFaceEvent(name.c_str(), "OPEN");
}

void handleDoorPayload(String cmd) {
  cmd.trim();
  String up = cmd; up.toUpperCase();
  if (up == "ON" || up == "OPEN") { openDoorForAccess("Remote"); pubDoor(); return; }
  if (up == "OFF" || up == "CLOSE") { closeDoorNow(); pubDoor(); return; }
  if (cmd.length() && (isDigit(cmd.charAt(0)) || cmd.charAt(0) == '-')) {
    doorAutoClose = false;
    adjustDoorAngle(cmd.toInt());
    pubDoor();
  }
}

void mqttCallback(const String& topicStr, const String& payload) {
  String topic = topicStr;
  String cmd = payload;
  cmd.trim();
  Serial.printf("MQTT %s <= %s\n", topic.c_str(), cmd.c_str());

  if (topic.indexOf(DEV_MODE) >= 0) {
    handleModePayload(cmd);
  } else if (topic.indexOf(DEV_RULES) >= 0) {
    if (topic.indexOf("/GET") >= 0 || cmd.equalsIgnoreCase("GET") || cmd.equalsIgnoreCase("STATUS")) {
      pubRules();
      pubMode();
      forceOledRulesPage(8000);
    } else {
      handleRulesPayload(cmd);
    }
  } else if (topic.indexOf(DEV_FACE) >= 0) {
    handleFacePayload(cmd);
  } else if (topic.indexOf(DEV_DOOR) >= 0) {
    handleDoorPayload(cmd);
  } else if (topic.indexOf(DEV_LIGHT) >= 0) {
    if (rules.mode == MODE_MANUAL) {
      setLight(cmd == "ON");
      pubLight();
      pubVitals();
    } else {
      Serial.println(F("Bo qua den: dang AUTO"));
    }
  } else if (topic.indexOf(DEV_PUMP) >= 0) {
    if (rules.mode == MODE_MANUAL) {
      setPump(cmd == "ON");
      pubPump();
      pubVitals();
    } else {
      Serial.println(F("Bo qua bom: dang AUTO"));
    }
  } else if (topic.indexOf(DEV_FAN) >= 0) {
    if (rules.mode == MODE_MANUAL) {
      setFan(cmd == "ON");
      pubFan();
      pubVitals();
    } else {
      Serial.println(F("Bo qua quat: dang AUTO"));
    }
  }
}

void reconnectMQTT() {
  if (mqttClient.isConnected()) return;
  Serial.printf("MQTT WSS ... ");
  uint64_t mac = ESP.getEfuseMac();
  String clientId = "ESP32-" + String((uint32_t)(mac >> 16), HEX);
  mqttClient.setWill(String("tele/") + CHIP_ID + "/status", "offline", true, 1);
  if (!mqttClient.connect(clientId, "", "")) {
    Serial.println(F("fail"));
    return;
  }
  Serial.println(F("OK"));
  pubOnline();
  wsClient.loop(); delay(30);

  auto sub = [](const String& topic) {
    mqttClient.subscribe(topic, [topic](const char* p, unsigned int n) {
      String cmd; for (unsigned int i = 0; i < n; i++) cmd += p[i];
      mqttCallback(topic, cmd);
    });
    wsClient.loop(); delay(30);
  };

  sub(String("cmnd/") + DEV_LIGHT + "/POWER");
  sub(String("cmnd/") + DEV_PUMP + "/POWER");
  sub(String("cmnd/") + DEV_FAN + "/POWER");
  sub(String("cmnd/") + DEV_DOOR + "/POWER");
  sub(String("cmnd/") + DEV_FACE + "/POWER");
  sub(String("cmnd/") + DEV_MODE + "/POWER");
  sub(String("cmnd/") + DEV_RULES + "/SET");
  sub(String("cmnd/") + DEV_RULES + "/POWER");
  sub(String("cmnd/") + DEV_RULES + "/GET");

  forceOledRulesPage(10000);
  pubMode();
  pubRules();
  pubVitals();
  pubLight(); wsClient.loop(); delay(20);
  pubPump();
  pubFan();
  pubDoor();
  pubGas();
  pubLdr();
  pubSoil();
  pubRain();
  pubWater();
}

// ─── Portal ──────────────────────────────────────────────────
const char PORTAL_HTML[] PROGMEM = R"rawhtml(
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartHome</title>
<style>body{font-family:sans-serif;background:#0a0e1a;color:#e2e8f0;display:flex;justify-content:center;padding:20px}
.c{max-width:400px;width:100%}input{width:100%;padding:10px;margin-bottom:10px;border-radius:5px;border:none;box-sizing:border-box}
button{padding:10px;width:100%;background:#0ea5e9;color:#fff;border:none;border-radius:5px;font-weight:bold}</style>
</head><body><div class="c"><h2>SmartHome ESP32 WiFi</h2>
<button onclick="scan()" style="margin-bottom:10px;background:#6366f1">Quet mang</button>
<div id="w"></div>
<input id="s" placeholder="Ten WiFi"><input type="password" id="p" placeholder="Mat khau">
<button onclick="conn()">Ket noi</button><div id="st"></div></div>
<script>
function scan(){document.getElementById('w').innerHTML='Dang quet...';fetch('/scan').then(r=>r.json()).then(l=>{
document.getElementById('w').innerHTML=l.map(n=>`<div style="padding:6px;background:#1e293b;margin:4px 0;border-radius:6px" onclick="document.getElementById('s').value='${n.ssid}'">${n.ssid} (${n.rssi})</div>`).join('')
}).catch(()=>document.getElementById('w').innerHTML='Loi')}
function conn(){const s=document.getElementById('s').value,p=document.getElementById('p').value;if(!s)return alert('Nhap WiFi');
const st=document.getElementById('st');st.innerHTML='Dang ket noi...';
fetch('/connect',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'ssid='+encodeURIComponent(s)+'&pass='+encodeURIComponent(p)})
.then(r=>r.json()).then(d=>{st.innerHTML=d.ok?'OK restart...':'Loi: '+(d.message||'')})}
</script></body></html>
)rawhtml";

void handleNotFound() {
  webServer.sendHeader("Location", "http://192.168.4.1/", true);
  webServer.send(302, "text/plain", "");
}
void handleRoot() { webServer.send_P(200, "text/html", PORTAL_HTML); }
void handleScan() {
  int n = WiFi.scanNetworks();
  String json = "[";
  for (int i = 0; i < n; i++) {
    if (i) json += ',';
    json += "{\"ssid\":\"" + WiFi.SSID(i) + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
  }
  json += "]";
  WiFi.scanDelete();
  webServer.send(200, "application/json", json);
}
void handleConnect() {
  String ssid = webServer.arg("ssid");
  String pass = webServer.arg("pass");
  if (!ssid.length()) {
    webServer.send(200, "application/json", "{\"ok\":false,\"message\":\"empty\"}");
    return;
  }
  WiFi.begin(ssid.c_str(), pass.c_str());
  for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) delay(500);
  if (WiFi.status() == WL_CONNECTED) {
    addOrUpdateWifi(ssid, pass);
    webServer.send(200, "application/json", "{\"ok\":true}");
    delay(800);
    ESP.restart();
  } else {
    WiFi.disconnect();
    webServer.send(200, "application/json", "{\"ok\":false,\"message\":\"fail\"}");
  }
}
void startPortal() {
  portalActive = true;
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  bool apOk = WiFi.softAP(AP_SSID, AP_PASSWORD);
  Serial.printf("softAP(%s) => %d IP=%s\n", AP_SSID, apOk ? 1 : 0,
                WiFi.softAPIP().toString().c_str());
  dnsServer.start(DNS_PORT, "*", apIP);
  webServer.on("/", HTTP_GET, handleRoot);
  webServer.on("/scan", HTTP_GET, handleScan);
  webServer.on("/connect", HTTP_POST, handleConnect);
  webServer.onNotFound(handleNotFound);
  webServer.begin();
  oledDraw();
}

// Double-reset (ESP32 RTC)
#define DOUBLE_RESET_MAGIC 0x12345678
RTC_DATA_ATTR uint32_t rtcData = 0;
bool isDoubleReset = false;

void checkDoubleReset() {
  if (rtcData == DOUBLE_RESET_MAGIC) {
    isDoubleReset = true;
    rtcData = 0;
    wifiCount = 0;
    saveWifiList();
  } else {
    isDoubleReset = false;
    rtcData = DOUBLE_RESET_MAGIC;
  }
}
void clearDoubleResetFlag() {
  if (rtcData == DOUBLE_RESET_MAGIC) rtcData = 0;
}

void setup() {
  // Relay ACTIVE HIGH → ghi LOW ngay để tắt
  pinMode(PIN_RELAY1, OUTPUT);
  pinMode(PIN_RELAY2, OUTPUT);
  pinMode(PIN_FAN, OUTPUT);
  digitalWrite(PIN_RELAY1, RELAY_OFF);
  digitalWrite(PIN_RELAY2, RELAY_OFF);
  digitalWrite(PIN_FAN, RELAY_OFF);
  lightState = "OFF";
  pumpState = "OFF";
  fanState = "OFF";

  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  pinMode(PIN_LDR, INPUT_PULLUP);
  pinMode(PIN_GAS, INPUT_PULLUP);
  pinMode(PIN_RAIN, INPUT);       // GPIO35 input-only, không pull nội
  pinMode(PIN_SOIL, INPUT);
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  digitalWrite(PIN_TRIG, LOW);

  Serial.begin(115200);
  delay(200);
  Serial.println(F("\n=== SmartHome ESP32 AUTO/MANUAL ==="));
  Serial.println(F("Relay ACTIVE HIGH | Gas D0 GPIO26 | Water HC-SR04 Kalman"));
  Serial.println(F("IN1=Den32 IN2=Bom33 FAN=GPIO19 ChipID=esp32"));

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  Serial.println(F("DHT..."));
  dht.begin();
  Serial.println(F("Rules EEPROM..."));
  loadRules();
  oledInit();

  Serial.println(F("Buzzer test..."));
  beep(80);
  delay(40);
  beep(80);
  digitalWrite(PIN_BUZZER, LOW);

  Serial.println(F("Servo..."));
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  servoDoor.setPeriodHertz(50);
  servoDoor.attach(PIN_DOOR, 500, 2400);
  delay(40);
  closeDoorNow();

  wsClient.beginSSL(MQTT_HOST, MQTT_PORT, MQTT_PATH);
  wsClient.setExtraHeaders("Sec-WebSocket-Protocol: mqtt");
  mqttClient.begin(wsClient);

  loadWifiList();
  // EEPROM rác sau chip mới: wifiCount ảo → không bao giờ vào portal
  bool wifiLooksValid = false;
  for (int i = 0; i < wifiCount; i++) {
    if (wifiList[i].ssid[0] != 0 && wifiList[i].ssid[0] != (char)0xFF) {
      wifiLooksValid = true;
      break;
    }
  }
  if (!wifiLooksValid) wifiCount = 0;

  checkDoubleReset();
  Serial.printf("wifiCount=%d doubleReset=%d\n", wifiCount, isDoubleReset ? 1 : 0);

  if (isDoubleReset) {
    Serial.println(F("=> WiFi PORTAL (double reset)"));
    startPortal();
  } else if (!(wifiCount > 0 && connectBestWifi())) {
    Serial.println(F("=> WiFi PORTAL (chua co / fail)"));
    startPortal();
  } else {
    Serial.println(F("=> WiFi STA OK"));
    oledDraw();
  }
  Serial.printf("AP SoftAP SSID=%s portal=%d\n", AP_SSID, portalActive ? 1 : 0);
}

void loop() {
  if (millis() > 3000 && rtcData == DOUBLE_RESET_MAGIC) clearDoubleResetFlag();

  updateBuzzer();

  if (portalActive) {
    dnsServer.processNextRequest();
    webServer.handleClient();
    if (millis() - lastOled >= OLED_MS) { lastOled = millis(); oledDraw(); }
    return;
  }

  unsigned long now = millis();

  if (doorAutoClose && (long)(now - doorCloseAt) >= 0) {
    closeDoorNow();
    pubDoor();
  }

  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastReconnect >= RECONNECT_MS) {
      lastReconnect = now;
      if (connectBestWifi()) wifiRetries = 0;
      else if (++wifiRetries >= 3) { startPortal(); wifiRetries = 0; }
    }
    return;
  }
  wifiRetries = 0;

  wsClient.loop();
  mqttClient.update();
  if (!mqttClient.isConnected() && now - lastReconnect >= 5000) {
    lastReconnect = now;
    reconnectMQTT();
  }

  if (now - lastFastRead >= SENSOR_FAST_MS) {
    lastFastRead = now;

    // Gas D0
    bool gasAlert = readGasAlert();
    if (gasAlert != isGasAlert) {
      isGasAlert = gasAlert;
      pubGas();
      pubVitals();
      Serial.printf("Gas ALERT=%d\n", isGasAlert);
    }

    // LDR
    bool dark = (digitalRead(PIN_LDR) == HIGH);
    if (dark != isDark) {
      isDark = dark;
      pubLdr();
    }

    // Mưa D0 — nhiều module LOW = có mưa
    bool rain = (digitalRead(PIN_RAIN) == LOW);
    if (rain != isRaining) {
      isRaining = rain;
      pubRain();
      pubVitals();
    }

    // Đất analog
    lastSoilRaw = readSoilAvg();
    bool soilDry;
    if (isSoilDry) {
      soilDry = (lastSoilRaw > (int)rules.soilWetOff);
    } else {
      soilDry = (lastSoilRaw >= (int)rules.soilDryOn);
    }
    if (soilDry != isSoilDry) {
      isSoilDry = soilDry;
      pubSoil();
      pubVitals();
    }

    // Mực nước Kalman
    float w = readWaterKalman();
    if (!isnan(w)) {
      bool empty;
      if (isWaterEmpty) {
        empty = (w > rules.waterOkCm);     // hết → chỉ hết khi vẫn > ok
      } else {
        empty = (w >= rules.waterEmptyCm);
      }
      if (empty != isWaterEmpty) {
        isWaterEmpty = empty;
        pubWater();
        pubVitals();
        Serial.printf("Water empty=%d cm=%.1f (raw=%.1f)\n",
                      isWaterEmpty, lastWaterFilt, lastWaterCm);
      }
    }

    applyAutoLogic();
  }

  if (now - lastHeartbeat >= HEARTBEAT_MS) {
    lastHeartbeat = now;
    pubOnline();
    pubMode();
  }

  if (now - lastTelemetry >= TELEMETRY_MS) {
    lastTelemetry = now;
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    if (!isnan(t) && !isnan(h)) {
      lastTemp = t;
      lastHumi = h;
      pubTemp(t);
      pubHumi(h);
    }
    pubSoil();
    pubWater();
    pubRain();
    pubVitals();
    applyAutoLogic();
  }

  if (now - lastOled >= OLED_MS) {
    lastOled = now;
    oledDraw();
  }
}
