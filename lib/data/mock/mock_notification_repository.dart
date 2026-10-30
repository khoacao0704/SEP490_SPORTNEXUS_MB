import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/notification_strings.dart';
import '../../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'mock_auth_repository.dart';

/// Bản giả lập [NotificationRepository].
///
/// - Thông báo mẫu tính lùi từ mốc lần đầu chạy, riêng cho từng tài khoản demo
///   (tài khoản mới đăng ký thì hộp thư trống).
/// - Trạng thái đã đọc, đã xoá, cài đặt và thông báo giả lập lưu theo từng tài khoản.
class MockNotificationRepository implements NotificationRepository, SandboxNotificationSimulator {
  static const String keySeedAt = 'notification_seed_at';
  static String keyRead(String userId) => 'notifications_read_$userId';
  static String keyExtra(String userId) => 'notifications_extra_$userId';
  static String keyDeleted(String userId) => 'notifications_deleted_$userId';
  static String keyDisabled(String userId) => 'notifications_disabled_$userId';

  final Duration latency;
  final DateTime Function() _now;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<AppNotification> _incoming = StreamController<AppNotification>.broadcast();

  MockNotificationRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<AppNotification> get incoming => _incoming.stream;

  @override
  Future<NotificationPage> getPage({NotificationGroup? group, bool unreadOnly = false, int page = 1}) async {
    await _delay();
    final matching = (await _all())
        .where((n) => (group == null || n.group == group) && (!unreadOnly || !n.isRead))
        .toList();
    const size = NotificationRepository.pageSize;
    final start = (page - 1) * size;
    return NotificationPage(
      items: matching.skip(start).take(size).toList(),
      hasMore: matching.length > start + size,
    );
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    await _delay();
    return _all();
  }

  @override
  Future<int> getUnreadCount() async => (await getUnread()).total;

  @override
  Future<UnreadNotifications> getUnread() async {
    await _delay();
    final byGroup = <NotificationGroup, int>{};
    for (final n in (await _all()).where((n) => !n.isRead)) {
      byGroup[n.group] = (byGroup[n.group] ?? 0) + 1;
    }
    return UnreadNotifications(total: byGroup.values.fold(0, (a, b) => a + b), byGroup: byGroup);
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
  Future<void> markAllAsRead({NotificationGroup? group}) async {
    await _delay();
    final userId = await _currentUserId();
    final all = await _all();
    final read = await _readIds(userId)..addAll(all.where((n) => group == null || n.group == group).map((n) => n.id));
    await _saveReadIds(userId, read);
    _changes.add(null);
  }

  @override
  Future<void> delete(String notificationId) async {
    await _delay();
    final userId = await _currentUserId();
    await _saveDeleted(userId, await _deletedIds(userId)..add(notificationId));
    _changes.add(null);
  }

  @override
  Future<int> deleteRead() async {
    await _delay();
    final userId = await _currentUserId();
    final readIds = (await _all()).where((n) => n.isRead).map((n) => n.id).toList();
    await _saveDeleted(userId, await _deletedIds(userId)..addAll(readIds));
    _changes.add(null);
    return readIds.length;
  }

  @override
  Future<Set<NotificationGroup>> getDisabledGroups() async {
    await _delay();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(keyDisabled(await _currentUserId())) ?? const [];
    return saved.map(NotificationGroup.fromApi).where((g) => !g.mandatory).toSet();
  }

  @override
  Future<void> setDisabledGroups(Set<NotificationGroup> disabled) async {
    await _delay();
    if (disabled.any((g) => g.mandatory)) throw const NotificationException(NotificationStrings.mandatoryGroup);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyDisabled(await _currentUserId()), disabled.map((g) => g.apiValue).toList());
  }

  /// Thêm một thông báo mới (xoay vòng theo các mẫu) như thể BE vừa đẩy xuống.
  @override
  Future<AppNotification> simulateIncoming() async {
    final userId = await _currentUserId();
    final prefs = await SharedPreferences.getInstance();
    final extras = prefs.getStringList(keyExtra(userId)) ?? [];
    final templates = userId == MockAuthRepository.ownerId ? _ownerIncomingTemplates : _incomingTemplates;
    final template = templates[extras.length % templates.length];
    final notification = AppNotification(
      id: 'nt-sim-${_now().microsecondsSinceEpoch}',
      type: template.type,
      title: template.title,
      body: template.body,
      createdAt: _now(),
    );
    await prefs.setStringList(keyExtra(userId), [...extras, jsonEncode(notification.toJson())]);
    _incoming.add(notification);
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

  Future<Set<String>> _deletedIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(keyDeleted(userId)) ?? []).toSet();
  }

  Future<void> _saveDeleted(String userId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyDeleted(userId), ids.toList());
  }

  Future<List<AppNotification>> _all() async {
    final userId = await _currentUserId();
    final prefs = await SharedPreferences.getInstance();
    final read = await _readIds(userId);
    final deleted = await _deletedIds(userId);
    final extras = (prefs.getStringList(keyExtra(userId)) ?? [])
        .map((raw) => AppNotification.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .whereType<AppNotification>();
    return [...await _seedFor(userId), ...extras]
        .where((n) => !deleted.contains(n.id))
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
          n('nt-008', NotificationType.fairPlayChanged, 'Fair Play +3',
              'Bạn được đánh giá trung bình 4.3 sao sau trận Pickleball tại Thảo Điền. Điểm hiện tại: 93.', 5 * day, read: true),
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
              'Hoàn 150.000 đ do bạn hủy đặt sân trước 24 giờ.', 10 * day, read: true),
        ];
      case MockAuthRepository.ownerId:
        return [
          n('nt-201', NotificationType.newBooking, 'Có lượt đặt sân mới',
              'Nguyễn Minh Anh đặt Cầu Lông tại Sân Cầu Lông Thiên Triều hôm nay (cọc 1/4: 40.000 đ).', 15),
          n('nt-202', NotificationType.playerNoShow, 'Khách vắng mặt',
              'Lượt Bóng Đá • Sân 5 người tại Sân Bóng Hoa Lư quá 15 phút chưa check-in. '
                  'Tiền cọc 125.000 đ đã chuyển về ví của bạn.',
              40),
          n('nt-203', NotificationType.newFacilityReview, 'Đánh giá mới 2 sao',
              'Sân Cầu Lông Thiên Triều: "Đèn sân 3 bị chớp, mong sân sửa sớm."', 3 * 60),
          n('nt-204', NotificationType.listingFeeOverdue, 'Quá hạn phí duy trì',
              'Phí tháng trước chưa được thanh toán. Các cơ sở của bạn đang bị ẩn khỏi tìm kiếm cho tới khi trả phí.',
              6 * 60),
          n('nt-205', NotificationType.escrowReleased, 'Đã giải ngân',
              'Lượt Pickleball tại Sân Cầu Lông Thiên Triều đã check-out. 150.000 đ đã vào ví.', 4 * 60, read: true),
          n('nt-206', NotificationType.facilityRejected, 'Hồ sơ cơ sở bị từ chối',
              'Sân Cầu Lông Tân Bình: Ảnh giấy phép bị mờ và số giấy phép không khớp với ảnh.', 5 * day, read: true),
          n('nt-207', NotificationType.listingFeeIssued, 'Đã chốt phí duy trì',
              'Phí duy trì tháng trước đã được chốt (10% doanh thu). Hạn trả hết ngày 07.', 8 * day, read: true),
          n('nt-208', NotificationType.ownerWithdrawalApproved, 'Rút tiền thành công',
              'Lệnh rút 5.000.000 đ về Techcombank ****1234 đã được chuyển.', 10 * day, read: true),
          n('nt-209', NotificationType.lfgMatchConfirmed, 'Kèo LFG đã đủ người',
              'Kèo Cầu Lông đôi tại Sân Cầu Lông Thiên Triều đã đủ 4/4 người.', 12 * day, read: true),
        ];
      default:
        return [];
    }
  }

  static const List<({NotificationType type, String title, String body})> _ownerIncomingTemplates = [
    (
      type: NotificationType.newBooking,
      title: 'Có lượt đặt sân mới',
      body: 'Một khách vừa đặt Bóng Đá • Sân 7 người tại Sân Bóng Hoa Lư (thanh toán 100%).',
    ),
    (
      type: NotificationType.bookingCancelledByPlayer,
      title: 'Khách hủy đặt sân',
      body: 'Một lượt Cầu Lông tại Sân Cầu Lông Thiên Triều bị hủy trong 24 giờ. Bạn nhận 40.000 đ tiền phạt.',
    ),
    (
      type: NotificationType.facilityApproved,
      title: 'Cơ sở đã được duyệt',
      body: 'Pickleball Bình Thạnh đã được Admin duyệt. Hãy cài giá và khung giờ để bắt đầu nhận đặt sân.',
    ),
    (
      type: NotificationType.reviewReportResolved,
      title: 'Admin đã xử lý báo cáo',
      body: 'Đánh giá bạn báo cáo đã được ẩn vì vi phạm quy định.',
    ),
  ];

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
