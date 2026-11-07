import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../config.dart';

class HomeVitals {
  double temp = 0;
  double humi = 0;
  int gas = 0; // thang 0..1024 từ ESP
  bool gasAlert = false;
  bool dark = false;
  bool lightOn = false;
  bool fanOn = false;
  int door = 0;
  String mode = 'MANUAL';
  double tempFanOn = 30;
  double tempFanOff = 28;
  bool darkLightOn = true;
  int gasThreshold = 512; // 0..1024
  bool gasOpenDoor = true;
  bool gasFanOn = true;
  int doorHoldSec = 5; // mở cửa bao lâu rồi đóng
  bool buzzerOnGas = true;
  static const int gasScaleMax = 1024;
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
    client.subscribe(AppConfig.teleRelay1, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleRelay2, MqttQos.atMostOnce);
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
        vitals.dark = (j['dark'] ?? 0) == 1;
        vitals.lightOn = '${j['light']}' == 'ON';
        vitals.fanOn = '${j['fan']}' == 'ON';
        vitals.door = (j['door'] as num?)?.toInt() ?? vitals.door;
        vitals.mode = '${j['mode'] ?? vitals.mode}';
      } else if (topic.contains('_mode')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.mode = '${j['value'] ?? vitals.mode}';
      } else if (topic.contains('_rules')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
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
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.lightOn = '${j['value']}' == 'ON';
      } else if (topic.contains('_fan_')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.fanOn = '${j['value']}' == 'ON';
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
    await _pub(AppConfig.cmndRelay1, on ? 'ON' : 'OFF');
  }

  Future<void> setFan(bool on) async {
    if (vitals.mode == 'AUTO') return;
    vitals.fanOn = on;
    notifyListeners();
    await _pub(AppConfig.cmndRelay2, on ? 'ON' : 'OFF');
  }

  Future<void> openDoor() async {
    await _pub(AppConfig.doorTopic, 'ON');
  }

  Future<void> closeDoor() async {
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
    await _pub(AppConfig.cmndRules, body);
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
