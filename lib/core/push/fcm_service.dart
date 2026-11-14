import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../alerts/gas_alert.dart';
import '../api/push_api.dart';
import '../config.dart';

/// Top-level: bắt buộc để nhận FCM khi app bị kill (Android isolate).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // Notification message (có title/body): OS tự hiện khi app killed / background.
  // Data-only: hiện local notification dự phòng.
  if (message.notification != null) return;

  final data = message.data;
  final title = '${data['title'] ?? '⚠ Cảnh báo gas'}';
  final body =
      '${data['body'] ?? 'Phát hiện khí gas vượt ngưỡng. Kiểm tra ngay!'}';
  await GasAlert.instance.showPush(title: title, body: body);
}

/// FCM **Android-only** — báo gas khi app đã tắt.
/// iOS: không có Apple Developer → bỏ qua; vẫn dùng MQTT + GasAlert khi app mở.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _api = PushApi();
  bool _ready = false;
  String? _fid;
  StreamSubscription<String>? _regSub;
  StreamSubscription<RemoteMessage>? _fgSub;

  bool get isReady => _ready;
  String? get token => _fid;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Gọi từ [main] trước [runApp] (sau WidgetsFlutterBinding).
  Future<void> init() async {
    if (_ready) return;
    if (!isSupportedPlatform) {
      if (kDebugMode) {
        debugPrint(
          'FCM: chỉ bật trên Android (iOS cần Apple Developer + APNs).',
        );
      }
      return;
    }
    if (!DefaultFirebaseOptions.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          'FCM: chưa cấu hình Firebase. Xem docs/FCM_SETUP.md '
          '(google-services.json + --dart-define=FIREBASE_CONFIGURED=true)',
        );
      }
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FCM Firebase.initializeApp: $e');
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    }

    await GasAlert.instance.requestPermission();

    _fgSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (kDebugMode) debugPrint('FCM opened: ${m.messageId}');
    });

    _regSub = _messaging.onRegistered.listen((fid) async {
      _fid = fid;
      if (kDebugMode) debugPrint('FCM FID: $fid');
      await syncRegistration();
    }, onError: (e) {
      if (kDebugMode) debugPrint('FCM onRegistered error: $e');
    });

    try {
      await _messaging.register();
    } catch (e) {
      if (kDebugMode) debugPrint('FCM register: $e');
    }

    _ready = true;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final gas = int.tryParse('${data['gas'] ?? ''}') ?? 0;
    final alert = data['gasAlert'] == '1' ||
        data['type'] == 'gas_alert' ||
        message.notification != null;
    if (alert) {
      await GasAlert.instance.handleVitals(gasAlert: true, gas: gas);
    }
  }

  /// Gọi sau login / đổi chipId / khi FID đổi.
  Future<void> syncRegistration({String? authToken}) async {
    if (!isSupportedPlatform) return;
    final id = _fid;
    if (id == null || id.isEmpty) return;
    try {
      await _api.registerDevice(
        fcmToken: id,
        chipId: AppConfig.chipId,
        authToken: authToken,
      );
      if (kDebugMode) {
        debugPrint('FCM registered chip=${AppConfig.chipId}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM register failed: $e');
    }
  }

  Future<void> unregister({String? authToken}) async {
    if (!isSupportedPlatform) return;
    final id = _fid;
    if (id != null) {
      await _api.unregisterDevice(fcmToken: id, authToken: authToken);
    }
    try {
      await _messaging.unregister();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _regSub?.cancel();
    await _fgSub?.cancel();
  }
}
