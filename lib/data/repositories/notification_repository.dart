import '../../models/app_notification.dart';

abstract class NotificationRepository {
  /// Thông báo của người dùng hiện tại, mới nhất trước.
  Future<List<AppNotification>> getNotifications();

  Future<int> getUnreadCount();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();

  /// Phát tín hiệu khi có thông báo mới hoặc trạng thái đã đọc thay đổi,
  /// để chuông và danh sách tự tải lại. Bản thật: nối với FCM/SignalR.
  Stream<void> get changes;
}

/// Chỉ bản giả lập cài đặt: dùng cho nút "Giả lập thông báo mới" khi demo.
abstract class SandboxNotificationSimulator {
  Future<AppNotification> simulateIncoming();
}
