import 'user_role.dart';

class AppUser {
  final String id;

  /// Tên đăng nhập (BE chỉ cho đăng nhập bằng username, không đổi được).
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final int fairPlayScore;

  /// Ảnh đại diện; `null` khi chưa có ảnh (BE trả null hoặc chuỗi rỗng đều coi là chưa có).
  final String? avatarUrl;
  final bool isPhoneVerified;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    this.username = '',
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.fairPlayScore = 100,
    this.avatarUrl,
    this.isPhoneVerified = false,
    this.createdAt,
  });

  /// Chữ cái đầu của tên, hiện thay ảnh đại diện khi chưa có ảnh.
  String get initial {
    final name = fullName.trim().isNotEmpty ? fullName.trim() : username.trim();
    return name.isEmpty ? '?' : name.split(RegExp(r'\s+')).last[0].toUpperCase();
  }

  static String? _avatar(Object? value) {
    final url = (value as String?)?.trim();
    return url == null || url.isEmpty ? null : url;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: UserRole.fromApi(json['role'] as String?),
      fairPlayScore: (json['fairPlayScore'] as num?)?.toInt() ?? 100,
      avatarUrl: _avatar(json['avatarUrl']),
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
      createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String)?.toLocal(),
    );
  }

  /// Từ GET /api/auth/me của BE: role nằm ở "roleName", Fair Play là số thập phân, giờ có múi giờ (UTC).
  factory AppUser.fromProfileJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromApi(json['roleName'] as String?),
      fairPlayScore: (json['fairPlayScore'] as num?)?.round() ?? 100,
      avatarUrl: _avatar(json['avatarUrl']),
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal(),
    );
  }

  AppUser copyWith({String? fullName, String? avatarUrl, bool clearAvatar = false}) => AppUser(
        id: id,
        username: username,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone,
        role: role,
        fairPlayScore: fairPlayScore,
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        isPhoneVerified: isPhoneVerified,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.apiValue,
        'fairPlayScore': fairPlayScore,
        'avatarUrl': avatarUrl,
        'isPhoneVerified': isPhoneVerified,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };
}
