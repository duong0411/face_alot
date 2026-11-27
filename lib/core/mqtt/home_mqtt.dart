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
  int gas = 0; // ESP32: gas D0 → 0/1; vẫn giữ field cho UI
  bool gasAlert = false;
  bool gasDigital = true; // ESP32 đọc D0
  bool dark = false;
  bool lightOn = false;
  bool pumpOn = false;
  int door = 0;
  String mode = 'MANUAL';

  // Rule ESP32
  double soilDryOn = 30;   // % do am <= → khô
  double soilWetOff = 50;  // % do am >= → đủ ẩm
  bool darkLightOn = true;
  int gasThreshold = 1;
  bool gasOpenDoor = true;
  bool gasPumpOn = false;
  int doorHoldSec = 5;
  bool buzzerOnGas = true;
  bool buzzerOnEmpty = false;
  double waterEmptyCm = 8;
  double waterOkCm = 4;
  bool autoPumpEmpty = false;
  bool autoPumpSoil = true;
  bool stopPumpRain = true;

  // Sensor live
  int soil = 0;
  bool soilDry = false;
  bool raining = false;
  double waterCm = 0;
  bool waterEmpty = false;

  static const int soilScaleMax = 100;

  bool get doorOpen => door > 10;
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
    // ESP32: led1=đèn, pump=bơm (không quạt trên app)
    client.subscribe(AppConfig.teleRelay1, MqttQos.atMostOnce);
    client.subscribe(AppConfig.telePump, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleDoor, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleWater, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleSoil, MqttQos.atMostOnce);
    client.subscribe(AppConfig.teleRain, MqttQos.atMostOnce);
    await _pub(AppConfig.cmndRulesGet, 'GET');
  }

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
        vitals.gasDigital = (j['gasDigital'] ?? 1) == 1;
        vitals.dark = (j['dark'] ?? 0) == 1;
        vitals.lightOn = '${j['light']}' == 'ON';
        vitals.pumpOn = '${j['pump']}' == 'ON';
        vitals.door = (j['door'] as num?)?.toInt() ?? vitals.door;
        vitals.mode = '${j['mode'] ?? vitals.mode}';
        // Ưu tiên % (0–100); bỏ qua ADC thô nếu firmware gửi nhầm
        final soilPct = (j['soilPct'] as num?)?.toInt() ??
            (j['soil'] as num?)?.toInt();
        if (soilPct != null) {
          vitals.soil = soilPct > 100 ? vitals.soil : soilPct.clamp(0, 100);
        }
        vitals.soilDry = (j['soilDry'] ?? 0) == 1;
        vitals.raining = (j['rain'] ?? 0) == 1;
        vitals.waterCm = (j['waterCm'] as num?)?.toDouble() ?? vitals.waterCm;
        vitals.waterEmpty = (j['waterEmpty'] ?? 0) == 1;
        unawaited(
          GasAlert.instance.handleVitals(
            gasAlert: vitals.gasAlert,
            gas: vitals.gasAlert ? 1 : 0,
          ),
        );
      } else if (topic.contains('_mode')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.mode = '${j['value'] ?? vitals.mode}';
      } else if (topic.contains('_rules')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        if (j.containsKey('ack') &&
            !j.containsKey('soilDryOn') &&
            !j.containsKey('waterEmptyCm') &&
            !j.containsKey('autoPumpEmpty')) {
          return;
        }
        vitals.mode = '${j['mode'] ?? vitals.mode}';
        vitals.soilDryOn =
            (j['soilDryOn'] as num?)?.toDouble() ?? vitals.soilDryOn;
        vitals.soilWetOff =
            (j['soilWetOff'] as num?)?.toDouble() ?? vitals.soilWetOff;
        vitals.darkLightOn = (j['darkLightOn'] ?? 1) == 1;
        vitals.gasThreshold =
            (j['gasThreshold'] as num?)?.toInt() ?? vitals.gasThreshold;
        vitals.gasOpenDoor = (j['gasOpenDoor'] ?? 1) == 1;
        vitals.gasPumpOn = (j['gasPumpOn'] ?? 0) == 1;
        vitals.doorHoldSec =
            (j['doorHoldSec'] as num?)?.toInt() ?? vitals.doorHoldSec;
        vitals.buzzerOnGas = (j['buzzerOnGas'] ?? 1) == 1;
        vitals.buzzerOnEmpty = (j['buzzerOnEmpty'] ?? 1) == 1;
        vitals.waterEmptyCm =
            (j['waterEmptyCm'] as num?)?.toDouble() ?? vitals.waterEmptyCm;
        vitals.waterOkCm =
            (j['waterOkCm'] as num?)?.toDouble() ?? vitals.waterOkCm;
        vitals.autoPumpEmpty = (j['autoPumpEmpty'] ?? 1) == 1;
        vitals.autoPumpSoil = (j['autoPumpSoil'] ?? 1) == 1;
        vitals.stopPumpRain = (j['stopPumpRain'] ?? 1) == 1;
      } else if (topic.contains('_led1')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.lightOn = '${j['value']}' == 'ON';
      } else if (topic.contains('_pump')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.pumpOn = '${j['value']}' == 'ON';
      } else if (topic.contains('_water')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.waterCm = (j['cm'] as num?)?.toDouble() ?? vitals.waterCm;
        vitals.waterEmpty = (j['empty'] ?? 0) == 1;
      } else if (topic.contains('_soil')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        final soilPct = (j['pct'] as num?)?.toInt() ??
            (j['value'] as num?)?.toInt();
        if (soilPct != null && soilPct <= 100) {
          vitals.soil = soilPct.clamp(0, 100);
        }
        vitals.soilDry = (j['dry'] ?? 0) == 1;
      } else if (topic.contains('_rain')) {
        final j = jsonDecode(payload) as Map<String, dynamic>;
        vitals.raining = '${j['value']}' == 'ON';
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
    // Lenh tay → MANUAL (khop firmware forceManual)
    if (vitals.mode == 'AUTO') {
      vitals.mode = 'MANUAL';
      await _pub(AppConfig.cmndMode, 'MANUAL');
    }
    vitals.lightOn = on;
    notifyListeners();
    await _pub(AppConfig.cmndRelay1, on ? 'ON' : 'OFF');
  }

  Future<void> setPump(bool on) async {
    if (vitals.mode == 'AUTO') {
      vitals.mode = 'MANUAL';
      await _pub(AppConfig.cmndMode, 'MANUAL');
    }
    vitals.pumpOn = on;
    notifyListeners();
    final payload = on ? 'ON' : 'OFF';
    await _pub(AppConfig.cmndPump, payload);
    // Tuong thich APK/firmware cu: fan_livingroom = bom
    await _pub(AppConfig.cmndPumpLegacy, payload);
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
    required double soilDryOn,
    required double soilWetOff,
    required bool darkLightOn,
    required bool gasOpenDoor,
    required bool gasPumpOn,
    required int doorHoldSec,
    required bool buzzerOnGas,
    required double waterEmptyCm,
    required double waterOkCm,
    required bool autoPumpSoil,
    required bool stopPumpRain,
  }) async {
    vitals.soilDryOn = soilDryOn;
    vitals.soilWetOff = soilWetOff;
    vitals.darkLightOn = darkLightOn;
    vitals.gasOpenDoor = gasOpenDoor;
    vitals.gasPumpOn = gasPumpOn;
    vitals.doorHoldSec = doorHoldSec.clamp(1, 60);
    vitals.buzzerOnGas = buzzerOnGas;
    vitals.buzzerOnEmpty = true;
    vitals.waterEmptyCm = waterEmptyCm.clamp(1, 10);
    vitals.waterOkCm = waterOkCm.clamp(1, 10);
    vitals.autoPumpEmpty = false;
    vitals.autoPumpSoil = autoPumpSoil;
    vitals.stopPumpRain = stopPumpRain;
    notifyListeners();
    // Bỏ quạt + bỏ AUTO bơm hết nước; giữ còi hết nước (firmware kêu 5s AUTO)
    final body = jsonEncode({
      'mode': vitals.mode,
      'soilDryOn': soilDryOn,
      'soilWetOff': soilWetOff,
      'darkLightOn': darkLightOn ? 1 : 0,
      'gasOpenDoor': gasOpenDoor ? 1 : 0,
      'gasPumpOn': gasPumpOn ? 1 : 0,
      'doorHoldSec': vitals.doorHoldSec,
      'buzzerOnGas': buzzerOnGas ? 1 : 0,
      'buzzerOnEmpty': 1,
      'waterEmptyCm': vitals.waterEmptyCm,
      'waterOkCm': vitals.waterOkCm,
      'autoPumpEmpty': 0,
      'autoPumpSoil': autoPumpSoil ? 1 : 0,
      'stopPumpRain': stopPumpRain ? 1 : 0,
    });
    await _pub(AppConfig.cmndRules, body);
    await _pub(AppConfig.cmndRulesPower, body);
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
