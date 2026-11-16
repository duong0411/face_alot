/// Lỗi xác thực — JWT hết hạn / không hợp lệ.
class AuthExpiredException implements Exception {
  AuthExpiredException([this.message = 'Token đã hết hạn. Vui lòng đăng nhập lại.']);
  final String message;

  @override
  String toString() => message;
}
