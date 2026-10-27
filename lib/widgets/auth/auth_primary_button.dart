import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Nút chính của form xác thực; hiện vòng xoay và khóa nút khi [isLoading].
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? trailingIcon;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon = Icons.arrow_forward,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.authPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.authPrimary.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Dòng "Câu hỏi? Liên kết" ở cuối form, ví dụ "Chưa có tài khoản? Đăng ký ngay".
class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback? onTap;

  const AuthFooterLink({super.key, required this.prompt, required this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Wrap: màn hẹp / chữ to thì liên kết xuống dòng thay vì tràn ngang.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(fontSize: 13, color: AppColors.authSubtle)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: onTap == null ? AppColors.authHint : AppColors.authPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

void showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
