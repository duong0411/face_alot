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
  static String get cmndMode => 'cmnd/${chipId}_mode/POWER';
  static String get cmndRules => 'cmnd/${chipId}_rules/SET';
  static String get cmndRelay1 => 'cmnd/${chipId}_led1/POWER';
  static String get cmndRelay2 => 'cmnd/${chipId}_fan_livingroom/POWER';

  static String get teleVitals => 'tele/${chipId}_vitals/status';
  static String get teleMode => 'tele/${chipId}_mode/status';
  static String get teleRules => 'tele/${chipId}_rules/status';
  static String get teleRelay1 => 'tele/${chipId}_led1/status';
  static String get teleRelay2 => 'tele/${chipId}_fan_livingroom/status';

  /// Cosine threshold (stem_chamcong_face default 0.45)
  static const double matchThreshold = 0.45;

  /// Cooldown giữa 2 lần mở cửa (ms)
  static const int doorCooldownMs = 5000;
}
