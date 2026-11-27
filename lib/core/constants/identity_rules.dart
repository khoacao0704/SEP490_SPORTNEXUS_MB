/// Luật hồ sơ eKYC của BE (POST /api/v1/me/verification).
class IdentityRules {
  IdentityRules._();

  /// Số CCCD gồm đúng chừng này chữ số.
  static const int idNumberLength = 12;
  static const int minAge = 18;

  /// Ảnh JPG / PNG / WEBP, tối đa 5MB.
  static const int maxImageBytes = 5 * 1024 * 1024;

  static final RegExp _idNumber = RegExp(r'^\d{12}$');

  static bool isValidIdNumber(String value) => _idNumber.hasMatch(value.trim());

  /// Đủ [minAge] tuổi tính tới [now].
  static bool isAdult(DateTime dateOfBirth, DateTime now) {
    final adultFrom = DateTime(dateOfBirth.year + minAge, dateOfBirth.month, dateOfBirth.day);
    return !adultFrom.isAfter(DateTime(now.year, now.month, now.day));
  }
}
