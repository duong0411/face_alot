class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatar,
    this.chipId = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatar;
  /// Chip ID nhà ESP lưu trên MongoDB — tự nạp khi login.
  final String chipId;

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: '${j['id'] ?? j['_id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        avatar: j['avatar']?.toString(),
        chipId: '${j['chipId'] ?? ''}'.trim(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'chipId': chipId,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? chipId,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatar: avatar ?? this.avatar,
        chipId: chipId ?? this.chipId,
      );
}
