import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Thông tin phiên đăng nhập lưu trong máy (không gồm token: token nằm trong TokenStore).
///
/// Dùng chung key với MockAuthRepository: trong lúc nối API dần, các repository giả lập
/// (ví, đặt sân, LFG...) vẫn đọc người dùng hiện tại từ [keyCurrentUser].
class SessionStore {
  SessionStore._();

  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'user_role';
  static const String keyCurrentUser = 'current_user';
  static const String keyRememberMe = 'remember_me';

  static Future<void> save(AppUser user, {required bool rememberMe}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsLoggedIn, true);
    await prefs.setString(keyUserName, user.fullName);
    await prefs.setString(keyUserRole, user.role.apiValue);
    await prefs.setString(keyCurrentUser, jsonEncode(user.toJson()));
    await prefs.setBool(keyRememberMe, rememberMe);
  }

  /// Người dùng của phiên đã lưu; `null` nếu chưa đăng nhập hoặc dữ liệu hỏng.
  static Future<AppUser?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyCurrentUser);
    if (!(prefs.getBool(keyIsLoggedIn) ?? false) || raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> rememberMe() async =>
      (await SharedPreferences.getInstance()).getBool(keyRememberMe) ?? true;

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [keyIsLoggedIn, keyUserName, keyUserRole, keyCurrentUser, keyRememberMe]) {
      await prefs.remove(key);
    }
  }
}
