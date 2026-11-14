import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/alerts/gas_alert.dart';
import '../../core/config.dart';
import '../../core/mqtt/home_mqtt.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/home_atmosphere.dart';

class SmartControlScreen extends StatefulWidget {
  const SmartControlScreen({super.key});

  @override
  State<SmartControlScreen> createState() => _SmartControlScreenState();
}

class _SmartControlScreenState extends State<SmartControlScreen> {
  final _mqtt = HomeMqtt();
  late final TextEditingController _chipCtrl;
  String _status = 'Đang kết nối nhà...';
  bool _online = false;
  bool _connecting = false;
  bool _gasDialogShown = false;

  late double _tempOn;
  late double _tempOff;
  late bool _darkLight;
  late double _gasThr;
  late bool _gasDoor;
  late bool _gasFan;
  late double _doorHoldSec;
  late bool _buzzerOnGas;

  @override
  void initState() {
    super.initState();
    _chipCtrl = TextEditingController(text: AppConfig.chipId);
    _tempOn = 30;
    _tempOff = 28;
    _darkLight = true;
    _gasThr = 512;
    _gasDoor = true;
    _gasFan = true;
    _doorHoldSec = 5;
    _buzzerOnGas = true;
    GasAlert.instance.requestPermission();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _connecting = true;
      _status = 'Đang kết nối nhà ${AppConfig.chipId}...';
      _online = false;
    });
    try {
      await _mqtt.connect();
      _mqtt.addListener(_syncFromMqtt);
      if (!mounted) return;
      setState(() {
        _status = 'Đã kết nối · ${AppConfig.chipId}';
        _online = true;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Mất kết nối — kiểm tra mạng / Chip ID';
        _online = false;
        _connecting = false;
      });
    }
  }

  Future<void> _connectHouse() async {
    final id = _chipCtrl.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập Chip ID trước khi kết nối')),
      );
      return;
    }
    setState(() {
      _connecting = true;
      _status = 'Đang kết nối nhà $id...';
      _online = false;
    });
    final auth = context.read<AuthProvider>();
    try {
      final ok = await auth.saveChipId(id);
      if (!ok) {
        throw Exception(auth.errorMessage ?? 'Không lưu Chip ID');
      }
      _mqtt.removeListener(_syncFromMqtt);
      await _mqtt.reconnect();
      _mqtt.addListener(_syncFromMqtt);
      if (!mounted) return;
      setState(() {
        _status = 'Đã kết nối · ${AppConfig.chipId}';
        _online = true;
        _connecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nối nhà Chip ID ${AppConfig.chipId}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Kết nối thất bại — kiểm tra mạng / Chip ID';
        _online = false;
        _connecting = false;
      });
    }
  }

  void _syncFromMqtt() {
    final v = _mqtt.vitals;
    setState(() {
      _tempOn = v.tempFanOn;
      _tempOff = v.tempFanOff;
      _darkLight = v.darkLightOn;
      _gasThr = v.gasThreshold.toDouble();
      _gasDoor = v.gasOpenDoor;
      _gasFan = v.gasFanOn;
      _doorHoldSec = v.doorHoldSec.toDouble();
      _buzzerOnGas = v.buzzerOnGas;
    });
    _maybeShowGasDialog(v);
  }

  void _maybeShowGasDialog(HomeVitals v) {
    if (!v.gasAlert) {
      _gasDialogShown = false;
      return;
    }
    if (_gasDialogShown || !mounted) return;
    _gasDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppColors.danger, size: 40),
        title: const Text('Cảnh báo gas'),
        content: Text(
          'Phát hiện khí gas vượt ngưỡng (mức ${v.gas}/1023) tại nhà '
          '${AppConfig.chipId}. Kiểm tra ngay nguồn gas / thông gió.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chipCtrl.dispose();
    _mqtt.removeListener(_syncFromMqtt);
    _mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mqtt,
      builder: (context, _) {
        final v = _mqtt.vitals;
        final isAuto = v.mode == 'AUTO';
        return Scaffold(
          body: HomeAtmosphere(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            'Điều khiển nhà',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusDot(ok: _online, label: _status),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _HouseChipConnect(
                          controller: _chipCtrl,
                          connecting: _connecting,
                          onConnect: _connectHouse,
                        ),
                        const SizedBox(height: 16),
                        if (v.gasAlert) ...[
                          _GasAlertBanner(gas: v.gas),
                          const SizedBox(height: 12),
                        ],
                        _VitalsStrip(v: v),
                        const SizedBox(height: 20),
                        Text(
                          'Chế độ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _ModeSwitch(
                          isAuto: isAuto,
                          onChanged: (auto) async {
                            await _mqtt.setMode(auto);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  auto
                                      ? 'AUTO: ESP theo rule cảm biến (OLED trang RULES)'
                                      : 'Thủ công: điều khiển đèn / quạt / cửa trên app',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isAuto
                              ? 'Đang AUTO — đèn/quạt theo cảm biến + rule dưới đây'
                              : 'Đang Thủ công — bật/tắt thiết bị bên dưới',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkSoft,
                              ),
                        ),
                        const SizedBox(height: 16),
                        if (!isAuto) ...[
                          _ManualDevices(
                            key: const ValueKey('manual'),
                            lightOn: v.lightOn,
                            fanOn: v.fanOn,
                            doorDeg: v.door,
                            onLight: _mqtt.setLight,
                            onFan: _mqtt.setFan,
                            onOpenDoor: _mqtt.openDoor,
                            onCloseDoor: _mqtt.closeDoor,
                          ),
                          const SizedBox(height: 22),
                        ],
                        // Rule luôn chỉnh được (OLED đồng bộ khi Lưu); chỉ có hiệu lực khi AUTO
                        _AutoRules(
                          key: const ValueKey('rules'),
                          tempOn: _tempOn,
                          tempOff: _tempOff,
                          darkLight: _darkLight,
                          gasThr: _gasThr,
                          gasDoor: _gasDoor,
                          gasFan: _gasFan,
                          doorHoldSec: _doorHoldSec,
                          buzzerOnGas: _buzzerOnGas,
                          liveGas: v.gas,
                          onTempOn: (x) => setState(() {
                            _tempOn = x;
                            if (_tempOff >= _tempOn) {
                              _tempOff = _tempOn - 1;
                            }
                          }),
                          onTempOff: (x) => setState(() => _tempOff = x),
                          onDarkLight: (x) => setState(() => _darkLight = x),
                          onGasThr: (x) => setState(() => _gasThr = x),
                          onGasDoor: (x) => setState(() => _gasDoor = x),
                          onGasFan: (x) => setState(() => _gasFan = x),
                          onDoorHold: (x) => setState(() => _doorHoldSec = x),
                          onBuzzer: (x) => setState(() => _buzzerOnGas = x),
                          onSave: () async {
                            await _mqtt.saveRules(
                              tempFanOn: _tempOn,
                              tempFanOff: _tempOff,
                              darkLightOn: _darkLight,
                              gasThreshold: _gasThr.round(),
                              gasOpenDoor: _gasDoor,
                              gasFanOn: _gasFan,
                              doorHoldSec: _doorHoldSec.round(),
                              buzzerOnGas: _buzzerOnGas,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã gửi rule xuống ESP — xem OLED trang RULES',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GasAlertBanner extends StatelessWidget {
  const _GasAlertBanner({required this.gas});
  final int gas;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'CẢNH BÁO GAS — mức $gas/1023. Kiểm tra ngay!',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseChipConnect extends StatelessWidget {
  const _HouseChipConnect({
    required this.controller,
    required this.connecting,
    required this.onConnect,
  });

  final TextEditingController controller;
  final bool connecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kết nối nhà',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Nhập Chip ID trên ESP8266 để điều khiển đúng nhà.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !connecting,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onConnect(),
                decoration: const InputDecoration(
                  labelText: 'Chip ID',
                  hintText: 'Ví dụ: 123',
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: connecting ? null : onConnect,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kết nối'),
            ),
          ],
        ),
      ],
    );
  }
}

class _VitalsStrip extends StatelessWidget {
  const _VitalsStrip({required this.v});
  final HomeVitals v;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: [
          _Metric(
            icon: Icons.thermostat_rounded,
            label: 'Nhiệt độ',
            value: '${v.temp.toStringAsFixed(1)}°',
          ),
          _Metric(
            icon: Icons.water_drop_outlined,
            label: 'Độ ẩm',
            value: '${v.humi.toStringAsFixed(0)}%',
          ),
          _Metric(
            icon: Icons.air_rounded,
            label: 'Gas/1023',
            value: v.gasDigital
                ? 'DO?'
                : (v.gasAlert ? '${v.gas}!' : '${v.gas}'),
            warn: v.gasAlert || v.gasSensorSuspect,
          ),
          _Metric(
            icon: Icons.wb_twilight_rounded,
            label: 'Ánh sáng',
            value: v.dark ? 'Tối' : 'Sáng',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppColors.danger : AppColors.ink;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isAuto, required this.onChanged});

  final bool isAuto;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              selected: !isAuto,
              label: 'Thủ công',
              icon: Icons.touch_app_rounded,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeChip(
              selected: isAuto,
              label: 'Tự động',
              icon: Icons.auto_awesome_rounded,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.sage : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualDevices extends StatelessWidget {
  const _ManualDevices({
    super.key,
    required this.lightOn,
    required this.fanOn,
    required this.doorDeg,
    required this.onLight,
    required this.onFan,
    required this.onOpenDoor,
    required this.onCloseDoor,
  });

  final bool lightOn;
  final bool fanOn;
  final int doorDeg;
  final ValueChanged<bool> onLight;
  final ValueChanged<bool> onFan;
  final VoidCallback onOpenDoor;
  final VoidCallback onCloseDoor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thiết bị',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DeviceTile(
                title: 'Đèn',
                subtitle: lightOn ? 'Đang bật' : 'Đang tắt',
                icon: lightOn
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded,
                active: lightOn,
                accent: AppColors.amber,
                onTap: () => onLight(!lightOn),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DeviceTile(
                title: 'Quạt',
                subtitle: fanOn ? 'Đang bật' : 'Đang tắt',
                icon: Icons.air_rounded,
                active: fanOn,
                accent: AppColors.sage,
                onTap: () => onFan(!fanOn),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.door_front_door_outlined,
                      color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cửa nhà',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: doorDeg > 10
                          ? AppColors.sage.withValues(alpha: 0.18)
                          : AppColors.inkSoft.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      doorDeg > 10 ? 'Đang mở' : 'Đang đóng',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: doorDeg > 10
                                ? AppColors.sage
                                : AppColors.inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                doorDeg > 10
                    ? 'Trạng thái: cửa đang mở'
                    : 'Trạng thái: cửa đang đóng',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: doorDeg > 10 ? null : onOpenDoor,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Mở cửa'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: doorDeg > 10 ? onCloseDoor : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Đóng cửa'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.14)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.35) : AppColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: active ? accent : AppColors.inkSoft),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoRules extends StatelessWidget {
  const _AutoRules({
    super.key,
    required this.tempOn,
    required this.tempOff,
    required this.darkLight,
    required this.gasThr,
    required this.gasDoor,
    required this.gasFan,
    required this.doorHoldSec,
    required this.buzzerOnGas,
    required this.liveGas,
    required this.onTempOn,
    required this.onTempOff,
    required this.onDarkLight,
    required this.onGasThr,
    required this.onGasDoor,
    required this.onGasFan,
    required this.onDoorHold,
    required this.onBuzzer,
    required this.onSave,
  });

  final double tempOn;
  final double tempOff;
  final bool darkLight;
  final double gasThr;
  final bool gasDoor;
  final bool gasFan;
  final double doorHoldSec;
  final bool buzzerOnGas;
  final int liveGas;
  final ValueChanged<double> onTempOn;
  final ValueChanged<double> onTempOff;
  final ValueChanged<bool> onDarkLight;
  final ValueChanged<double> onGasThr;
  final ValueChanged<bool> onGasDoor;
  final ValueChanged<bool> onGasFan;
  final ValueChanged<double> onDoorHold;
  final ValueChanged<bool> onBuzzer;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rule cảm biến (dùng khi AUTO)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Lưu → ESP + OLED cập nhật ngay. Chỉ điều khiển thiết bị khi đang Thủ công.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
              ),
        ),
        const SizedBox(height: 10),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bật quạt khi ≥ ${tempOn.toStringAsFixed(0)}°C',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 20,
                max: 40,
                divisions: 20,
                value: tempOn.clamp(20, 40),
                activeColor: AppColors.sage,
                onChanged: onTempOn,
              ),
              Text(
                'Tắt quạt khi ≤ ${tempOff.toStringAsFixed(0)}°C',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 18,
                max: 38,
                divisions: 20,
                value: tempOff.clamp(18, 38),
                activeColor: AppColors.sage,
                onChanged: onTempOff,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Trời tối thì bật đèn'),
                value: darkLight,
                activeThumbColor: AppColors.sage,
                onChanged: onDarkLight,
              ),
              Text(
                (liveGas <= 5 || liveGas >= 1000)
                    ? 'Ngưỡng: ${gasThr.toStringAsFixed(0)}/1023'
                        ' (đo $liveGas — nối MQ chân AO→A0, không dùng DO)'
                    : 'Ngưỡng gas: ${gasThr.toStringAsFixed(0)} / 1023'
                        '  (đang đo: $liveGas)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 0,
                max: HomeVitals.gasScaleMax.toDouble(),
                divisions: 64,
                value: gasThr.clamp(0, HomeVitals.gasScaleMax.toDouble()),
                activeColor: AppColors.amber,
                onChanged: onGasThr,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gas vượt ngưỡng → mở cửa'),
                subtitle: Text(
                  'Mở ${_doorHoldLabel(doorHoldSec)} rồi tự đóng',
                ),
                value: gasDoor,
                activeThumbColor: AppColors.sage,
                onChanged: onGasDoor,
              ),
              Text(
                'Giữ cửa mở: ${doorHoldSec.toStringAsFixed(0)} giây',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 1,
                max: 30,
                divisions: 29,
                value: doorHoldSec.clamp(1, 30),
                activeColor: AppColors.sage,
                onChanged: onDoorHold,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gas → bật quạt'),
                value: gasFan,
                activeThumbColor: AppColors.sage,
                onChanged: onGasFan,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Còi báo động khi có gas'),
                value: buzzerOnGas,
                activeThumbColor: AppColors.amber,
                onChanged: onBuzzer,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSave,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Lưu cấu hình'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _doorHoldLabel(double sec) => '${sec.round()} giây';
}
