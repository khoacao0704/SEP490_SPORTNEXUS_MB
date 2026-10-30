import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/strings/notification_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../models/booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notification/notification_tile.dart';
import '../booking/split_booking_screen.dart';
import '../fair_play/fair_play_screen.dart';
import '../lfg/lfg_match_detail_screen.dart';
import '../lfg/lfg_screen.dart';
import '../main/main_navigation_screen.dart';
import '../review/pending_reviews_screen.dart';
import '../team/my_teams_screen.dart';
import '../team/team_detail_screen.dart';
import '../tournament/tournament_detail_screen.dart';
import '../wallet/transaction_history_screen.dart';
import 'notification_settings_screen.dart';

/// Bộ lọc: `null` là tất cả, [_unreadFilter] là chưa đọc, còn lại là [NotificationGroup]
/// (người chơi, lọc trên server) hoặc [NotificationCategory] (Chủ sân, lọc trên các trang đã tải).
const Object _unreadFilter = 'unread';

/// Mở màn liên quan khi bấm thông báo (Chủ sân điều hướng khác người chơi).
typedef NotificationOpener = Future<void> Function(BuildContext context, AppNotification notification);

enum _MenuAction { deleteRead, settings }

class NotificationsScreen extends StatefulWidget {
  /// Nhóm lọc cũ (Chủ sân). Bỏ trống = lọc theo nhóm của BE.
  final List<NotificationCategory>? categories;

  /// Bỏ trống = điều hướng của người chơi.
  final NotificationOpener? onOpen;

  const NotificationsScreen({super.key, this.categories, this.onOpen});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scroll = ScrollController();
  List<AppNotification> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  Object? _filter;
  UnreadNotifications _unread = const UnreadNotifications(total: 0);

  /// Nhóm đã thấy có dữ liệu: chỉ những nhóm này hiện trên thanh lọc.
  final Set<NotificationGroup> _seenGroups = {};

  /// Lượt tải mới nhất; kết quả của lượt cũ (đổi bộ lọc giữa chừng) bị bỏ.
  int _loadToken = 0;
  StreamSubscription<void>? _changesSub;
  StreamSubscription<AppNotification>? _incomingSub;

  NotificationRepository get _repo => AppRepositories.notification;

  bool get _legacyFilter => widget.categories != null;

  @override
  void initState() {
    super.initState();
    _changesSub = _repo.changes.listen((_) => _loadUnread());
    _incomingSub = _repo.incoming.listen(_onIncoming);
    _scroll.addListener(_onScroll);
    _load();
    _loadUnread();
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _incomingSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------- Tải dữ liệu ----------------

  NotificationGroup? get _serverGroup {
    final filter = _filter;
    return filter is NotificationGroup ? filter : null;
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _repo.getPage(group: _serverGroup, unreadOnly: _filter == _unreadFilter);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _items = page.items;
        _page = 1;
        _hasMore = page.hasMore;
        _isLoading = false;
        _seenGroups.addAll(page.items.map((n) => n.group));
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _error = NotificationStrings.loadError;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    final token = _loadToken;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repo.getPage(group: _serverGroup, unreadOnly: _filter == _unreadFilter, page: _page + 1);
      if (!mounted || token != _loadToken) return;
      final known = _items.map((n) => n.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((n) => !known.contains(n.id))];
        _page++;
        _hasMore = page.hasMore;
        _seenGroups.addAll(page.items.map((n) => n.group));
      });
    } catch (_) {
      // Cuộn tới cuối lần nữa sẽ thử lại.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadUnread() async {
    try {
      final unread = await _repo.getUnread();
      if (!mounted) return;
      setState(() {
        _unread = unread;
        _seenGroups.addAll(unread.byGroup.keys);
      });
    } catch (_) {
      // Chỉ ảnh hưởng số trên bộ lọc.
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) _loadMore();
  }

  void _onIncoming(AppNotification n) {
    if (!mounted || _items.any((item) => item.id == n.id)) return;
    final filter = _filter;
    final matches = filter == null ||
        filter == _unreadFilter ||
        (filter is NotificationGroup && n.group == filter) ||
        (filter is NotificationCategory && n.type.category == filter);
    setState(() {
      _seenGroups.add(n.group);
      if (matches) _items = [n, ..._items];
    });
  }

  void _setFilter(Object? filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    // Bộ lọc cũ của Chủ sân lọc ngay trên danh sách đã tải.
    if (!(_legacyFilter && filter is NotificationCategory)) _load();
  }

  List<AppNotification> get _visible {
    final filter = _filter;
    if (filter is NotificationCategory) return _items.where((n) => n.type.category == filter).toList();
    return _items;
  }

  // ---------------- Thao tác ----------------

  Future<void> _markAllRead() async {
    final group = _serverGroup;
    try {
      await _repo.markAllAsRead(group: group);
      if (!mounted) return;
      setState(() {
        _items = [for (final n in _items) group == null || n.group == group ? n.copyWith(isRead: true) : n];
        if (_filter == _unreadFilter) _items = [];
      });
      _loadUnread();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(NotificationStrings.allMarkedRead)));
    } catch (_) {
      // Lần mở sau sẽ thử lại; không cần chặn người dùng.
    }
  }

  Future<bool> _delete(AppNotification n) async {
    try {
      await _repo.delete(n.id);
      if (!mounted) return true;
      setState(() => _items = _items.where((item) => item.id != n.id).toList());
      _loadUnread();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(NotificationStrings.deleted)));
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(NotificationStrings.deleteError)));
      }
      return false;
    }
  }

  Future<void> _deleteRead() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(NotificationStrings.deleteReadTitle),
        content: const Text(NotificationStrings.deleteReadMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(NotificationStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(NotificationStrings.deleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await _repo.deleteRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(NotificationStrings.deletedCount(count))));
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(NotificationStrings.deleteError)));
      }
    }
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.deleteRead:
        await _deleteRead();
      case _MenuAction.settings:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
    }
  }

  Future<void> _simulate() async {
    final repo = _repo;
    if (repo is SandboxNotificationSimulator) {
      await (repo as SandboxNotificationSimulator).simulateIncoming();
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      // Đánh dấu đã đọc ngay trên giao diện, không chờ mạng.
      setState(() => _items = [for (final item in _items) item.id == n.id ? item.copyWith(isRead: true) : item]);
      unawaited(_repo.markAsRead(n.id).then((_) => _loadUnread()).catchError((_) {}));
    }

    final custom = widget.onOpen;
    if (custom != null) {
      await custom(context, n);
      return;
    }
    await _openForPlayer(n);
  }

  Future<void> _openForPlayer(AppNotification n) async {
    final id = n.referenceId;
    Widget? page;
    switch (n.referenceType) {
      case NotificationReference.booking:
        await _openBooking(id!);
        return;
      case NotificationReference.lfgCard:
        page = LfgMatchDetailScreen(matchId: id!);
      case NotificationReference.wallet:
        page = const TransactionHistoryScreen();
      case NotificationReference.team:
        page = TeamDetailScreen(teamId: id!);
      case NotificationReference.teamInvitation:
        page = const MyTeamsScreen();
      case NotificationReference.tournament:
        page = TournamentDetailScreen(tournamentId: id!);
      case NotificationReference.facilityReview:
      case NotificationReference.facility:
      case NotificationReference.communityPost:
      case NotificationReference.report:
        // Chưa có màn tương ứng phía người chơi.
        return;
      case null:
        page = _legacyPage(n.type.target);
        if (page == null) return;
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }

  /// Đơn chia tiền mở màn góp tiền; đơn thường mở tab Lịch Đặt.
  Future<void> _openBooking(String bookingId) async {
    try {
      final booking = await AppRepositories.booking.getBooking(bookingId);
      if (!mounted) return;
      if (booking.paymentType == BookingPaymentType.split) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => SplitBookingScreen(bookingId: bookingId)));
        return;
      }
    } catch (_) {
      // Không tải được đơn: vẫn mở Lịch Đặt.
    }
    if (!mounted) return;
    _openMyBookings();
  }

  void _openMyBookings() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
      (route) => false,
    );
  }

  /// Thông báo không có đối tượng liên quan (Fair Play sau trận, dữ liệu giả lập).
  Widget? _legacyPage(NotificationTarget target) {
    switch (target) {
      case NotificationTarget.none:
      case NotificationTarget.ownerSchedule:
      case NotificationTarget.ownerFinance:
      case NotificationTarget.ownerListingFee:
      case NotificationTarget.ownerFacilities:
      case NotificationTarget.ownerReviews:
        return null;
      case NotificationTarget.myBookings:
        _openMyBookings();
        return null;
      case NotificationTarget.myLfgMatches:
        return const MyLfgMatchesScreen();
      case NotificationTarget.transactions:
        return const TransactionHistoryScreen();
      case NotificationTarget.pendingReviews:
        return const PendingReviewsScreen();
      case NotificationTarget.fairPlay:
        return const FairPlayScreen();
    }
  }

  static String _dayHeader(DateTime date, DateTime now) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return NotificationStrings.today;
    if (diff == 1) return NotificationStrings.yesterday;
    return '${Formatters.weekdayDayMonth(date)}/${date.year}';
  }

  // ---------------- Giao diện ----------------

  @override
  Widget build(BuildContext context) {
    final isSandbox = _repo is SandboxNotificationSimulator;
    final group = _serverGroup;
    final canMarkAll = group == null ? _unread.total > 0 : (_unread.byGroup[group] ?? 0) > 0;
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
            onPressed: canMarkAll ? _markAllRead : null,
            icon: const Icon(Icons.done_all_rounded),
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: NotificationStrings.moreActions,
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: _MenuAction.deleteRead, child: Text(NotificationStrings.deleteRead)),
              PopupMenuItem(value: _MenuAction.settings, child: Text(NotificationStrings.settings)),
            ],
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
    final unread = _unread.total;
    final groups = NotificationGroup.values
        .where((g) => g == _filter || (g != NotificationGroup.community && _seenGroups.contains(g)));
    final labels = <Object?, String>{
      null: NotificationStrings.filterAll,
      _unreadFilter: unread > 0 ? '${NotificationStrings.filterUnread} ($unread)' : NotificationStrings.filterUnread,
      if (_legacyFilter)
        for (final c in widget.categories!) c: c.label
      else
        for (final g in groups) g: g.label,
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
                onSelected: (_) => _setFilter(e.key),
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

    final items = _visible;
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _refresh,
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
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2)),
            );
          }
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
          return Dismissible(
            key: ValueKey('notification-${n.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _delete(n),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            child: NotificationTile(notification: n, now: now, onTap: () => _open(n)),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), _loadUnread()]);
  }
}
