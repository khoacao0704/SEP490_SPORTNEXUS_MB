import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../main/main_navigation_screen.dart';
import 'owner_pending_screen.dart';

/// App mobile chỉ dành cho Player và Chủ sân; Admin dùng Web Portal.
bool isRoleAllowedOnMobile(UserRole role) => role != UserRole.admin;

/// Màn hình chính tương ứng với role sau khi đăng nhập.
/// Chỉ gọi khi [isRoleAllowedOnMobile] trả về true.
Widget homeScreenFor(AppUser user) {
  switch (user.role) {
    case UserRole.player:
      return const MainNavigationScreen();
    case UserRole.courtOwner:
      return OwnerPendingScreen(user: user);
    case UserRole.admin:
      throw StateError('Admin không sử dụng app mobile');
  }
}

/// Xóa toàn bộ stack (login, OTP...) và vào màn hình chính theo role.
void goToHome(BuildContext context, AppUser user) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => homeScreenFor(user)),
    (_) => false,
  );
}
