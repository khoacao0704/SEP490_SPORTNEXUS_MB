import '../../models/app_notification.dart';

/// Lỗi thông báo; [message] sẵn sàng để hiển thị.
class NotificationException implements Exception {
  final String message;

  const NotificationException(this.message);

  @override
  String toString() => 'NotificationException: $message';
}

abstract class NotificationRepository {
  static const int pageSize = 20;

  /// Một trang thông báo, mới nhất trước. [group] = `null` là mọi nhóm.
  Future<NotificationPage> getPage({NotificationGroup? group, bool unreadOnly = false, int page = 1});

  /// Trang đầu của mọi nhóm (tiện cho chỗ không cần phân trang).
  Future<List<AppNotification>> getNotifications();

  Future<int> getUnreadCount();

  Future<UnreadNotifications> getUnread();

  Future<void> markAsRead(String notificationId);

  /// Đánh dấu đã đọc mọi thông báo, hoặc chỉ của [group].
  Future<void> markAllAsRead({NotificationGroup? group});

  /// Xoá vĩnh viễn (BE không có khôi phục).
  Future<void> delete(String notificationId);

  /// Xoá mọi thông báo đã đọc; trả về số đã xoá.
  Future<int> deleteRead();

  /// Nhóm đang tắt. Nhóm bắt buộc ([NotificationGroup.mandatory]) luôn bật.
  Future<Set<NotificationGroup>> getDisabledGroups();

  /// Ghi đè toàn bộ cài đặt: chỉ tắt các nhóm trong [disabled].
  Future<void> setDisabledGroups(Set<NotificationGroup> disabled);

  /// Có thể đã đổi số chưa đọc (thông báo mới, đọc, xoá) → chuông tải lại.
  Stream<void> get changes;

  /// Thông báo vừa tới (realtime) → màn danh sách chèn lên đầu.
  Stream<AppNotification> get incoming;
}

/// Chỉ bản giả lập cài đặt: dùng cho nút "Giả lập thông báo mới" khi demo.
abstract class SandboxNotificationSimulator {
  Future<AppNotification> simulateIncoming();
}
