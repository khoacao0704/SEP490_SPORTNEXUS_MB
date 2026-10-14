import 'user_role.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final int fairPlayScore;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.fairPlayScore = 100,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: UserRole.fromApi(json['role'] as String?),
      fairPlayScore: (json['fairPlayScore'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.apiValue,
        'fairPlayScore': fairPlayScore,
      };
}
