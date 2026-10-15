import 'user_role.dart';

class AppUser {
  final String id;

  /// Tên đăng nhập (BE chỉ cho đăng nhập bằng username).
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final int fairPlayScore;

  const AppUser({
    required this.id,
    this.username = '',
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.fairPlayScore = 100,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: UserRole.fromApi(json['role'] as String?),
      fairPlayScore: (json['fairPlayScore'] as num?)?.toInt() ?? 100,
    );
  }

  /// Từ GET /api/accounts/{id} của BE (role nằm ở "roleName", Fair Play là số thập phân).
  factory AppUser.fromAccountJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromApi(json['roleName'] as String?),
      fairPlayScore: (json['fairPlayScore'] as num?)?.round() ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.apiValue,
        'fairPlayScore': fairPlayScore,
      };
}
