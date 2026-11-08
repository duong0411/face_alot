/*
 * SmartHome ESP8266 — OLED UI + AUTO/MANUAL + Face Door
 *
 * PINOUT:
 *  OLED SCL/SDA → D1/D2 | Relay1 D5 | Relay2 D6
 *  DHT11 D7 | Gas A0 | LDR D3 | Buzzer D8 | Servo cửa D0
 *  Wiring thực tế: RELAY1(led1)=quạt, RELAY2(fan)=đèn — AUTO/MANUAL theo pin thật
 *
 * MQTT:
 *  cmnd/123_mode/POWER          AUTO|MANUAL
 *  cmnd/123_rules/SET           JSON ngưỡng auto
 *  cmnd/123_led1/POWER          ON|OFF   (chỉ MANUAL)
 *  cmnd/123_fan_livingroom/POWER ON|OFF  (chỉ MANUAL)
 *  cmnd/123_door_livingroom1/POWER | cmnd/123_face_livingroom/POWER
 *  tele/123_mode|/123_rules|/sensors ...
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include <WebSocketsClient.h>
#include <MQTTPubSubClient.h>
#include "DHT.h"
#include <Servo.h>

// Buffer MQTT mặc định chỉ 128 — JSON rules/vitals bị cắt → rule mobile không xuống ESP
using MqttClient512 = arduino::mqtt::PubSubClient<512>;

#define PIN_OLED_SDA  4
#define PIN_OLED_SCL  5
#define PIN_RELAY1   14   // topic led1 — dây thực = quạt
#define PIN_RELAY2   12   // topic fan  — dây thực = đèn
#define PIN_DHT      13
#define PIN_GAS      A0
#define PIN_LDR       0
#define PIN_BUZZER   15   // D8 — boot phải LOW (còi tắt mặc định)
#define PIN_DOOR     16

#define DHTTYPE      DHT11
#define RELAY_ON     HIGH
#define RELAY_OFF    LOW

#define OLED_ADDR    0x3C
#define SCREEN_W     128
#define SCREEN_H     64
/** 2 = xoay 180° nếu màn hình bị ngược. Đổi 0/1/3 nếu cần. */
#define OLED_ROTATION 2

#define AP_SSID      "SmartHome"
#define AP_PASSWORD  ""
IPAddress apIP(192, 168, 4, 1);
const byte DNS_PORT = 53;

#define MQTT_HOST    "mqtt.duynguyen.io.vn"
#define MQTT_PORT    443
#define MQTT_PATH    "/mqtt"
#define CHIP_ID      "123"

#define DEV_TEMP     "123_temp_livingroom"
#define DEV_HUMI     "123_humi_living_room"
#define DEV_RELAY1   "123_led1"
#define DEV_RELAY2   "123_fan_livingroom"
#define DEV_DOOR     "123_door_livingroom1"
#define DEV_FACE     "123_face_livingroom"
#define DEV_GAS      "123_gas_livingroom"
#define DEV_LDR      "123_ldr_livingroom"
#define DEV_MODE     "123_mode"
#define DEV_RULES    "123_rules"
#define DEV_VITALS   "123_vitals"

#define EEPROM_SIZE  512
#define MAX_WIFI     5
#define RULES_EEPROM_ADDR 400
#define RULES_MAGIC  0xA8   // bump khi đổi struct AutoRules

struct WifiEntry { char ssid[32]; char pass[32]; };
WifiEntry wifiList[MAX_WIFI];
int wifiCount = 0;

enum ControlMode : uint8_t { MODE_MANUAL = 0, MODE_AUTO = 1 };

struct AutoRules {
  uint8_t magic;
  uint8_t mode;          // MODE_MANUAL / MODE_AUTO — set từ mobile
  float   tempFanOn;     // >= → bật quạt (mobile setup, không hard-code runtime)
  float   tempFanOff;    // <= → tắt quạt (hysteresis)
  uint8_t darkLightOn;   // 1: tối → bật đèn
  uint16_t gasThreshold; // thang gas 0..1024 (ADC)
  uint8_t gasOpenDoor;   // 1: gas vượt ngưỡng → mở cửa
  uint8_t gasFanOn;      // 1: gas → bật quạt
  uint8_t doorHoldSec;   // giữ cửa mở bao nhiêu giây rồi đóng (mobile)
  uint8_t buzzerOnGas;   // 1: bật còi khi gas alert
};

AutoRules rules;

#define TELEMETRY_MS    5000
#define SENSOR_FAST_MS   400
#define HEARTBEAT_MS   30000
#define RECONNECT_MS   10000
#define OLED_MS          400
#define DOOR_OPEN_ANGLE   90
#define DOOR_CLOSE_ANGLE   0
#define GAS_ADC_MAX     1023   // ESP8266 ADC raw 0..1023 (AO của MQ, KHÔNG dùng chân DO)
#define GAS_DIGITAL_LO   40    // dưới ngưỡng này / trên HI → nghi dây nhầm chân DO
#define GAS_DIGITAL_HI  980

DHT dht(PIN_DHT, DHTTYPE);
Servo servoDoor;
ESP8266WebServer webServer(80);
DNSServer dnsServer;
WebSocketsClient wsClient;
MqttClient512 mqttClient;
Adafruit_SH1106G display(SCREEN_W, SCREEN_H, &Wire, -1);

bool portalActive = false;
bool oledOk = false;
int doorAngle = 0;
String relay1State = "OFF";
String relay2State = "OFF";
bool isGasAlert = false;
bool isDark = false;
bool doorAutoClose = false;
unsigned long doorCloseAt = 0;
char lastFaceName[24] = "";
unsigned long faceMsgUntil = 0;
float lastTemp = NAN;
float lastHumi = NAN;
int lastGasRaw = 0;
bool gasLooksDigital = false;  // ADC chỉ 0/1023 → thường nối nhầm DO thay vì AO
uint8_t oledPage = 0;
unsigned long lastPageFlip = 0;
unsigned long showRulesUntil = 0;  // ép OLED trang RULES sau khi mobile đẩy rule

unsigned long lastTelemetry = 0;
unsigned long lastFastRead = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastReconnect = 0;
unsigned long lastOled = 0;
int wifiRetries = 0;

void saveRules();
void loadRules();
void pubMode();
void pubRules();
void pubVitals();
void applyAutoLogic();
void mqttCallback(const String& topicStr, const String& payload);

String relayRead(uint8_t pin) {
  return (digitalRead(pin) == RELAY_ON) ? "ON" : "OFF";
}

void setRelay(uint8_t pin, bool on) {
  digitalWrite(pin, on ? RELAY_ON : RELAY_OFF);
  if (pin == PIN_RELAY1) relay1State = on ? "ON" : "OFF";
  if (pin == PIN_RELAY2) relay2State = on ? "ON" : "OFF";
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

/**
 * Đọc MQ qua A0 — PHẢI nối chân AO (analog) của module, không nối DO (digital).
 * DO chỉ ra LOW/HIGH → app sẽ chỉ thấy ~0 hoặc ~1023.
 */
int readGasScaled() {
  long sum = 0;
  int gmin = 1023, gmax = 0;
  const int n = 16;
  for (int i = 0; i < n; i++) {
    delay(2);  // cho ADC ESP8266 ổn định (WiFi nhiễu A0)
    int raw = analogRead(PIN_GAS);
    if (raw < 0) raw = 0;
    if (raw > 1023) raw = 1023;
    sum += raw;
    if (raw < gmin) gmin = raw;
    if (raw > gmax) gmax = raw;
  }
  int avg = (int)(sum / n);
  // Chỉ nghi DO khi trong 1 lần đọc nhảy biên độ lớn (0↔1023).
  // Không coi avg thấp/cao ổn định là digital — sẽ chặn còi gas thật.
  gasLooksDigital = ((gmax - gmin) > 700);
  return avg;
}

/** Coi active D8: chi HIGH/LOW — khong tone() (GPIO15 + coi active de im). */
void beep(uint16_t ms = 80) {
  digitalWrite(PIN_BUZZER, HIGH);
  delay(ms);
  digitalWrite(PIN_BUZZER, LOW);
}

void buzzerGasSet(bool on) {
  digitalWrite(PIN_BUZZER, on ? HIGH : LOW);
}

void defaultRules() {
  rules.magic = RULES_MAGIC;
  rules.mode = MODE_MANUAL;
  rules.tempFanOn = 30.0f;     // default lần đầu; sau đó chỉ theo mobile/EEPROM
  rules.tempFanOff = 28.0f;
  rules.darkLightOn = 1;
  rules.gasThreshold = 512;    // giữa thang 0..1024
  rules.gasOpenDoor = 1;
  rules.gasFanOn = 1;
  rules.doorHoldSec = 5;       // mở cửa 5s rồi đóng (mobile có thể đổi)
  rules.buzzerOnGas = 1;
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
  if (rules.tempFanOff >= rules.tempFanOn) rules.tempFanOff = rules.tempFanOn - 2.0f;
  if (rules.gasThreshold > GAS_ADC_MAX) rules.gasThreshold = GAS_ADC_MAX;
  if (rules.doorHoldSec < 1 || rules.doorHoldSec > 60) rules.doorHoldSec = 5;
  if (rules.buzzerOnGas > 1) rules.buzzerOnGas = 1;
}

// ─── OLED UI đẹp hơn ─────────────────────────────────────────
void drawRoundBadge(int x, int y, int w, int h, const char* txt, bool on) {
  if (on) {
    display.fillRoundRect(x, y, w, h, 3, SH110X_WHITE);
    display.setTextColor(SH110X_BLACK);
  } else {
    display.drawRoundRect(x, y, w, h, 3, SH110X_WHITE);
    display.setTextColor(SH110X_WHITE);
  }
  display.setCursor(x + 4, y + 3);
  display.print(txt);
  display.setTextColor(SH110X_WHITE);
}

void oledInit() {
  Wire.begin(PIN_OLED_SDA, PIN_OLED_SCL);
  oledOk = display.begin(OLED_ADDR, true);
  if (!oledOk) {
    Serial.println(F("OLED SH1106 not found"));
    return;
  }
  display.setRotation(OLED_ROTATION);
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(18, 18);
  display.println(F("SmartHome"));
  display.setCursor(10, 34);
  display.println(F("Dang khoi dong..."));
  display.drawRoundRect(4, 8, 120, 48, 6, SH110X_WHITE);
  display.display();
}

void oledDrawPortal() {
  display.clearDisplay();
  display.drawRoundRect(0, 0, 128, 64, 4, SH110X_WHITE);
  display.setCursor(28, 8);
  display.println(F("WiFi PORTAL"));
  display.drawFastHLine(8, 20, 112, SH110X_WHITE);
  display.setCursor(10, 28);
  display.println(F("SSID: SmartHome"));
  display.setCursor(10, 42);
  display.println(F("192.168.4.1"));
  display.display();
}

void oledDrawHome() {
  display.clearDisplay();

  // Header
  display.fillRect(0, 0, 128, 14, SH110X_WHITE);
  display.setTextColor(SH110X_BLACK);
  display.setCursor(4, 3);
  display.print(F("SmartHome"));
  display.setCursor(78, 3);
  display.print(rules.mode == MODE_AUTO ? F("AUTO") : F("MANUAL"));
  display.setTextColor(SH110X_WHITE);

  // Temp / Humi big
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
  display.setCursor(58, 18);
  if (!isnan(lastHumi)) {
    display.setTextSize(2);
    display.printf("%.0f", lastHumi);
    display.setTextSize(1);
    display.print(F("%"));
  } else {
    display.setTextSize(2);
    display.print(F("--"));
    display.setTextSize(1);
  }

  // Status row
  drawRoundBadge(4, 40, 38, 12, relay1State == "ON" ? "DEN ON" : "DEN",
                 relay1State == "ON");
  drawRoundBadge(46, 40, 40, 12, relay2State == "ON" ? "QUAT ON" : "QUAT",
                 relay2State == "ON");
  drawRoundBadge(90, 40, 34, 12, isGasAlert ? "GAS!" : "OK", isGasAlert);

  // Footer
  display.setCursor(4, 55);
  display.printf("%s %s Door:%d",
                 WiFi.status() == WL_CONNECTED ? "W" : "-",
                 mqttClient.isConnected() ? "M" : "-",
                 doorAngle);
  display.setCursor(78, 55);
  display.print(isDark ? F("TOI") : F("SANG"));

  if (millis() < faceMsgUntil && lastFaceName[0]) {
    display.fillRect(0, 52, 128, 12, SH110X_WHITE);
    display.setTextColor(SH110X_BLACK);
    display.setCursor(4, 54);
    display.printf("Hi %s", lastFaceName);
    display.setTextColor(SH110X_WHITE);
  }

  display.display();
}

void oledDrawRules() {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 14, SH110X_WHITE);
  display.setTextColor(SH110X_BLACK);
  display.setCursor(4, 3);
  display.print(rules.mode == MODE_AUTO ? F("RULES*AUTO") : F("RULES*MAN"));
  display.setTextColor(SH110X_WHITE);
  display.setCursor(4, 18);
  display.printf("Quat %.0f/%.0fC", rules.tempFanOn, rules.tempFanOff);
  display.setCursor(4, 30);
  display.printf("Den: %s  Gas>%d", rules.darkLightOn ? "TOI" : "OFF", rules.gasThreshold);
  display.setCursor(4, 42);
  if (gasLooksDigital) {
    display.printf("ADC %d !!AO?", lastGasRaw);
  } else {
    display.printf("ADC %d/1023", lastGasRaw);
  }
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
  // loop() sẽ oledDraw() trong OLED_MS — không gọi trực tiếp (tránh forward-decl)
}

void oledDraw() {
  if (!oledOk) return;
  if (portalActive) {
    oledDrawPortal();
    return;
  }
  // Giữ trang RULES sau khi app đẩy cấu hình (đồng bộ nhìn thấy trên OLED)
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
// Dây đảo: đèn thật = RELAY2 (topic fan), quạt thật = RELAY1 (topic led1)
void applyAutoLogic() {
  if (rules.mode != MODE_AUTO) return;

  // Đèn thật theo LDR → PIN_RELAY2
  if (rules.darkLightOn) {
    bool wantLight = isDark;
    if ((relay2State == "ON") != wantLight) {
      setRelay(PIN_RELAY2, wantLight);
      pubRelay2();
    }
  }

  // Quạt thật theo nhiệt + gas → PIN_RELAY1
  bool wantFan = false;
  if (!isnan(lastTemp)) {
    if (relay1State == "ON") {
      wantFan = (lastTemp > rules.tempFanOff);
    } else {
      wantFan = (lastTemp >= rules.tempFanOn);
    }
  }
  if (rules.gasFanOn && isGasAlert) wantFan = true;

  if ((relay1State == "ON") != wantFan) {
    setRelay(PIN_RELAY1, wantFan);
    pubRelay1();
  }

  // Gas → mở cửa
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
void pubRelay1() {
  relay1State = relayRead(PIN_RELAY1);
  mqttPub(DEV_RELAY1, "{\"value\":\"" + relay1State + "\"}");
}
void pubRelay2() {
  relay2State = relayRead(PIN_RELAY2);
  mqttPub(DEV_RELAY2, "{\"value\":\"" + relay2State + "\"}");
}
void pubDoor() { mqttPub(DEV_DOOR, "{\"value\":" + String(doorAngle) + "}"); }
void pubGas() {
  mqttPub(DEV_GAS, isGasAlert ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}");
}
void pubLdr() {
  mqttPub(DEV_LDR, isDark ? "{\"value\":\"DARK\"}" : "{\"value\":\"LIGHT\"}");
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
  j += "\"tempFanOn\":" + String(rules.tempFanOn, 1) + ",";
  j += "\"tempFanOff\":" + String(rules.tempFanOff, 1) + ",";
  j += "\"darkLightOn\":" + String(rules.darkLightOn ? 1 : 0) + ",";
  j += "\"gasThreshold\":" + String(rules.gasThreshold) + ",";
  j += "\"gasOpenDoor\":" + String(rules.gasOpenDoor ? 1 : 0) + ",";
  j += "\"gasFanOn\":" + String(rules.gasFanOn ? 1 : 0) + ",";
  j += "\"doorHoldSec\":" + String(rules.doorHoldSec) + ",";
  j += "\"buzzerOnGas\":" + String(rules.buzzerOnGas ? 1 : 0) + ",";
  j += "\"gasScaleMax\":" + String(GAS_ADC_MAX);
  j += "}";
  mqttPub(DEV_RULES, j);
}
void pubVitals() {
  String j = "{";
  j += "\"temp\":" + String(isnan(lastTemp) ? 0 : lastTemp, 1) + ",";
  j += "\"humi\":" + String(isnan(lastHumi) ? 0 : lastHumi, 1) + ",";
  j += "\"gas\":" + String(lastGasRaw) + ",";
  j += "\"gasAlert\":" + String(isGasAlert ? 1 : 0) + ",";
  j += "\"gasDigital\":" + String(gasLooksDigital ? 1 : 0) + ",";
  j += "\"dark\":" + String(isDark ? 1 : 0) + ",";
  j += "\"light\":\"" + relay1State + "\",";
  j += "\"fan\":\"" + relay2State + "\",";
  j += "\"door\":" + String(doorAngle) + ",";
  j += "\"mode\":\"" + String(rules.mode == MODE_AUTO ? "AUTO" : "MANUAL") + "\"";
  j += "}";
  mqttPub(DEV_VITALS, j);
}

// Parse số ngay sau "key": — bỏ khoảng trắng, dừng ở , } ]
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
  String k = String("\"") + key + "\"";
  return s.indexOf(k) >= 0;
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
  // AUTO: áp dụng rule ngay; MANUAL: dừng auto, chờ lệnh tay từ app
  if (rules.mode == MODE_AUTO) applyAutoLogic();
  forceOledRulesPage();
  beep(40);
  Serial.printf("Mode => %s\n", rules.mode == MODE_AUTO ? "AUTO" : "MANUAL");
}

void handleRulesPayload(String cmd) {
  cmd.trim();
  Serial.printf("Rules RX (%u): %s\n", (unsigned)cmd.length(), cmd.c_str());
  if (cmd.length() < 2) return;

  // Chỉ coi là lệnh mode thuần nếu KHÔNG có key rule
  if (!jsonHasKey(cmd, "tempFanOn") && !jsonHasKey(cmd, "gasThreshold") &&
      !jsonHasKey(cmd, "doorHoldSec") &&
      (cmd.indexOf("AUTO") >= 0 || cmd.indexOf("MANUAL") >= 0) &&
      !cmd.startsWith("{")) {
    handleModePayload(cmd);
    return;
  }

  if (cmd.startsWith("{") || jsonHasKey(cmd, "tempFanOn") || jsonHasKey(cmd, "gasThreshold")) {
    if (jsonHasKey(cmd, "mode")) {
      String m = jsonValueToken(cmd, "mode");
      m.replace("\"", "");
      m.toUpperCase();
      if (m.indexOf("AUTO") >= 0) rules.mode = MODE_AUTO;
      else if (m.indexOf("MANUAL") >= 0) rules.mode = MODE_MANUAL;
    }
    if (jsonHasKey(cmd, "tempFanOn")) rules.tempFanOn = jsonFloat(cmd, "tempFanOn", rules.tempFanOn);
    if (jsonHasKey(cmd, "tempFanOff")) rules.tempFanOff = jsonFloat(cmd, "tempFanOff", rules.tempFanOff);
    if (jsonHasKey(cmd, "darkLightOn")) rules.darkLightOn = jsonInt(cmd, "darkLightOn", rules.darkLightOn) ? 1 : 0;
    if (jsonHasKey(cmd, "gasThreshold")) {
      int g = jsonInt(cmd, "gasThreshold", rules.gasThreshold);
      if (g < 0) g = 0;
      if (g > GAS_ADC_MAX) g = GAS_ADC_MAX;
      rules.gasThreshold = (uint16_t)g;
    }
    if (jsonHasKey(cmd, "gasOpenDoor")) rules.gasOpenDoor = jsonInt(cmd, "gasOpenDoor", rules.gasOpenDoor) ? 1 : 0;
    if (jsonHasKey(cmd, "gasFanOn")) rules.gasFanOn = jsonInt(cmd, "gasFanOn", rules.gasFanOn) ? 1 : 0;
    if (jsonHasKey(cmd, "doorHoldSec")) {
      int s = jsonInt(cmd, "doorHoldSec", rules.doorHoldSec);
      if (s < 1) s = 1;
      if (s > 60) s = 60;
      rules.doorHoldSec = (uint8_t)s;
    }
    if (jsonHasKey(cmd, "buzzerOnGas")) rules.buzzerOnGas = jsonInt(cmd, "buzzerOnGas", rules.buzzerOnGas) ? 1 : 0;
  } else {
    Serial.println(F("Rules: payload khong nhan dien JSON"));
    return;
  }

  if (rules.tempFanOff >= rules.tempFanOn) rules.tempFanOff = rules.tempFanOn - 2.0f;
  saveRules();
  pubRules();
  pubMode();
  pubVitals();
  mqttPub(DEV_RULES, String("{\"ack\":1,\"tempFanOn\":") + String(rules.tempFanOn, 1) +
                          ",\"tempFanOff\":" + String(rules.tempFanOff, 1) + "}");
  if (rules.mode == MODE_AUTO) applyAutoLogic();
  forceOledRulesPage(12000);
  // Không delay dài — tránh block MQTT
  digitalWrite(PIN_BUZZER, HIGH);
  delay(30);
  digitalWrite(PIN_BUZZER, LOW);
  Serial.printf("Rules OK ton=%.1f toff=%.1f gas=%u hold=%us mode=%s\n",
                rules.tempFanOn, rules.tempFanOff, rules.gasThreshold,
                (unsigned)rules.doorHoldSec,
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
  } else if (topic.indexOf(DEV_RELAY1) >= 0) {
    if (rules.mode == MODE_MANUAL) {
      setRelay(PIN_RELAY1, cmd == "ON");
      pubRelay1();
      pubVitals();
    } else {
      Serial.println(F("Bo qua relay: dang AUTO"));
    }
  } else if (topic.indexOf(DEV_RELAY2) >= 0) {
    if (rules.mode == MODE_MANUAL) {
      setRelay(PIN_RELAY2, cmd == "ON");
      pubRelay2();
      pubVitals();
    } else {
      Serial.println(F("Bo qua relay: dang AUTO"));
    }
  }
}

void reconnectMQTT() {
  if (mqttClient.isConnected()) return;
  Serial.printf("MQTT WSS ... ");
  String clientId = "ESP8266-" + String(ESP.getChipId(), HEX);
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

  sub(String("cmnd/") + DEV_RELAY1 + "/POWER");
  sub(String("cmnd/") + DEV_RELAY2 + "/POWER");
  sub(String("cmnd/") + DEV_DOOR + "/POWER");
  sub(String("cmnd/") + DEV_FACE + "/POWER");
  sub(String("cmnd/") + DEV_MODE + "/POWER");
  sub(String("cmnd/") + DEV_RULES + "/SET");
  sub(String("cmnd/") + DEV_RULES + "/POWER");
  sub(String("cmnd/") + DEV_RULES + "/GET");
  // Đồng bộ OLED/app ngay khi online
  forceOledRulesPage(10000);
  pubMode();
  pubRules();
  pubVitals();

  pubRelay1(); wsClient.loop(); delay(20);
  pubRelay2();
  pubDoor();
  pubGas();
  pubLdr();
  pubMode();
  pubRules();
  pubVitals();
}

// ─── Portal ──────────────────────────────────────────────────
const char PORTAL_HTML[] PROGMEM = R"rawhtml(
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartHome</title>
<style>body{font-family:sans-serif;background:#0a0e1a;color:#e2e8f0;display:flex;justify-content:center;padding:20px}
.c{max-width:400px;width:100%}input{width:100%;padding:10px;margin-bottom:10px;border-radius:5px;border:none;box-sizing:border-box}
button{padding:10px;width:100%;background:#0ea5e9;color:#fff;border:none;border-radius:5px;font-weight:bold}</style>
</head><body><div class="c"><h2>SmartHome WiFi</h2>
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
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  dnsServer.start(DNS_PORT, "*", apIP);
  webServer.on("/", HTTP_GET, handleRoot);
  webServer.on("/scan", HTTP_GET, handleScan);
  webServer.on("/connect", HTTP_POST, handleConnect);
  webServer.onNotFound(handleNotFound);
  webServer.begin();
  oledDraw();
}

#define DOUBLE_RESET_MAGIC 0x12345678
uint32_t rtcData = 0;
bool isDoubleReset = false;

void checkDoubleReset() {
  ESP.rtcUserMemoryRead(0, (uint32_t*)&rtcData, sizeof(rtcData));
  if (rtcData == DOUBLE_RESET_MAGIC) {
    isDoubleReset = true;
    rtcData = 0;
    ESP.rtcUserMemoryWrite(0, (uint32_t*)&rtcData, sizeof(rtcData));
    wifiCount = 0;
    saveWifiList();
  } else {
    isDoubleReset = false;
    rtcData = DOUBLE_RESET_MAGIC;
    ESP.rtcUserMemoryWrite(0, (uint32_t*)&rtcData, sizeof(rtcData));
  }
}
void clearDoubleResetFlag() {
  if (rtcData == DOUBLE_RESET_MAGIC) {
    rtcData = 0;
    ESP.rtcUserMemoryWrite(0, (uint32_t*)&rtcData, sizeof(rtcData));
  }
}

// ESP8266: dùng chân TOUT/A0 đọc điện áp ngoài (không đo VCC nội)
ADC_MODE(ADC_TOUT);

void setup() {
  // GPIO15 (D8) phải LOW sớm để boot ổn + còi tắt
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  Serial.begin(115200);
  delay(200);
  Serial.println(F("\n=== SmartHome AUTO/MANUAL ==="));
  Serial.println(F("Gas: noi MQ chan AO -> NodeMCU A0 (khong dung DO)"));
  Serial.println(F("Buzzer: D8 (GPIO15), mac dinh LOW"));

  pinMode(PIN_RELAY1, OUTPUT); setRelay(PIN_RELAY1, false);
  pinMode(PIN_RELAY2, OUTPUT); setRelay(PIN_RELAY2, false);
  digitalWrite(PIN_BUZZER, LOW);
  pinMode(PIN_LDR, INPUT_PULLUP);

  dht.begin();
  loadRules();
  oledInit();

  // Test còi D8 lúc boot (2 tiếng ngắn) — nếu không nghe → kiểm tra dây VCC/GND/I/O
  beep(120);
  delay(80);
  beep(120);
  digitalWrite(PIN_BUZZER, LOW);

  servoDoor.attach(PIN_DOOR);
  delay(40);
  closeDoorNow();

  wsClient.beginSSL(MQTT_HOST, MQTT_PORT, MQTT_PATH);
  wsClient.setExtraHeaders("Sec-WebSocket-Protocol: mqtt");
  mqttClient.begin(wsClient);

  loadWifiList();
  checkDoubleReset();

  if (isDoubleReset) startPortal();
  else if (!(wifiCount > 0 && connectBestWifi())) startPortal();
  else oledDraw();
}

void loop() {
  if (millis() > 3000 && rtcData == DOUBLE_RESET_MAGIC) clearDoubleResetFlag();

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
    lastGasRaw = readGasScaled();   // 0..1023
    // ADC >= ngưỡng → alert + còi (kể cả 1023). Không chặn bởi cờ digital UI.
    bool gasAlert = (lastGasRaw >= (int)rules.gasThreshold);
    if (gasAlert != isGasAlert) {
      isGasAlert = gasAlert;
      pubGas();
      pubVitals();
      Serial.printf("Gas ALERT=%d adc=%d thr=%d pinD8=%d bzzRule=%d\n",
                    isGasAlert, lastGasRaw, rules.gasThreshold,
                    PIN_BUZZER, rules.buzzerOnGas);
    }
    static unsigned long lastGasLog = 0;
    if (millis() - lastGasLog > 2000) {
      lastGasLog = millis();
      Serial.printf("Gas ADC=%d thr=%d alert=%d bzz=%d D8=%d\n",
                    lastGasRaw, rules.gasThreshold, isGasAlert,
                    rules.buzzerOnGas, digitalRead(PIN_BUZZER));
    }
    bool dark = (digitalRead(PIN_LDR) == HIGH);
    if (dark != isDark) {
      isDark = dark;
      pubLdr();
    }
    // Còi D8 liên tục khi gas
    buzzerGasSet(isGasAlert && rules.buzzerOnGas);
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
      pubVitals();
      applyAutoLogic();
    }
  }

  if (now - lastOled >= OLED_MS) {
    lastOled = now;
    oledDraw();
  }
}
