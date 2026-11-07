import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config.dart';

class DoorMqtt {
  MqttServerClient? _client;
  bool get connected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    if (connected) return;
    final id = 'facealot_${Random().nextInt(1 << 30)}';
    final client =
        MqttServerClient.withPort(AppConfig.mqttWss, id, 443);
    client.useWebSocket = true;
    client.secure = false;
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(id)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    await client.connect().timeout(const Duration(seconds: 12));
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      throw Exception('MQTT connect failed');
    }
    _client = client;
  }

  Future<void> openDoor({required String name}) async {
    await connect();
    final c = _client!;
    final facePayload = MqttClientPayloadBuilder()
      ..addUTF8String(jsonEncode({'name': name, 'action': 'OPEN'}));
    c.publishMessage(
        AppConfig.faceTopic, MqttQos.atLeastOnce, facePayload.payload!);
    final doorPayload = MqttClientPayloadBuilder()..addUTF8String('ON');
    c.publishMessage(
        AppConfig.doorTopic, MqttQos.atLeastOnce, doorPayload.payload!);
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
