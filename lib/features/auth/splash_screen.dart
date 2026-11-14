import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/alerts/gas_alert.dart';
import '../../core/config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/push/fcm_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/home_atmosphere.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
    _boot();
  }

  Future<T?> _guarded<T>(
    String label,
    Future<T> Function() run, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      return await run().timeout(timeout);
    } catch (e) {
      if (kDebugMode) debugPrint('Splash $label: $e');
      return null;
    }
  }

  Future<void> _boot() async {
    // Không để bất kỳ bước nào treo splash trên iOS.
    await Future.wait([
      _guarded('auth', () => context.read<AuthProvider>().checkAuthStatus()),
      _guarded('chip', () => AppConfig.loadChipId()),
      _guarded('notif', () => GasAlert.instance.init()),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);

    // FCM chỉ Android — không chạm FirebaseMessaging trên iOS.
    if (FcmService.isSupportedPlatform) {
      await _guarded(
        'fcm',
        () => FcmService.instance.syncRegistration(),
        timeout: const Duration(seconds: 3),
      );
    }

    // Xin quyền thông báo sau khi đã vào UI (không block splash).
    // ignore: unawaited_futures
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      GasAlert.instance.requestPermission();
    });

    _goNext();
  }

  void _goNext() {
    if (!mounted || _navigated) return;
    _navigated = true;
    final auth = context.read<AuthProvider>();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => auth.isAuthenticated
            ? const HomeScreen()
            : const LoginScreen(),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeAtmosphere(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Face AIoT',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 44,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nhà của bạn, thông minh hơn mỗi ngày',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
