enum UserRole {
  player('Player'),
  courtOwner('CourtOwner'),
  admin('Admin');

  const UserRole(this.apiValue);

  /// Giá trị role mà BE trả về / nhận vào.
  final String apiValue;

  static UserRole fromApi(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.apiValue.toLowerCase() == value?.toLowerCase(),
      orElse: () => UserRole.player,
    );
  }
}
