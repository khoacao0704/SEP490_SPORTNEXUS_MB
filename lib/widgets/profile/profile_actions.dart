import 'package:flutter/material.dart';

import '../../screens/auth/login_screen.dart';
import '../../theme/app_colors.dart';

/// Phiên đã bị BE thu hồi (đổi mật khẩu / xóa tài khoản): đóng mọi màn, về Đăng nhập và báo [message].
/// Repository đã xóa token và phiên trong máy trước khi gọi hàm này.
void goToLogin(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primaryGreen));
}

void showProfileError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
