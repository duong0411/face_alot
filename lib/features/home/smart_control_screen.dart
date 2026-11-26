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

  late double _soilDryOn;
  late double _soilWetOff;
  late bool _darkLight;
  late bool _gasDoor;
  late bool _gasPump;
  late bool _gasFan;
  late double _tempFanOn;
  late double _tempFanOff;
  late double _doorHoldSec;
  late bool _buzzerOnGas;
  late bool _buzzerOnEmpty;
  late double _waterEmptyCm;
  late double _waterOkCm;
  late bool _autoPumpEmpty;
  late bool _autoPumpSoil;
  late bool _stopPumpRain;

  /// Đang kéo slider / chỉnh rule — không để tele MQTT kéo giá trị về cũ.
  bool _editingRules = false;

  @override
  void initState() {
    super.initState();
    _chipCtrl = TextEditingController(text: AppConfig.chipId);
    _soilDryOn = 30;
    _soilWetOff = 50;
    _darkLight = true;
    _gasDoor = true;
    _gasPump = false;
    _gasFan = true;
    _tempFanOn = 30;
    _tempFanOff = 28;
    _doorHoldSec = 5;
    _buzzerOnGas = true;
    _buzzerOnEmpty = true;
    _waterEmptyCm = 25;
    _waterOkCm = 18;
    _autoPumpEmpty = true;
    _autoPumpSoil = true;
    _stopPumpRain = true;
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
    // Vitals/tele vẫn rebuild UI qua AnimatedBuilder; chỉ đồng bộ rule khi
    // người dùng không đang chỉnh (tránh slider bị kéo lại mỗi vài giây).
    if (!_editingRules) {
      setState(() {
        _soilDryOn = v.soilDryOn;
        _soilWetOff = v.soilWetOff;
        _darkLight = v.darkLightOn;
        _gasDoor = v.gasOpenDoor;
        _gasPump = v.gasPumpOn;
        _gasFan = v.gasFanOn;
        _tempFanOn = v.tempFanOn;
        _tempFanOff = v.tempFanOff;
        _doorHoldSec = v.doorHoldSec.toDouble();
        _buzzerOnGas = v.buzzerOnGas;
        _buzzerOnEmpty = v.buzzerOnEmpty;
        _waterEmptyCm = v.waterEmptyCm;
        _waterOkCm = v.waterOkCm;
        _autoPumpEmpty = v.autoPumpEmpty;
        _autoPumpSoil = v.autoPumpSoil;
        _stopPumpRain = v.stopPumpRain;
      });
    }
    _maybeShowGasDialog(v);
  }

  void _markEditingRules() {
    if (!_editingRules) _editingRules = true;
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
        title: const Text('Cảnh báo gas / CO2'),
        content: Text(
          'Phát hiện khí gas tại nhà ${AppConfig.chipId}. '
          'Kiểm tra nguồn gas / thông gió. Còi ESP đang báo động.',
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
                          const _AlertBanner(
                            text: 'CẢNH BÁO GAS / CO2 — kiểm tra ngay!',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (v.waterEmpty) ...[
                          const _AlertBanner(
                            text: 'HẾT NƯỚC — còi báo · AUTO sẽ bật bơm',
                            color: AppColors.amber,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _VitalsStrip(v: v),
                        const SizedBox(height: 12),
                        _ExtraVitals(v: v),
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
                                      ? 'AUTO: đèn / bơm theo cảm biến + rule'
                                      : 'Thủ công: điều khiển đèn / bơm / cửa trên app',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isAuto
                              ? 'Đang AUTO — cảm biến điều khiển; chạm thiết bị bên dưới sẽ về Thủ công'
                              : 'Đang Thủ công — bật/tắt đèn / bơm / quạt trên app',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkSoft,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _ManualDevices(
                          key: const ValueKey('manual'),
                          lightOn: v.lightOn,
                          pumpOn: v.pumpOn,
                          fanOn: v.fanOn,
                          doorDeg: v.door,
                          onLight: _mqtt.setLight,
                          onPump: _mqtt.setPump,
                          onFan: _mqtt.setFan,
                          onOpenDoor: _mqtt.openDoor,
                          onCloseDoor: _mqtt.closeDoor,
                        ),
                        const SizedBox(height: 22),
                        _AutoRules(
                          key: const ValueKey('rules'),
                          soilDryOn: _soilDryOn,
                          soilWetOff: _soilWetOff,
                          darkLight: _darkLight,
                          gasDoor: _gasDoor,
                          gasPump: _gasPump,
                          gasFan: _gasFan,
                          tempFanOn: _tempFanOn,
                          tempFanOff: _tempFanOff,
                          doorHoldSec: _doorHoldSec,
                          buzzerOnGas: _buzzerOnGas,
                          buzzerOnEmpty: _buzzerOnEmpty,
                          waterEmptyCm: _waterEmptyCm,
                          waterOkCm: _waterOkCm,
                          autoPumpEmpty: _autoPumpEmpty,
                          autoPumpSoil: _autoPumpSoil,
                          stopPumpRain: _stopPumpRain,
                          liveSoil: v.soil,
                          liveWater: v.waterCm,
                          onSoilDry: (x) => setState(() {
                            _markEditingRules();
                            _soilDryOn = x;
                            if (_soilWetOff <= _soilDryOn) {
                              _soilWetOff = (_soilDryOn + 15).clamp(0, 100);
                            }
                          }),
                          onSoilWet: (x) => setState(() {
                            _markEditingRules();
                            _soilWetOff = x;
                          }),
                          onDarkLight: (x) => setState(() {
                            _markEditingRules();
                            _darkLight = x;
                          }),
                          onGasDoor: (x) => setState(() {
                            _markEditingRules();
                            _gasDoor = x;
                          }),
                          onGasPump: (x) => setState(() {
                            _markEditingRules();
                            _gasPump = x;
                          }),
                          onGasFan: (x) => setState(() {
                            _markEditingRules();
                            _gasFan = x;
                          }),
                          onTempFanOn: (x) => setState(() {
                            _markEditingRules();
                            _tempFanOn = x;
                            if (_tempFanOff >= _tempFanOn) {
                              _tempFanOff = _tempFanOn - 1;
                            }
                          }),
                          onTempFanOff: (x) => setState(() {
                            _markEditingRules();
                            _tempFanOff = x;
                          }),
                          onDoorHold: (x) => setState(() {
                            _markEditingRules();
                            _doorHoldSec = x;
                          }),
                          onBuzzerGas: (x) => setState(() {
                            _markEditingRules();
                            _buzzerOnGas = x;
                          }),
                          onBuzzerEmpty: (x) => setState(() {
                            _markEditingRules();
                            _buzzerOnEmpty = x;
                          }),
                          onWaterEmpty: (x) => setState(() {
                            _markEditingRules();
                            _waterEmptyCm = x;
                            if (_waterOkCm >= _waterEmptyCm) {
                              _waterOkCm = _waterEmptyCm - 2;
                            }
                          }),
                          onWaterOk: (x) => setState(() {
                            _markEditingRules();
                            _waterOkCm = x;
                          }),
                          onAutoPumpEmpty: (x) => setState(() {
                            _markEditingRules();
                            _autoPumpEmpty = x;
                          }),
                          onAutoPumpSoil: (x) => setState(() {
                            _markEditingRules();
                            _autoPumpSoil = x;
                          }),
                          onStopRain: (x) => setState(() {
                            _markEditingRules();
                            _stopPumpRain = x;
                          }),
                          onSave: () async {
                            await _mqtt.saveRules(
                              soilDryOn: _soilDryOn,
                              soilWetOff: _soilWetOff,
                              darkLightOn: _darkLight,
                              gasOpenDoor: _gasDoor,
                              gasPumpOn: _gasPump,
                              gasFanOn: _gasFan,
                              tempFanOn: _tempFanOn,
                              tempFanOff: _tempFanOff,
                              doorHoldSec: _doorHoldSec.round(),
                              buzzerOnGas: _buzzerOnGas,
                              buzzerOnEmpty: _buzzerOnEmpty,
                              waterEmptyCm: _waterEmptyCm,
                              waterOkCm: _waterOkCm,
                              autoPumpEmpty: _autoPumpEmpty,
                              autoPumpSoil: _autoPumpSoil,
                              stopPumpRain: _stopPumpRain,
                            );
                            if (!mounted) return;
                            setState(() => _editingRules = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã gửi rule xuống ESP32 — xem OLED trang RULES',
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

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.text, this.color = AppColors.danger});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
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
          'Nhập Chip ID trên ESP32 để điều khiển đúng nhà.',
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
                  hintText: 'Ví dụ: esp32',
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
            label: 'Độ ẩm KK',
            value: '${v.humi.toStringAsFixed(0)}%',
          ),
          _Metric(
            icon: Icons.air_rounded,
            label: 'Gas',
            value: v.gasAlert ? 'ALERT' : 'OK',
            warn: v.gasAlert,
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

class _ExtraVitals extends StatelessWidget {
  const _ExtraVitals({required this.v});
  final HomeVitals v;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: [
          _Metric(
            icon: Icons.grass_rounded,
            label: 'Độ ẩm đất',
            value: '${v.soil.clamp(0, 100)}%'
                '${v.soilDry ? ' · khô' : ''}',
            warn: v.soilDry,
          ),
          _Metric(
            icon: Icons.water_rounded,
            label: 'Mực nước',
            value: '${v.waterCm.toStringAsFixed(0)}cm',
            warn: v.waterEmpty,
          ),
          _Metric(
            icon: Icons.umbrella_rounded,
            label: 'Mưa',
            value: v.raining ? 'Có' : 'Không',
          ),
          _Metric(
            icon: Icons.water_damage_outlined,
            label: 'Bơm',
            value: v.pumpOn ? 'ON' : 'OFF',
          ),
          _Metric(
            icon: Icons.air_rounded,
            label: 'Quạt',
            value: v.fanOn ? 'ON' : 'OFF',
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
    required this.pumpOn,
    required this.fanOn,
    required this.doorDeg,
    required this.onLight,
    required this.onPump,
    required this.onFan,
    required this.onOpenDoor,
    required this.onCloseDoor,
  });

  final bool lightOn;
  final bool pumpOn;
  final bool fanOn;
  final int doorDeg;
  final ValueChanged<bool> onLight;
  final ValueChanged<bool> onPump;
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
                title: 'Bơm nước',
                subtitle: pumpOn ? 'Đang bật' : 'Đang tắt',
                icon: Icons.water_damage_rounded,
                active: pumpOn,
                accent: AppColors.sage,
                onTap: () => onPump(!pumpOn),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DeviceTile(
          title: 'Quạt',
          subtitle: fanOn ? 'Đang bật (GPIO19)' : 'Đang tắt — đấu relay GPIO19',
          icon: Icons.air_rounded,
          active: fanOn,
          accent: AppColors.sage,
          onTap: () => onFan(!fanOn),
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
    required this.soilDryOn,
    required this.soilWetOff,
    required this.darkLight,
    required this.gasDoor,
    required this.gasPump,
    required this.gasFan,
    required this.tempFanOn,
    required this.tempFanOff,
    required this.doorHoldSec,
    required this.buzzerOnGas,
    required this.buzzerOnEmpty,
    required this.waterEmptyCm,
    required this.waterOkCm,
    required this.autoPumpEmpty,
    required this.autoPumpSoil,
    required this.stopPumpRain,
    required this.liveSoil,
    required this.liveWater,
    required this.onSoilDry,
    required this.onSoilWet,
    required this.onDarkLight,
    required this.onGasDoor,
    required this.onGasPump,
    required this.onGasFan,
    required this.onTempFanOn,
    required this.onTempFanOff,
    required this.onDoorHold,
    required this.onBuzzerGas,
    required this.onBuzzerEmpty,
    required this.onWaterEmpty,
    required this.onWaterOk,
    required this.onAutoPumpEmpty,
    required this.onAutoPumpSoil,
    required this.onStopRain,
    required this.onSave,
  });

  final double soilDryOn;
  final double soilWetOff;
  final bool darkLight;
  final bool gasDoor;
  final bool gasPump;
  final bool gasFan;
  final double tempFanOn;
  final double tempFanOff;
  final double doorHoldSec;
  final bool buzzerOnGas;
  final bool buzzerOnEmpty;
  final double waterEmptyCm;
  final double waterOkCm;
  final bool autoPumpEmpty;
  final bool autoPumpSoil;
  final bool stopPumpRain;
  final int liveSoil;
  final double liveWater;
  final ValueChanged<double> onSoilDry;
  final ValueChanged<double> onSoilWet;
  final ValueChanged<bool> onDarkLight;
  final ValueChanged<bool> onGasDoor;
  final ValueChanged<bool> onGasPump;
  final ValueChanged<bool> onGasFan;
  final ValueChanged<double> onTempFanOn;
  final ValueChanged<double> onTempFanOff;
  final ValueChanged<double> onDoorHold;
  final ValueChanged<bool> onBuzzerGas;
  final ValueChanged<bool> onBuzzerEmpty;
  final ValueChanged<double> onWaterEmpty;
  final ValueChanged<double> onWaterOk;
  final ValueChanged<bool> onAutoPumpEmpty;
  final ValueChanged<bool> onAutoPumpSoil;
  final ValueChanged<bool> onStopRain;
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
          'Lưu → ESP32 + OLED cập nhật. Khoảng cách lớn = mực nước thấp.',
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
                'Đất khô khi độ ẩm ≤ ${soilDryOn.toStringAsFixed(0)}% (đo: $liveSoil%)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 0,
                max: 90,
                divisions: 90,
                value: soilDryOn.clamp(0, 90),
                activeColor: AppColors.sage,
                onChanged: onSoilDry,
              ),
              Text(
                'Đất đủ ẩm khi độ ẩm ≥ ${soilWetOff.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 10,
                max: 100,
                divisions: 90,
                value: soilWetOff.clamp(10, 100),
                activeColor: AppColors.sage,
                onChanged: onSoilWet,
              ),
              Text(
                'Hết nước khi khoảng cách ≥ ${waterEmptyCm.toStringAsFixed(0)} cm'
                ' (đo: ${liveWater.toStringAsFixed(1)} cm)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 5,
                max: 80,
                divisions: 75,
                value: waterEmptyCm.clamp(5, 80),
                activeColor: AppColors.amber,
                onChanged: onWaterEmpty,
              ),
              Text(
                'Đủ nước khi khoảng cách ≤ ${waterOkCm.toStringAsFixed(0)} cm',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 3,
                max: 70,
                divisions: 67,
                value: waterOkCm.clamp(3, 70),
                activeColor: AppColors.amber,
                onChanged: onWaterOk,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hết nước → tự bơm'),
                value: autoPumpEmpty,
                activeThumbColor: AppColors.sage,
                onChanged: onAutoPumpEmpty,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đất khô → tự bơm'),
                value: autoPumpSoil,
                activeThumbColor: AppColors.sage,
                onChanged: onAutoPumpSoil,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Có mưa → dừng bơm'),
                value: stopPumpRain,
                activeThumbColor: AppColors.sage,
                onChanged: onStopRain,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Trời tối thì bật đèn'),
                value: darkLight,
                activeThumbColor: AppColors.sage,
                onChanged: onDarkLight,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gas → mở cửa'),
                subtitle: Text('Giữ mở ${doorHoldSec.toStringAsFixed(0)} giây'),
                value: gasDoor,
                activeThumbColor: AppColors.sage,
                onChanged: onGasDoor,
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
                title: const Text('Gas → bật bơm'),
                value: gasPump,
                activeThumbColor: AppColors.sage,
                onChanged: onGasPump,
              ),
              Text(
                'Bật quạt khi ≥ ${tempFanOn.toStringAsFixed(0)}°C',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 20,
                max: 40,
                divisions: 20,
                value: tempFanOn.clamp(20, 40),
                activeColor: AppColors.sage,
                onChanged: onTempFanOn,
              ),
              Text(
                'Tắt quạt khi ≤ ${tempFanOff.toStringAsFixed(0)}°C',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                min: 18,
                max: 38,
                divisions: 20,
                value: tempFanOff.clamp(18, 38),
                activeColor: AppColors.sage,
                onChanged: onTempFanOff,
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
                title: const Text('Còi khi có gas'),
                value: buzzerOnGas,
                activeThumbColor: AppColors.amber,
                onChanged: onBuzzerGas,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Còi khi hết nước'),
                value: buzzerOnEmpty,
                activeThumbColor: AppColors.amber,
                onChanged: onBuzzerEmpty,
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
}
