import 'package:flutter/material.dart';
import '../../core/mqtt/home_mqtt.dart';

class SmartControlScreen extends StatefulWidget {
  const SmartControlScreen({super.key});

  @override
  State<SmartControlScreen> createState() => _SmartControlScreenState();
}

class _SmartControlScreenState extends State<SmartControlScreen> {
  final _mqtt = HomeMqtt();
  String _status = 'Đang kết nối MQTT...';

  late double _tempOn;
  late double _tempOff;
  late bool _darkLight;
  late double _gasThr;
  late bool _gasDoor;
  late bool _gasFan;

  @override
  void initState() {
    super.initState();
    _tempOn = 30;
    _tempOff = 28;
    _darkLight = true;
    _gasThr = 500;
    _gasDoor = true;
    _gasFan = true;
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _mqtt.connect();
      _mqtt.addListener(_syncFromMqtt);
      setState(() => _status = 'Đã kết nối broker');
    } catch (e) {
      setState(() => _status = 'Lỗi MQTT: $e');
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
    });
  }

  @override
  void dispose() {
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
          appBar: AppBar(title: const Text('Điều khiển nhà')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_status, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              _SensorCard(v: v),
              const SizedBox(height: 16),
              Text('Chế độ', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Thủ công'), icon: Icon(Icons.touch_app)),
                  ButtonSegment(value: true, label: Text('Tự động'), icon: Icon(Icons.auto_mode)),
                ],
                selected: {isAuto},
                onSelectionChanged: (s) => _mqtt.setMode(s.first),
              ),
              const SizedBox(height: 20),
              if (!isAuto) ...[
                Text('Thủ công — bật/tắt thiết bị',
                    style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  title: const Text('Đèn (Relay 1)'),
                  value: v.lightOn,
                  onChanged: (x) => _mqtt.setLight(x),
                ),
                SwitchListTile(
                  title: const Text('Quạt (Relay 2)'),
                  value: v.fanOn,
                  onChanged: (x) => _mqtt.setFan(x),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _mqtt.openDoor(),
                        child: const Text('Mở cửa'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _mqtt.closeDoor(),
                        child: const Text('Đóng cửa'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text('Tự động — cấu hình cảm biến',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Nhiệt độ bật quạt: ${_tempOn.toStringAsFixed(0)}°C'),
                Slider(
                  min: 20,
                  max: 40,
                  divisions: 20,
                  value: _tempOn.clamp(20, 40),
                  onChanged: (x) => setState(() {
                    _tempOn = x;
                    if (_tempOff >= _tempOn) _tempOff = _tempOn - 1;
                  }),
                ),
                Text('Nhiệt độ tắt quạt: ${_tempOff.toStringAsFixed(0)}°C'),
                Slider(
                  min: 18,
                  max: 38,
                  divisions: 20,
                  value: _tempOff.clamp(18, 38),
                  onChanged: (x) => setState(() => _tempOff = x),
                ),
                SwitchListTile(
                  title: const Text('Trời tối → bật đèn'),
                  value: _darkLight,
                  onChanged: (x) => setState(() => _darkLight = x),
                ),
                Text('Ngưỡng gas ADC: ${_gasThr.toStringAsFixed(0)}'),
                Slider(
                  min: 100,
                  max: 900,
                  divisions: 40,
                  value: _gasThr.clamp(100, 900),
                  onChanged: (x) => setState(() => _gasThr = x),
                ),
                SwitchListTile(
                  title: const Text('Có gas → mở cửa'),
                  value: _gasDoor,
                  onChanged: (x) => setState(() => _gasDoor = x),
                ),
                SwitchListTile(
                  title: const Text('Có gas → bật quạt'),
                  value: _gasFan,
                  onChanged: (x) => setState(() => _gasFan = x),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await _mqtt.saveRules(
                      tempFanOn: _tempOn,
                      tempFanOff: _tempOff,
                      darkLightOn: _darkLight,
                      gasThreshold: _gasThr.round(),
                      gasOpenDoor: _gasDoor,
                      gasFanOn: _gasFan,
                    );
                    if (!mounted) return;
                    final messenger = ScaffoldMessenger.of(this.context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đã gửi rule AUTO tới ESP')),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Lưu cấu hình AUTO'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.v});
  final HomeVitals v;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cảm biến realtime',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _chip('Nhiệt', '${v.temp.toStringAsFixed(1)}°C'),
                _chip('Ẩm', '${v.humi.toStringAsFixed(0)}%'),
                _chip('Gas', '${v.gas}${v.gasAlert ? "!" : ""}'),
                _chip('Ánh sáng', v.dark ? 'Tối' : 'Sáng'),
                _chip('Đèn', v.lightOn ? 'ON' : 'OFF'),
                _chip('Quạt', v.fanOn ? 'ON' : 'OFF'),
                _chip('Cửa', '${v.door}°'),
                _chip('Mode', v.mode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String k, String v) => Chip(label: Text('$k: $v'));
}
