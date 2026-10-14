import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/strings/notification_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notification/notification_tile.dart';
import '../fair_play/fair_play_screen.dart';
import '../lfg/lfg_screen.dart';
import '../main/main_navigation_screen.dart';
import '../review/pending_reviews_screen.dart';
import '../wallet/transaction_history_screen.dart';

/// Bộ lọc: `null` là tất cả, [_unreadFilter] là chưa đọc, còn lại lọc theo nhóm.
const Object _unreadFilter = 'unread';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _isLoading = true;
  String? _error;
  Object? _filter;
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await AppRepositories.notification.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = NotificationStrings.loadError;
      });
    }
  }

  List<AppNotification> get _filtered {
    final filter = _filter;
    if (filter == null) return _items;
    if (filter == _unreadFilter) return _items.where((n) => !n.isRead).toList();
    return _items.where((n) => n.type.category == filter).toList();
  }

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    try {
      await AppRepositories.notification.markAllAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(NotificationStrings.allMarkedRead)));
    } catch (_) {
      // Lần mở sau sẽ thử lại; không cần chặn người dùng.
    }
  }

  Future<void> _simulate() async {
    final repo = AppRepositories.notification;
    if (repo is SandboxNotificationSimulator) {
      await (repo as SandboxNotificationSimulator).simulateIncoming();
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      // Đánh dấu đã đọc ngay trên giao diện, không chờ mạng.
      setState(() => _items = [for (final item in _items) item.id == n.id ? item.copyWith(isRead: true) : item]);
      unawaited(AppRepositories.notification.markAsRead(n.id).catchError((_) {}));
    }

    Widget? page;
    switch (n.type.target) {
      case NotificationTarget.none:
        return;
      case NotificationTarget.myBookings:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
          (route) => false,
        );
        return;
      case NotificationTarget.myLfgMatches:
        page = const MyLfgMatchesScreen();
      case NotificationTarget.transactions:
        page = const TransactionHistoryScreen();
      case NotificationTarget.pendingReviews:
        page = const PendingReviewsScreen();
      case NotificationTarget.fairPlay:
        page = const FairPlayScreen();
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }

  static String _dayHeader(DateTime date, DateTime now) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return NotificationStrings.today;
    if (diff == 1) return NotificationStrings.yesterday;
    return '${Formatters.weekdayDayMonth(date)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isSandbox = AppRepositories.notification is SandboxNotificationSimulator;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          NotificationStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isSandbox)
            IconButton(
              tooltip: NotificationStrings.simulate,
              onPressed: _simulate,
              icon: const Icon(Icons.add_alert_outlined),
            ),
          IconButton(
            tooltip: NotificationStrings.markAllRead,
            onPressed: _unreadCount > 0 ? _markAllRead : null,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final unread = _unreadCount;
    final labels = <Object?, String>{
      null: NotificationStrings.filterAll,
      _unreadFilter: unread > 0 ? '${NotificationStrings.filterUnread} ($unread)' : NotificationStrings.filterUnread,
      for (final c in NotificationCategory.values) c: c.label,
    };
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: labels.entries.map((e) {
            final selected = _filter == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = e.key),
                selectedColor: AppColors.primaryGreen,
                backgroundColor: AppColors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textMain,
                ),
                side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(NotificationStrings.retry)),
          ],
        ),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.cardBorder),
            const SizedBox(height: 12),
            Text(
              _filter == _unreadFilter ? NotificationStrings.emptyUnread : NotificationStrings.empty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Danh sách phẳng: tiêu đề ngày xen giữa các thông báo.
    final now = DateTime.now();
    final rows = <Object>[];
    String? lastHeader;
    for (final n in items) {
      final header = _dayHeader(n.createdAt, now);
      if (header != lastHeader) {
        rows.add(header);
        lastHeader = header;
      }
      rows.add(n);
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                row,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            );
          }
          final n = row as AppNotification;
          return NotificationTile(notification: n, now: now, onTap: () => _open(n));
        },
      ),
    );
  }
}
