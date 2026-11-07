import 'package:flutter/foundation.dart';
import '../api/auth_api.dart';
import '../models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthApi? api}) : _api = api ?? AuthApi();

  final AuthApi _api;
  AuthStatus status = AuthStatus.initial;
  UserModel? user;
  String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  Future<void> checkAuthStatus() async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      user = await _api.loadSession();
      status = user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
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
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
      String name, String email, String phone, String password) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _api.register(
          name: name, email: email, phone: phone, password: password);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      status = AuthStatus.unauthenticated;
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
    await _api.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
