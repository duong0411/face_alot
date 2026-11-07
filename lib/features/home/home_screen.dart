import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../face/face_register_screen.dart';
import '../face/face_unlock_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Xin chào, ${user?.name ?? ''}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(user?.email ?? '', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          _Card(
            icon: Icons.face_retouching_natural,
            title: 'Đăng ký khuôn mặt',
            subtitle: 'Lưu embedding để mở cửa (NCNN)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaceRegisterScreen()),
            ),
          ),
          _Card(
            icon: Icons.door_front_door,
            title: 'Mở cửa bằng mặt',
            subtitle: 'Camera realtime · detect + recognize',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaceUnlockScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
