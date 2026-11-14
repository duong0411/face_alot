import 'package:flutter/foundation.dart';
import '../api/auth_api.dart';
import '../config.dart';
import '../models/user_model.dart';
import '../push/fcm_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthApi? api}) : _api = api ?? AuthApi();

  final AuthApi _api;
  AuthStatus status = AuthStatus.initial;
  UserModel? user;
  String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  String? get authToken => _api.token;

  Future<void> _applyUserChip(UserModel u) async {
    final id = u.chipId.trim();
    if (id.isEmpty) return;
    await AppConfig.setChipId(id);
  }

  Future<void> checkAuthStatus() async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      user = await _api.loadSession();
      if (user != null) {
        await _applyUserChip(user!);
        status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _api.login(email, password);
      await _applyUserChip(user!);
      status = AuthStatus.authenticated;
      notifyListeners();
      await FcmService.instance.syncRegistration(authToken: _api.token);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String phone,
    String password, {
    required String chipId,
  }) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _api.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        chipId: chipId,
      );
      await _applyUserChip(user!);
      status = AuthStatus.authenticated;
      notifyListeners();
      await FcmService.instance.syncRegistration(authToken: _api.token);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Đổi Chip ID: local + MongoDB.
  Future<bool> saveChipId(String chipId) async {
    errorMessage = null;
    try {
      await AppConfig.setChipId(chipId);
      if (status == AuthStatus.authenticated && _api.token != null) {
        user = await _api.updateChipId(chipId);
        notifyListeners();
      }
      await FcmService.instance.syncRegistration(authToken: _api.token);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String phone) async {
    try {
      await _api.checkPhoneExists(phone);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      await _api.resetPassword(phone: phone, newPassword: newPassword);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await FcmService.instance.unregister(authToken: _api.token);
    await _api.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
