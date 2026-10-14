import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/strings/notification_strings.dart';
import '../../data/app_repositories.dart';
import '../../screens/notification/notifications_screen.dart';
import '../../theme/app_colors.dart';

/// Nút chuông trên AppBar, kèm số thông báo chưa đọc; tự cập nhật khi có thay đổi.
class NotificationBell extends StatefulWidget {
  final Color color;

  const NotificationBell({super.key, this.color = AppColors.textMain});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppRepositories.notification.changes.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final count = await AppRepositories.notification.getUnreadCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {
      // Chuông vẫn dùng được, chỉ không hiện số.
    }
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: NotificationStrings.bellTooltip,
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        backgroundColor: Colors.red,
        label: Text(NotificationStrings.badge(_unread)),
        child: Icon(_unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded, color: widget.color),
      ),
    );
  }
}
