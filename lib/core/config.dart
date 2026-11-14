import 'package:shared_preferences/shared_preferences.dart';

import 'push/fcm_service.dart';

class AppConfig {
  /// Docker API (Cloudflare) — auth login / register / forgot password
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://duynguyen.io.vn',
  );

  /// Gas FCM bridge (MQTT → push). Mặc định cùng host API; đổi nếu bridge riêng.
  static const String pushApiBase = String.fromEnvironment(
    'PUSH_API_BASE',
    defaultValue: 'https://duynguyen.io.vn',
  );

  static const String mqttWss = 'wss://mqtt.duynguyen.io.vn/mqtt';

  static const String _prefsChipId = 'chip_id';

  /// Chip ESP8266 SmartHome (khớp firmware) — mặc định compile-time, đổi runtime theo nhà
  static const String defaultChipId = String.fromEnvironment(
    'CHIP_ID',
    defaultValue: '123',
  );

  static String _chipId = defaultChipId;

  static String get chipId => _chipId;

  static Future<void> loadChipId() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_prefsChipId)?.trim();
    _chipId = (saved != null && saved.isNotEmpty) ? saved : defaultChipId;
  }

  /// Lưu Chip ID để kết nối đúng nhà (topic MQTT cmnd/{id}_… / tele/{id}_…)
  static Future<void> setChipId(String id) async {
    final cleaned = id.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Chip ID không được để trống');
    }
    _chipId = cleaned;
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsChipId, cleaned);
    // Gắn lại FCM token với nhà mới (để bridge đẩy đúng thiết bị)
    await FcmService.instance.syncRegistration();
  }

  static String get doorTopic => 'cmnd/${chipId}_door_livingroom1/POWER';
  static String get faceTopic => 'cmnd/${chipId}_face_livingroom/POWER';
  static String get cmndMode => 'cmnd/${chipId}_mode/POWER';
  static String get cmndRules => 'cmnd/${chipId}_rules/SET';
  static String get cmndRulesPower => 'cmnd/${chipId}_rules/POWER';
  static String get cmndRulesGet => 'cmnd/${chipId}_rules/GET';
  static String get cmndRelay1 => 'cmnd/${chipId}_led1/POWER';
  static String get cmndRelay2 => 'cmnd/${chipId}_fan_livingroom/POWER';

  static String get teleVitals => 'tele/${chipId}_vitals/status';
  static String get teleMode => 'tele/${chipId}_mode/status';
  static String get teleRules => 'tele/${chipId}_rules/status';
  static String get teleRelay1 => 'tele/${chipId}_led1/status';
  static String get teleRelay2 => 'tele/${chipId}_fan_livingroom/status';
  static String get teleDoor => 'tele/${chipId}_door_livingroom1/status';

  /// Cosine threshold (stem_chamcong_face default 0.45)
  static const double matchThreshold = 0.45;

  /// Cooldown giữa 2 lần mở cửa (ms)
  static const int doorCooldownMs = 5000;
}
