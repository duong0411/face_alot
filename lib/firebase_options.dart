// Generated from android/app/google-services.json (project face-e7576).
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Options Firebase — **Android** (FCM cảnh báo gas khi tắt app).
class DefaultFirebaseOptions {
  /// Bật FCM. Tắt tạm: `--dart-define=FIREBASE_CONFIGURED=false`
  static const bool isConfigured = bool.fromEnvironment(
    'FIREBASE_CONFIGURED',
    defaultValue: true,
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web chưa cấu hình Firebase cho Face AIoT.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FCM chỉ hỗ trợ Android. iOS báo gas khi app đang mở (MQTT).',
        );
      default:
        throw UnsupportedError(
          'Firebase chưa hỗ trợ platform ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBn4DvAfRGHO8ngudteeLHNGgD3ECxjRkA',
    appId: '1:125746205167:android:cbf38650e48de4d80a661a',
    messagingSenderId: '125746205167',
    projectId: 'face-e7576',
    storageBucket: 'face-e7576.firebasestorage.app',
  );
}
