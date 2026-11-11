import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import 'app_repositories.dart';
import 'repositories/player_profile_repository.dart';
import 'session_store.dart';

/// Người chơi phải làm khảo sát trước khi vào app.
///
/// BE chỉ báo `needsOnboarding` lúc đăng nhập; mở lại app thì hỏi GET /auth/me/onboarding. Đã biết là xong thì nhớ
/// trên máy (theo tài khoản) để lần sau vào thẳng. BE báo ONBOARDING_REQUIRED thì xoá dấu nhớ ([clear]).
class OnboardingGate {
  OnboardingGate._();

  static const String keyPrefix = 'onboarding_done_';

  /// `true`: phải làm khảo sát. Không kiểm tra được (mất mạng, server cũ chưa có API) thì cho vào app
  /// (BE vẫn chặn từng chức năng bằng ONBOARDING_REQUIRED).
  static Future<bool> needsSurvey(AppUser user) async {
    if (user.role != UserRole.player) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$keyPrefix${user.id}') == true) return false;
    try {
      final survey = await AppRepositories.playerProfile.getSurvey();
      if (survey.isCompleted) await prefs.setBool('$keyPrefix${user.id}', true);
      return !survey.isCompleted;
    } on PlayerProfileException {
      return false;
    }
  }

  /// Đã lưu khảo sát xong (tài khoản đang đăng nhập).
  static Future<void> markCompleted() async {
    final user = await SessionStore.readUser();
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$keyPrefix${user.id}', true);
  }

  /// BE báo chưa khảo sát: lần mở app sau phải hỏi lại.
  static Future<void> clear() async {
    final user = await SessionStore.readUser();
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$keyPrefix${user.id}');
  }
}
