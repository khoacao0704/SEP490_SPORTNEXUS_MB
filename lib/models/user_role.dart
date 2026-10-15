enum UserRole {
  player('Player'),
  courtOwner('Owner'),
  admin('Admin');

  const UserRole(this.apiValue);

  /// Giá trị role mà BE trả về / nhận vào.
  final String apiValue;

  static UserRole fromApi(String? value) {
    // Bản giả lập cũ lưu "CourtOwner"; BE dùng "Owner".
    if (value?.toLowerCase() == 'courtowner') return UserRole.courtOwner;
    return UserRole.values.firstWhere(
      (role) => role.apiValue.toLowerCase() == value?.toLowerCase(),
      orElse: () => UserRole.player,
    );
  }
}
