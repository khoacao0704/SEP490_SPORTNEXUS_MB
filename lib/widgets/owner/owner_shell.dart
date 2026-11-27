import 'package:flutter/material.dart';

import '../../core/strings/organizer_strings.dart';
import '../../theme/app_colors.dart';

/// Cho các tab của Chủ sân mở menu trái của khung chính (mỗi tab có Scaffold / AppBar riêng).
class OwnerShell extends InheritedWidget {
  final VoidCallback openDrawer;

  const OwnerShell({super.key, required this.openDrawer, required super.child});

  static OwnerShell? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<OwnerShell>();

  @override
  bool updateShouldNotify(OwnerShell oldWidget) => false;
}

/// Nút ☰ đặt ở `leading` AppBar của từng tab Chủ sân; ngoài khung chính (chưa có menu) thì không hiện gì.
class OwnerMenuButton extends StatelessWidget {
  const OwnerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = OwnerShell.maybeOf(context);
    if (shell == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      icon: const Icon(Icons.menu, color: AppColors.textMain),
      onPressed: shell.openDrawer,
    );
  }
}

/// Menu trái của Chủ sân: các chức năng chính không nằm ở thanh tab dưới (hiện có Giải đấu).
class OwnerDrawer extends StatelessWidget {
  final VoidCallback onOpenTournaments;

  const OwnerDrawer({super.key, required this.onOpenTournaments});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            const Text(
              OrganizerStrings.menuTitle,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: AppColors.primaryGreen),
              title: const Text(OrganizerStrings.ownerTitle, style: TextStyle(fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                onOpenTournaments();
              },
            ),
          ],
        ),
      ),
    );
  }
}
