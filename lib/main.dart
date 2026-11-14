import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'core/push/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // FCM chỉ Android. iOS: không init Firebase từ Dart (tránh treo/crash).
  try {
    if (DefaultFirebaseOptions.isConfigured &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FcmService.instance.init();
    }
  } catch (e, st) {
    debugPrint('FCM init skipped: $e\n$st');
  }

  runApp(const FaceAlotApp());
}

class FaceAlotApp extends StatelessWidget {
  const FaceAlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Face AIoT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SplashScreen(),
      ),
    );
  }
}
