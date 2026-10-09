import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

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
                    'EXPLORE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerItem(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    isSelected: false,
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.calendar_month_outlined,
                    title: 'Find sessions',
                    isSelected: true,
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.location_on_outlined,
                    title: 'Find venues',
                    isSelected: false,
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.groups_outlined,
                    title: 'Find groups',
                    isSelected: false,
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.emoji_events_outlined,
                    title: 'Find tournaments',
                    isSelected: false,
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.school_outlined,
                    title: 'Find classes',
                    isSelected: false,
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: 'Help',
                    isSelected: false,
                  ),
                  const SizedBox(height: 32),
                  // Sign In Button
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sign Up Button
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Sign up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
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
                    'EN',
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
    required IconData icon,
    required String title,
    required bool isSelected,
  }) {
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primaryGreen : AppColors.textMain,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primaryGreen : AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          // Handle navigation here
        },
      ),
    );
  }
}
