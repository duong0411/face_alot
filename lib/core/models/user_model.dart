class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatar,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatar;

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: '${j['id'] ?? j['_id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        avatar: j['avatar']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
      };
}
