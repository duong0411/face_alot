import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/user_model.dart';

class AuthApi {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';

  String? token;

  Uri _u(String path) => Uri.parse('${AppConfig.apiBase}$path');

  Future<void> _save(String t, UserModel u) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, t);
    await p.setString(_userKey, jsonEncode(u.toJson()));
  }

  Future<void> logout() async {
    token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_userKey);
  }

  Future<UserModel?> loadSession() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_tokenKey);
    final u = p.getString(_userKey);
    if (t == null || u == null) return null;
    token = t;
    return UserModel.fromJson(jsonDecode(u) as Map<String, dynamic>);
  }

  Future<UserModel> login(String email, String password) async {
    final res = await http.post(
      _u('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Đăng nhập thất bại');
    }
    final data = body['data'] as Map<String, dynamic>;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _save('${data['token']}', user);
    return user;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      _u('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if ((res.statusCode != 201 && res.statusCode != 200) || body['success'] != true) {
      throw Exception(body['message'] ?? 'Đăng ký thất bại');
    }
    final data = body['data'] as Map<String, dynamic>;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _save('${data['token']}', user);
    return user;
  }

  Future<void> checkPhoneExists(String phone) async {
    final res = await http.post(
      _u('/api/auth/check-phone-exists'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone.trim()}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Số điện thoại không tồn tại');
    }
  }

  Future<void> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    final res = await http.post(
      _u('/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone.trim(),
        'newPassword': newPassword,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Đổi mật khẩu thất bại');
    }
  }
}
