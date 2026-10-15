import '../strings/auth_strings.dart';

/// Các hàm kiểm tra dữ liệu nhập, dùng trực tiếp cho `TextFormField.validator`.
/// Trả về `null` khi hợp lệ, ngược lại trả về thông báo lỗi.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  // Số di động Việt Nam: 0 hoặc +84, theo sau là đầu số 3/5/7/8/9 và 8 chữ số.
  static final RegExp _phone = RegExp(r'^(0|\+84)[35789]\d{8}$');
  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasDigit = RegExp(r'\d');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPhone(String value) => _phone.hasMatch(value.trim());

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return AuthStrings.requiredField;
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return AuthStrings.requiredField;
    if (!isEmail(value)) return AuthStrings.invalidEmail;
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return AuthStrings.requiredField;
    if (!isPhone(value)) return AuthStrings.invalidPhone;
    return null;
  }

  /// Ô đăng nhập chấp nhận email hoặc số điện thoại.
  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) return AuthStrings.requiredField;
    if (!isEmail(value) && !isPhone(value)) return AuthStrings.invalidIdentifier;
    return null;
  }

  /// Theo BE: 3-30 ký tự, chữ không dấu / số / "." / "_".
  static final RegExp _username = RegExp(r'^[a-zA-Z0-9._]{3,30}$');

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return AuthStrings.requiredField;
    if (!_username.hasMatch(value.trim())) return AuthStrings.invalidUsername;
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return AuthStrings.requiredField;
    if (value.length < 8 || !_hasLetter.hasMatch(value) || !_hasDigit.hasMatch(value)) {
      return AuthStrings.invalidPassword;
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return AuthStrings.requiredField;
      if (value != original()) return AuthStrings.passwordMismatch;
      return null;
    };
  }
}
