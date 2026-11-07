import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/home_atmosphere.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _verified = false;

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final ok =
        await context.read<AuthProvider>().forgotPassword(_phone.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _verified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SĐT hợp lệ — nhập mật khẩu mới')),
      );
    } else {
      final msg =
          context.read<AuthProvider>().errorMessage ?? 'Không tìm thấy SĐT';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _reset() async {
    final ok = await context
        .read<AuthProvider>()
        .resetPassword(_phone.text.trim(), _pass.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đổi mật khẩu — đăng nhập lại')),
      );
      Navigator.pop(context);
    } else {
      final msg =
          context.read<AuthProvider>().errorMessage ?? 'Lỗi đổi mật khẩu';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeAtmosphere(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Text(
                'Quên mật khẩu',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Nhập số điện thoại đã đăng ký để đặt lại mật khẩu.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              const SizedBox(height: 24),
              SoftPanel(
                child: Column(
                  children: [
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: _verified
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _pass,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Mật khẩu mới',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _verified ? _reset : _check,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _verified ? 'Đặt lại mật khẩu' : 'Tiếp tục',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
