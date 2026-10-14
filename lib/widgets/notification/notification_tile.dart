import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';

IconData notificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.bookingConfirmed:
      return Icons.event_available_outlined;
    case NotificationType.matchReminder:
      return Icons.alarm_outlined;
    case NotificationType.lfgPlayerJoined:
      return Icons.person_add_alt_1_outlined;
    case NotificationType.lfgFull:
      return Icons.groups_outlined;
    case NotificationType.lfgCancelled:
      return Icons.event_busy_outlined;
    case NotificationType.topUpSucceeded:
      return Icons.account_balance_wallet_outlined;
    case NotificationType.withdrawalApproved:
      return Icons.north_east_rounded;
    case NotificationType.withdrawalRejected:
      return Icons.money_off_outlined;
    case NotificationType.refunded:
      return Icons.undo_rounded;
    case NotificationType.reviewReminder:
      return Icons.rate_review_outlined;
    case NotificationType.fairPlayChanged:
      return Icons.shield_outlined;
    case NotificationType.lfgRestriction:
      return Icons.block_outlined;
  }
}

({Color bg, Color fg}) notificationColors(NotificationCategory category) {
  switch (category) {
    case NotificationCategory.booking:
      return (bg: AppColors.lightGreen, fg: AppColors.primaryGreen);
    case NotificationCategory.wallet:
      return (bg: AppColors.tagPurpleBg, fg: AppColors.tagPurpleText);
    case NotificationCategory.review:
      return (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText);
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
    final colors = notificationColors(n.type.category);
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
                child: Icon(notificationIcon(n.type), size: 20, color: colors.fg),
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
