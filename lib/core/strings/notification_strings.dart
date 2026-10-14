/// Chuỗi hiển thị cho trung tâm thông báo.
class NotificationStrings {
  NotificationStrings._();

  static const String title = 'Thông Báo';
  static const String bellTooltip = 'Thông báo';
  static const String markAllRead = 'Đánh dấu tất cả đã đọc';
  static const String allMarkedRead = 'Đã đánh dấu tất cả là đã đọc';
  static const String simulate = 'Giả lập thông báo mới';
  static const String filterAll = 'Tất cả';
  static const String filterUnread = 'Chưa đọc';
  static const String empty = 'Chưa có thông báo nào';
  static const String emptyUnread = 'Bạn đã đọc hết thông báo';
  static const String today = 'Hôm nay';
  static const String yesterday = 'Hôm qua';
  static const String loadError = 'Không tải được thông báo. Vui lòng thử lại.';
  static const String retry = 'Thử lại';

  static String badge(int n) => n > 99 ? '99+' : '$n';
}
