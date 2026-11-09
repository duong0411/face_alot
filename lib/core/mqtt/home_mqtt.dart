import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../alerts/gas_alert.dart';
import '../config.dart';

class HomeVitals {
  double temp = 0;
  double humi = 0;
  int gas = 0; // ADC raw 0..1023 từ ESP
  bool gasAlert = false;
  bool gasDigital = false; // ESP báo tín hiệu giống DO (chỉ 0/1023)
  bool dark = false;
  bool lightOn = false;
  bool fanOn = false;
  int door = 0;
  String mode = 'MANUAL';
  double tempFanOn = 30;
  double tempFanOff = 28;
  bool darkLightOn = true;
  int gasThreshold = 512; // 0..1023
  bool gasOpenDoor = true;
  bool gasFanOn = true;
  int doorHoldSec = 5; // mở cửa bao lâu rồi đóng
  bool buzzerOnGas = true;
  static const int gasScaleMax = 1023;

  bool get doorOpen => door > 10;

  /// Kẹt biên hoặc ESP báo gasDigital → thường nối nhầm DO thay AO
  bool get gasSensorSuspect => gasDigital || gas <= 5 || gas >= 1000;
}

class HomeMqtt extends ChangeNotifier {
  MqttServerClient? _client;
  final vitals = HomeVitals();
  bool get connected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    if (connected) return;
    final id = 'facealot_home_${Random().nextInt(1 << 30)}';
    final client = MqttServerClient.withPort(AppConfig.mqttWss, id, 443);
    client.useWebSocket = true;
    client.secure = false;
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.connectionMessage =
        MqttConnectMessage().withClientIdentifier(id).startClean();
    await client.connect().timeout(const Duration(seconds: 12));
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      throw Exception('MQTT connect failed');
    }
    _client = client;
    client.updates?.listen(_onMsg);
    client.subscribe(AppConfig.teleVitals, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleMode, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleRules, MqttQos.atMostOnce);
    // Đèn/quạt wiring thực tế ngược topic led1 ↔ fan — swap khi đọc tele
    client.subscribe(AppConfig.teleRelay1, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleRelay2, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleDoor, MqttQos.atMostOnce);
    // Xin ESP đẩy lại rules hiện tại lên OLED/app
    await _pub(AppConfig.cmndRulesGet, 'GET');
  }

  /// Đổi nhà (chip) — ngắt kết nối cũ rồi subscribe topic mới
  Future<void> reconnect() async {
    disconnect();
    await connect();
  }

  void _onMsg(List<MqttReceivedMessage<MqttMessage>>? events) {
    if (events == null) return;
    for (final e in events) {
      final rec = e.payload as MqttPublishMessage;
      final topic = e.topic;
      final payload =
          MqttPublishPayload.bytesToStringAsString(rec.payload.message);
      _apply(topic, payload);
    }
    notifyListeners();
  }

  void _apply(String topic, String payload) {
    try {
      if (topic.contains('_vitals')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.temp = (j['temp'] as num?)?.toDouble() ?? vitals.temp;
        vitals.humi = (j['humi'] as num?)?.toDouble() ?? vitals.humi;
        vitals.gas = (j['gas'] as num?)?.toInt() ?? vitals.gas;
        vitals.gasAlert = (j['gasAlert'] ?? 0) == 1;
        vitals.gasDigital = (j['gasDigital'] ?? 0) == 1;
        vitals.dark = (j['dark'] ?? 0) == 1;
        // Swap: ESP "light"=relay1 nhưng dây thực = quạt; "fan"=relay2 = đèn
        vitals.fanOn = '${j['light']}' == 'ON';
        vitals.lightOn = '${j['fan']}' == 'ON';
        vitals.door = (j['door'] as num?)?.toInt() ?? vitals.door;
        vitals.mode = '${j['mode'] ?? vitals.mode}';
        // Cảnh báo trên điện thoại khi ESP báo gas
        unawaited(
          GasAlert.instance.handleVitals(
            gasAlert: vitals.gasAlert,
            gas: vitals.gas,
          ),
        );
      } else if (topic.contains('_mode')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.mode = '${j['value'] ?? vitals.mode}';
      } else if (topic.contains('_rules')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        if (j.containsKey('ack') && !j.containsKey('tempFanOn')) return;
        vitals.mode = '${j['mode'] ?? vitals.mode}';
        vitals.tempFanOn =
            (j['tempFanOn'] as num?)?.toDouble() ?? vitals.tempFanOn;
        vitals.tempFanOff =
            (j['tempFanOff'] as num?)?.toDouble() ?? vitals.tempFanOff;
        vitals.darkLightOn = (j['darkLightOn'] ?? 1) == 1;
        vitals.gasThreshold =
            (j['gasThreshold'] as num?)?.toInt() ?? vitals.gasThreshold;
        vitals.gasOpenDoor = (j['gasOpenDoor'] ?? 1) == 1;
        vitals.gasFanOn = (j['gasFanOn'] ?? 1) == 1;
        vitals.doorHoldSec =
            (j['doorHoldSec'] as num?)?.toInt() ?? vitals.doorHoldSec;
        vitals.buzzerOnGas = (j['buzzerOnGas'] ?? 1) == 1;
      } else if (topic.contains('_led1')) {
        // Topic led1 thực tế đang điều khiển quạt
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.fanOn = '${j['value']}' == 'ON';
      } else if (topic.contains('_fan_')) {
        // Topic fan thực tế đang điều khiển đèn
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.lightOn = '${j['value']}' == 'ON';
      } else if (topic.contains('_door_')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        final v = j['value'];
        if (v is num) {
          vitals.door = v.toInt();
        } else if (v != null) {
          final s = '$v'.toUpperCase();
          if (s == 'ON' || s == 'OPEN') {
            vitals.door = 90;
          } else if (s == 'OFF' || s == 'CLOSE') {
            vitals.door = 0;
          } else {
            vitals.door = int.tryParse('$v') ?? vitals.door;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pub(String topic, String payload) async {
    await connect();
    final b = MqttClientPayloadBuilder()..addUTF8String(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, b.payload!);
  }

  Future<void> setMode(bool auto) async {
    vitals.mode = auto ? 'AUTO' : 'MANUAL';
    notifyListeners();
    await _pub(AppConfig.cmndMode, auto ? 'AUTO' : 'MANUAL');
  }

  Future<void> setLight(bool on) async {
    if (vitals.mode == 'AUTO') return;
    vitals.lightOn = on;
    notifyListeners();
    // Swap: đèn UI → topic fan (relay2)
    await _pub(AppConfig.cmndRelay2, on ? 'ON' : 'OFF');
  }

  Future<void> setFan(bool on) async {
    if (vitals.mode == 'AUTO') return;
    vitals.fanOn = on;
    notifyListeners();
    // Swap: quạt UI → topic led1 (relay1)
    await _pub(AppConfig.cmndRelay1, on ? 'ON' : 'OFF');
  }

  Future<void> openDoor() async {
    vitals.door = 90;
    notifyListeners();
    await _pub(AppConfig.doorTopic, 'ON');
  }

  Future<void> closeDoor() async {
    vitals.door = 0;
    notifyListeners();
    await _pub(AppConfig.doorTopic, 'OFF');
  }

  Future<void> saveRules({
    required double tempFanOn,
    required double tempFanOff,
    required bool darkLightOn,
    required int gasThreshold,
    required bool gasOpenDoor,
    required bool gasFanOn,
    required int doorHoldSec,
    required bool buzzerOnGas,
  }) async {
    vitals.tempFanOn = tempFanOn;
    vitals.tempFanOff = tempFanOff;
    vitals.darkLightOn = darkLightOn;
    vitals.gasThreshold = gasThreshold.clamp(0, HomeVitals.gasScaleMax);
    vitals.gasOpenDoor = gasOpenDoor;
    vitals.gasFanOn = gasFanOn;
    vitals.doorHoldSec = doorHoldSec.clamp(1, 60);
    vitals.buzzerOnGas = buzzerOnGas;
    notifyListeners();
    final body = jsonEncode({
      'mode': vitals.mode,
      'tempFanOn': tempFanOn,
      'tempFanOff': tempFanOff,
      'darkLightOn': darkLightOn ? 1 : 0,
      'gasThreshold': vitals.gasThreshold,
      'gasOpenDoor': gasOpenDoor ? 1 : 0,
      'gasFanOn': gasFanOn ? 1 : 0,
      'doorHoldSec': vitals.doorHoldSec,
      'buzzerOnGas': buzzerOnGas ? 1 : 0,
    });
    // Publish cả SET và POWER — firmware cũ/mới đều nhận
    await _pub(AppConfig.cmndRules, body);
    await _pub(AppConfig.cmndRulesPower, body);
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
