import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/strings/common_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

/// Màn hình tạm cho Chủ sân cho đến khi giao diện Chủ sân trên mobile được phát triển.
class OwnerPendingScreen extends StatelessWidget {
  final AppUser user;

  const OwnerPendingScreen({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    await AppRepositories.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.storefront, size: 48, color: AppColors.primaryGreen),
                ),
                const SizedBox(height: 24),
                const Text(
                  AuthStrings.ownerPendingTitle,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 8),
                Text(
                  'Xin chào, ${user.fullName}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  AuthStrings.ownerPendingMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMain, height: 1.5),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: AppColors.primaryGreen),
                  label: const Text(
                    CommonStrings.logout,
                    style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
