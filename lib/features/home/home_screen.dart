import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/home_atmosphere.dart';
import '../auth/login_screen.dart';
import '../face/face_register_screen.dart';
import '../face/face_unlock_screen.dart';
import 'smart_control_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _chipCtrl;
  bool _savingChip = false;

  @override
  void initState() {
    super.initState();
    _chipCtrl = TextEditingController(text: AppConfig.chipId);
  }

  @override
  void dispose() {
    _chipCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChipId() async {
    final id = _chipCtrl.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập Chip ID của nhà (ví dụ 123)')),
      );
      return;
    }
    setState(() => _savingChip = true);
    try {
      final ok = await context.read<AuthProvider>().saveChipId(id);
      _chipCtrl.text = AppConfig.chipId;
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã lưu Chip ID ${AppConfig.chipId} (MongoDB + máy này)',
            ),
          ),
        );
      } else {
        final msg = context.read<AuthProvider>().errorMessage ?? 'Lỗi lưu Chip ID';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được Chip ID: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingChip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
            ? 'Chào buổi chiều'
            : 'Chào buổi tối';

    return Scaffold(
      body: HomeAtmosphere(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Face AIoT',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.sage,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$greet,\n${user?.name ?? 'bạn'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(height: 1.15),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đăng xuất',
                        onPressed: () async {
                          await context.read<AuthProvider>().logout();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (_) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(
                    'Chọn nhà bằng Chip ID rồi điều khiển hoặc mở cửa.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: _ChipIdCard(
                    controller: _chipCtrl,
                    saving: _savingChip,
                    activeId: AppConfig.chipId,
                    onSave: _saveChipId,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverList.list(
                  children: [
                    _HubAction(
                      icon: Icons.home_rounded,
                      title: 'Điều khiển nhà',
                      subtitle: 'Đèn · quạt · cửa · chế độ tự động',
                      accent: AppColors.sage,
                      delay: 0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SmartControlScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HubAction(
                      icon: Icons.door_front_door_outlined,
                      title: 'Mở cửa bằng mặt',
                      subtitle: 'Nhìn camera — cửa mở khi nhận ra bạn',
                      accent: AppColors.amber,
                      delay: 60,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FaceUnlockScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HubAction(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Thêm thành viên',
                      subtitle: 'Đăng ký khuôn mặt cho người trong nhà',
                      accent: AppColors.inkSoft,
                      delay: 120,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FaceRegisterScreen(),
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

class _ChipIdCard extends StatelessWidget {
  const _ChipIdCard({
    required this.controller,
    required this.saving,
    required this.activeId,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final String activeId;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_rounded, color: AppColors.sage, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chip ID nhà',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  'Đang dùng: $activeId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sageDeep,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Mỗi ESP8266 có một Chip ID — nhập đúng ID để nối riêng nhà đó.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSave(),
                    decoration: const InputDecoration(
                      hintText: 'Ví dụ: 123',
                      labelText: 'Chip ID',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HubAction extends StatefulWidget {
  const _HubAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    required this.delay,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final int delay;

  @override
  State<_HubAction> createState() => _HubActionState();
}

class _HubActionState extends State<_HubAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(widget.icon, color: widget.accent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.ink.withValues(alpha: 0.35),
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
