import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

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
      final msg = context.read<AuthProvider>().errorMessage ?? 'Không tìm thấy SĐT';
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
      final msg = context.read<AuthProvider>().errorMessage ?? 'Lỗi đổi mật khẩu';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại đã đăng ký',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_verified)
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _verified ? _reset : _check,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_verified ? 'Đặt lại mật khẩu' : 'Kiểm tra SĐT'),
            ),
          ),
        ],
      ),
    );
  }
}
