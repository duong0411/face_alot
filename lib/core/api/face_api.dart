import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'api_errors.dart';

/// Face gallery 1:N trên MongoDB Docker — gọi qua API public HTTPS.
class FaceApi {
  static const _tokenKey = 'auth_token';

  Future<String?> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
  }

  Uri _u(String path) => Uri.parse('${AppConfig.apiBase}$path');

  Future<Map<String, String>> _headers() async {
    final t = await _token();
    if (t == null || t.isEmpty) {
      throw AuthExpiredException('Chưa đăng nhập — cần đăng nhập lại để dùng gallery MongoDB');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $t',
    };
  }

  Never _throwApi(http.Response res, Map<String, dynamic> body, String fallback) {
    final msg = '${body['message'] ?? fallback}';
    if (res.statusCode == 401 ||
        msg.contains('hết hạn') ||
        msg.contains('đăng nhập') ||
        msg.contains('token')) {
      throw AuthExpiredException(msg);
    }
    throw Exception(msg);
  }

  Future<List<Map<String, dynamic>>> list() async {
    final res = await http.get(_u('/api/faces'), headers: await _headers());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      _throwApi(res, body, 'List faces failed');
    }
    return (body['data'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required Float32List embedding,
    String? personId,
  }) async {
    final res = await http.post(
      _u('/api/faces/register'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'embedding': embedding.toList(),
        if (personId != null) 'personId': personId,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if ((res.statusCode != 201 && res.statusCode != 200) || body['success'] != true) {
      _throwApi(res, body, 'Register face failed');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<Map<String, dynamic>> addSample({
    required String personId,
    required Float32List embedding,
  }) async {
    final res = await http.post(
      _u('/api/faces/sample'),
      headers: await _headers(),
      body: jsonEncode({
        'personId': personId,
        'embedding': embedding.toList(),
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      _throwApi(res, body, 'Add sample failed');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  /// 1:N identify từ xa (MongoDB trên Docker).
  Future<Map<String, dynamic>> identify({
    required Float32List embedding,
    double threshold = AppConfig.matchThreshold,
    int topK = 5,
  }) async {
    final res = await http.post(
      _u('/api/faces/identify'),
      headers: await _headers(),
      body: jsonEncode({
        'embedding': embedding.toList(),
        'threshold': threshold,
        'topK': topK,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      _throwApi(res, body, 'Identify failed');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<void> remove(String personId) async {
    final res = await http.delete(
      _u('/api/faces/$personId'),
      headers: await _headers(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      _throwApi(res, body, 'Delete failed');
    }
  }
}
