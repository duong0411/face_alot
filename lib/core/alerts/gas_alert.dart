import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config.dart';

/// Cảnh báo gas trên điện thoại (thông báo hệ thống + rung + âm báo).
class GasAlert {
  GasAlert._();
  static final GasAlert instance = GasAlert._();

  static const _channelId = 'gas_alert';
  static const _channelName = 'Cảnh báo gas';
  static const _notifId = 91001;
  static const _cooldown = Duration(seconds: 45);

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _episodeActive = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Init nhẹ — **không** xin quyền trên iOS (tránh treo splash / dialog).
  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS: tắt request* khi initialize — xin sau bằng requestPermission().
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Báo khi phát hiện khí gas vượt ngưỡng',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    _ready = true;
  }

  Future<void> requestPermission() async {
    try {
      await init();
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      if (kDebugMode) debugPrint('GasAlert permission: $e');
    }
  }

  /// Gọi mỗi lần nhận vitals. Chỉ báo một lần mỗi đợt gas (rising edge + cooldown).
  Future<void> handleVitals({
    required bool gasAlert,
    required int gas,
  }) async {
    if (!gasAlert) {
      _episodeActive = false;
      return;
    }
    final now = DateTime.now();
    if (_episodeActive && now.difference(_lastNotify) < _cooldown) return;
    _episodeActive = true;
    _lastNotify = now;
    await _fire(gas: gas);
  }

  Future<void> _fire({required int gas}) async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    final chip = AppConfig.chipId;
    await showPush(
      title: '⚠ Cảnh báo gas — nhà $chip',
      body: 'Phát hiện khí gas vượt ngưỡng (mức $gas/1023). Kiểm tra ngay!',
    );
  }

  /// Hiện thông báo từ MQTT / FCM data-only.
  Future<void> showPush({
    required String title,
    required String body,
  }) async {
    try {
      await init();
      await _plugin.show(
        id: _notifId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Báo khi phát hiện khí gas vượt ngưỡng',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            ticker: 'Cảnh báo gas',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: 'gas_alert',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GasAlert notify failed: $e');
      }
    }
  }
}
