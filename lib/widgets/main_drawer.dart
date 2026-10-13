import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../screens/auth/login_screen.dart';
import '../screens/profile/top_up_wallet_screen.dart';
import '../screens/booking/court_booking_screen.dart';
import '../screens/main/main_navigation_screen.dart';

class MainDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onItemSelected;

  const MainDrawer({
    super.key,
    this.selectedIndex = 0,
    this.onItemSelected,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  const Text(
                    'MENU ĐIỀU HƯỚNG',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 1. Trang Chủ
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_outlined,
                    title: 'Trang Chủ',
                    index: 0,
                    onTapCustom: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 0)),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 2. Đặt Sân
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.calendar_month_outlined,
                    title: 'Đặt Sân',
                    index: 1,
                    onTapCustom: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CourtBookingScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 3. Ghép Trận LFG
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.group_outlined,
                    title: 'Ghép Trận LFG',
                    index: 2,
                    onTapCustom: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 4. Check-in QR
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'Check-in QR',
                    index: 3,
                    onTapCustom: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 5. Giải Đấu
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.emoji_events_outlined,
                    title: 'Giải Đấu',
                    index: 4,
                    onTapCustom: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng Giải Đấu sắp ra mắt!'),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 6. Nạp Ví Escrow
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Nạp Ví Escrow',
                    index: 5,
                    onTapCustom: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TopUpWalletScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Log Out Button
                  ElevatedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Đăng Xuất'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Footer
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.sports_tennis, size: 16, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SportNexus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textMain,
                    ),
                  ),
                  const Text(
                    ' © 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.language, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  const Text(
                    'VIE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.settings, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    VoidCallback? onTapCustom,
  }) {
    final bool isSelected = selectedIndex == index;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D5238) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            leading: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF334155),
              size: 22,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            trailing: isSelected
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), // Glowing light green dot
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () {
              if (onTapCustom != null) {
                onTapCustom();
              } else {
                Navigator.pop(context); // Close drawer
                if (onItemSelected != null) {
                  onItemSelected!(index);
                }
              }
            },
          ),
        ),
        if (isSelected)
          Positioned(
            left: 0,
            child: Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
