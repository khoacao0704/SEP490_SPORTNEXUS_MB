import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';

IconData notificationIcon(NotificationGroup group) {
  switch (group) {
    case NotificationGroup.booking:
      return Icons.event_available_outlined;
    case NotificationGroup.lfg:
      return Icons.groups_outlined;
    case NotificationGroup.wallet:
      return Icons.account_balance_wallet_outlined;
    case NotificationGroup.review:
      return Icons.shield_outlined;
    case NotificationGroup.team:
      return Icons.diversity_3_outlined;
    case NotificationGroup.tournament:
      return Icons.emoji_events_outlined;
    case NotificationGroup.community:
      return Icons.forum_outlined;
    case NotificationGroup.report:
      return Icons.flag_outlined;
    case NotificationGroup.system:
      return Icons.campaign_outlined;
  }
}

({Color bg, Color fg}) notificationColors(NotificationGroup group) {
  switch (group) {
    case NotificationGroup.booking:
    case NotificationGroup.lfg:
      return (bg: AppColors.lightGreen, fg: AppColors.primaryGreen);
    case NotificationGroup.wallet:
      return (bg: AppColors.tagPurpleBg, fg: AppColors.tagPurpleText);
    case NotificationGroup.review:
    case NotificationGroup.report:
      return (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText);
    case NotificationGroup.team:
    case NotificationGroup.tournament:
    case NotificationGroup.community:
    case NotificationGroup.system:
      return (bg: const Color(0xFFE3F2FD), fg: const Color(0xFF1565C0));
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  const NotificationTile({super.key, required this.notification, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final colors = notificationColors(n.group);
    return Material(
      color: n.isRead ? AppColors.white : const Color(0xFFF1FAF4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.bg,
                child: Icon(notificationIcon(n.group), size: 20, color: colors.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.timeAgo(n.createdAt, now),
                      style: TextStyle(
                        fontSize: 11,
                        color: n.isRead ? AppColors.textSecondary : AppColors.primaryGreen,
                        fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  key: const ValueKey('unread-dot'),
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
