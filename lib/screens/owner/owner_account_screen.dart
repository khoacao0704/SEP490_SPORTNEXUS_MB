import 'package:flutter/material.dart';

import '../../core/strings/common_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import 'listing_fee_screen.dart';
import 'owner_finance_screen.dart';
import 'owner_notifications.dart';
import 'owner_reviews_screen.dart';
import 'owner_tournaments_screen.dart';

/// Tài khoản Chủ sân: thông tin, các mục sẽ làm ở bước sau, đăng xuất.
class OwnerAccountScreen extends StatelessWidget {
  final AppUser user;

  /// Chuyển tab trong khung chính khi mở thông báo.
  final ValueChanged<OwnerTab>? onSelectTab;

  const OwnerAccountScreen({super.key, required this.user, this.onSelectTab});

  Future<void> _logout(BuildContext context) async {
    await AppRepositories.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final menu = <(IconData, String, Widget Function())>[
      (Icons.account_balance_wallet_outlined, OwnerStrings.menuRevenue, () => const OwnerFinanceScreen()),
      (Icons.receipt_long_outlined, OwnerStrings.menuListingFee, () => const ListingFeeScreen()),
      (Icons.star_outline, OwnerStrings.menuReviews, () => const OwnerReviewsScreen()),
      (Icons.emoji_events_outlined, OwnerStrings.menuTournaments, () => const OwnerTournamentsScreen()),
      (
        Icons.notifications_outlined,
        OwnerStrings.menuNotifications,
        () => ownerNotificationsScreen(onSelectTab: onSelectTab ?? (_) {}),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          OwnerStrings.accountTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.lightGreen,
                  child: Icon(Icons.storefront, color: AppColors.primaryGreen, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(user.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          OwnerStrings.roleOwner,
                          style: TextStyle(color: AppColors.darkGreen, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                for (final (icon, label, screen) in menu)
                  ListTile(
                    leading: Icon(icon, color: AppColors.primaryGreen),
                    title: Text(label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen())),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              CommonStrings.logout,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
