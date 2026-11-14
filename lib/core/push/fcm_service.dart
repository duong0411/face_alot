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

  if (message.notification != null) return;

  final data = message.data;
  final title = '${data['title'] ?? '⚠ Cảnh báo gas'}';
  final body =
      '${data['body'] ?? 'Phát hiện khí gas vượt ngưỡng. Kiểm tra ngay!'}';
  await GasAlert.instance.showPush(title: title, body: body);
}

/// FCM **Android-only**. Trên iOS tuyệt đối không đụng FirebaseMessaging
/// (tránh treo splash / crash IPA unsigned).
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _api = PushApi();
  FirebaseMessaging? _messaging;
  bool _ready = false;
  String? _fid;
  StreamSubscription<String>? _regSub;
  StreamSubscription<RemoteMessage>? _fgSub;

  bool get isReady => _ready;
  String? get token => _fid;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  FirebaseMessaging get _msg {
    _messaging ??= FirebaseMessaging.instance;
    return _messaging!;
  }

  Future<void> init() async {
    if (_ready) return;
    if (!isSupportedPlatform) return;
    if (!DefaultFirebaseOptions.isConfigured) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FCM Firebase.initializeApp: $e');
      return;
    }

    final settings = await _msg.requestPermission(
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

    _regSub = _msg.onRegistered.listen((fid) async {
      _fid = fid;
      if (kDebugMode) debugPrint('FCM FID: $fid');
      await syncRegistration();
    }, onError: (e) {
      if (kDebugMode) debugPrint('FCM onRegistered error: $e');
    });

    try {
      await _msg.register();
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

  Future<void> syncRegistration({String? authToken}) async {
    if (!isSupportedPlatform || !_ready) return;
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
      await _msg.unregister();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _regSub?.cancel();
    await _fgSub?.cancel();
  }
}
