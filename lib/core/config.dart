class AppConfig {
  /// Docker API (Cloudflare) — auth login / register / forgot password
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://duynguyen.io.vn',
  );

  static const String mqttWss = 'wss://mqtt.duynguyen.io.vn/mqtt';

  /// Chip ESP8266 SmartHome (khớp firmware)
  static const String chipId = String.fromEnvironment(
    'CHIP_ID',
    defaultValue: '123',
  );

  static String get doorTopic => 'cmnd/${chipId}_door_livingroom1/POWER';
  static String get faceTopic => 'cmnd/${chipId}_face_livingroom/POWER';

  /// Cosine threshold (stem_chamcong_face default 0.45)
  static const double matchThreshold = 0.45;

  /// Cooldown giữa 2 lần mở cửa (ms)
  static const int doorCooldownMs = 5000;
}
