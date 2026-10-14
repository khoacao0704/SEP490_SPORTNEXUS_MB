import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'mock_auth_repository.dart';

/// Bản giả lập [NotificationRepository].
///
/// - Thông báo mẫu tính lùi từ mốc lần đầu chạy, riêng cho từng tài khoản demo
///   (tài khoản mới đăng ký thì hộp thư trống).
/// - Trạng thái đã đọc và thông báo giả lập lưu theo từng tài khoản.
class MockNotificationRepository implements NotificationRepository, SandboxNotificationSimulator {
  static const String keySeedAt = 'notification_seed_at';
  static String keyRead(String userId) => 'notifications_read_$userId';
  static String keyExtra(String userId) => 'notifications_extra_$userId';

  final Duration latency;
  final DateTime Function() _now;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  MockNotificationRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<AppNotification>> getNotifications() async {
    await _delay();
    return _all();
  }

  @override
  Future<int> getUnreadCount() async {
    await _delay();
    return (await _all()).where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _delay();
    final userId = await _currentUserId();
    final read = await _readIds(userId);
    if (read.add(notificationId)) {
      await _saveReadIds(userId, read);
      _changes.add(null);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    await _delay();
    final userId = await _currentUserId();
    final read = await _readIds(userId)..addAll((await _all()).map((n) => n.id));
    await _saveReadIds(userId, read);
    _changes.add(null);
  }

  /// Thêm một thông báo mới (xoay vòng theo các mẫu) như thể BE vừa đẩy xuống.
  @override
  Future<AppNotification> simulateIncoming() async {
    final userId = await _currentUserId();
    final prefs = await SharedPreferences.getInstance();
    final extras = prefs.getStringList(keyExtra(userId)) ?? [];
    final template = _incomingTemplates[extras.length % _incomingTemplates.length];
    final notification = AppNotification(
      id: 'nt-sim-${_now().microsecondsSinceEpoch}',
      type: template.type,
      title: template.title,
      body: template.body,
      createdAt: _now(),
    );
    await prefs.setStringList(keyExtra(userId), [...extras, jsonEncode(notification.toJson())]);
    _changes.add(null);
    return notification;
  }

  // ---------------- Dữ liệu giả ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<String> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) return 'guest';
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
  }

  Future<Set<String>> _readIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(keyRead(userId)) ?? []).toSet();
  }

  Future<void> _saveReadIds(String userId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyRead(userId), ids.toList());
  }

  Future<List<AppNotification>> _all() async {
    final userId = await _currentUserId();
    final prefs = await SharedPreferences.getInstance();
    final read = await _readIds(userId);
    final extras = (prefs.getStringList(keyExtra(userId)) ?? [])
        .map((raw) => AppNotification.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .whereType<AppNotification>();
    return [...await _seedFor(userId), ...extras]
        .map((n) => read.contains(n.id) ? n.copyWith(isRead: true) : n)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Mốc thời gian tạo dữ liệu giả lần đầu; thông báo mẫu tính lùi từ mốc này.
  Future<DateTime> _seedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keySeedAt);
    if (saved != null) return DateTime.parse(saved);
    final now = _now();
    await prefs.setString(keySeedAt, now.toIso8601String());
    return now;
  }

  Future<List<AppNotification>> _seedFor(String userId) async {
    final t = await _seedAt();
    AppNotification n(String id, NotificationType type, String title, String body, int minutesAgo,
            {bool read = false}) =>
        AppNotification(
          id: id,
          type: type,
          title: title,
          body: body,
          createdAt: t.subtract(Duration(minutes: minutesAgo)),
          isRead: read,
        );
    const day = 24 * 60;

    switch (userId) {
      case 'u-player-001':
        return [
          n('nt-001', NotificationType.matchReminder, 'Sắp tới giờ chơi',
              'Trận Pickleball tại Eco Sport Quận 7 bắt đầu sau 2 giờ nữa. Nhớ mở mã QR để check-in.', 20),
          n('nt-002', NotificationType.lfgPlayerJoined, 'Có người vào kèo của bạn',
              'Hoàng Nam vừa vào kèo Cầu Lông tại Sân Eco Quận 7 (3/4 người).', 75),
          n('nt-003', NotificationType.reviewReminder, 'Đánh giá buổi chơi',
              'Trận Cầu Lông tại Sân Cầu Lông Thiên Triều đã kết thúc. Bạn còn 24 giờ để đánh giá sân và người chơi.',
              170),
          n('nt-004', NotificationType.topUpSucceeded, 'Nạp tiền thành công',
              'Ví của bạn đã được cộng 200.000 đ qua VietQR.', day + 120, read: true),
          n('nt-005', NotificationType.bookingConfirmed, 'Đặt sân thành công',
              'Bạn đã đặt Pickleball Thảo Điền. Mã QR check-in có trong mục Lịch Đặt & QR.', day + 300, read: true),
          n('nt-006', NotificationType.withdrawalApproved, 'Rút tiền thành công',
              'Lệnh rút 300.000 đ về Vietcombank ****6789 đã được chuyển.', 2 * day, read: true),
          n('nt-007', NotificationType.lfgCancelled, 'Kèo đã bị hủy do không đủ người',
              'Kèo Bóng Đá tại Sân Bóng Hoa Lư chưa đủ người trước 48 giờ. Đã hoàn 100% tiền cọc 75.000 đ về ví.',
              3 * day, read: true),
          n('nt-008', NotificationType.fairPlayChanged, 'Fair Play +2',
              'Bạn được đánh giá tốt sau trận Pickleball tại Thảo Điền. Điểm hiện tại: 92.', 5 * day, read: true),
          n('nt-009', NotificationType.fairPlayChanged, 'Fair Play −10',
              'Bạn vắng mặt trận Cầu Lông tại Eco Sport Quận 7 và bị mất cọc.', 12 * day, read: true),
        ];
      case MockAuthRepository.restrictedPlayerId:
        return [
          n('nt-101', NotificationType.fairPlayChanged, 'Fair Play +5',
              'Điểm Fair Play đang hồi phục theo thời gian. Điểm hiện tại: 25.', day),
          n('nt-102', NotificationType.lfgRestriction, 'Tạm khóa ghép LFG',
              'Điểm Fair Play của bạn dưới 30 nên tạm thời không thể tạo kèo hoặc Flash Claim. '
                  'Bạn vẫn đặt sân bình thường.',
              8 * day),
          n('nt-103', NotificationType.refunded, 'Đã hoàn tiền',
              'Hoàn 150.000 đ do bạn hủy đặt sân trước 48 giờ.', 10 * day, read: true),
        ];
      default:
        return [];
    }
  }

  static const List<({NotificationType type, String title, String body})> _incomingTemplates = [
    (
      type: NotificationType.lfgFull,
      title: 'Kèo đã đủ người',
      body: 'Kèo Cầu Lông tại Sân Eco Quận 7 đã đủ 4/4 người. Hẹn gặp bạn ở sân!',
    ),
    (
      type: NotificationType.withdrawalRejected,
      title: 'Lệnh rút tiền bị từ chối',
      body: 'Thông tin tài khoản nhận không khớp. 300.000 đ đã được hoàn về ví.',
    ),
    (
      type: NotificationType.reviewReminder,
      title: 'Đánh giá buổi chơi',
      body: 'Chủ sân đã check-out trận của bạn. Đánh giá trong 24 giờ để giúp cộng đồng chơi đẹp hơn.',
    ),
    (
      type: NotificationType.bookingConfirmed,
      title: 'Đặt sân thành công',
      body: 'Đặt sân đã được xác nhận. Mã QR check-in có trong mục Lịch Đặt & QR.',
    ),
  ];
}
