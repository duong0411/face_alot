import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Đăng ký FCM token lên gas push bridge / API.
class PushApi {
  Uri _u(String path) {
    final base = AppConfig.pushApiBase.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<void> registerDevice({
    required String fcmToken,
    required String chipId,
    String? authToken,
  }) async {
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'unknown';
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    final res = await http
        .post(
          _u('/api/push/register'),
          headers: headers,
          body: jsonEncode({
            'token': fcmToken,
            'chipId': chipId,
            'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Đăng ký FCM thất bại (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> unregisterDevice({
    required String fcmToken,
    String? authToken,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    try {
      await http
          .post(
            _u('/api/push/unregister'),
            headers: headers,
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
