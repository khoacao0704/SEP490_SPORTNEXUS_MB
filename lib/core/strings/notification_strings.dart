import '../../models/app_notification.dart';

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
  static const String moreActions = 'Thêm';

  // Xoá
  static const String deleted = 'Đã xoá thông báo';
  static const String deleteError = 'Không xoá được thông báo. Vui lòng thử lại.';
  static const String deleteRead = 'Xoá thông báo đã đọc';
  static const String deleteReadTitle = 'Xoá thông báo đã đọc?';
  static const String deleteReadMessage = 'Mọi thông báo đã đọc sẽ bị xoá vĩnh viễn, không khôi phục được.';
  static const String deleteConfirm = 'Xoá';
  static const String cancel = 'Hủy';
  static String deletedCount(int n) => n == 0 ? 'Không có thông báo đã đọc nào để xoá' : 'Đã xoá $n thông báo';

  // Cài đặt
  static const String settings = 'Cài đặt thông báo';
  static const String settingsIntro =
      'Chọn loại thông báo bạn muốn nhận. Thông báo phát sinh trong lúc tắt sẽ không được gửi lại khi bật.';
  static const String mandatoryNote = 'Bắt buộc, không thể tắt';
  static const String mandatoryGroup = 'Không thể tắt nhóm thông báo bắt buộc';
  static const String settingsLoadError = 'Không tải được cài đặt thông báo. Vui lòng thử lại.';
  static const String settingsSaveError = 'Không lưu được cài đặt. Vui lòng thử lại.';

  static String badge(int n) => n > 99 ? '99+' : '$n';

  /// Mô tả từng nhóm trong màn cài đặt.
  static String groupDescription(NotificationGroup group) {
    switch (group) {
      case NotificationGroup.booking:
        return 'Đặt sân, chia tiền, hủy sân, nhắc giờ chơi';
      case NotificationGroup.lfg:
        return 'Có người vào kèo, kèo đủ người, kèo bị hủy, lời mời';
      case NotificationGroup.wallet:
        return 'Nạp tiền, rút tiền, hoàn tiền, chốt tiền kèo';
      case NotificationGroup.review:
        return 'Điểm Fair Play sau trận, kết quả kiểm duyệt đánh giá';
      case NotificationGroup.team:
        return 'Lời mời vào đội, thay đổi thành viên, chuyển đội trưởng';
      case NotificationGroup.tournament:
        return 'Đăng ký giải, đổi lịch, giải bắt đầu';
      case NotificationGroup.community:
        return 'Lượt thích, bình luận';
      case NotificationGroup.report:
        return 'Kết quả xử lý báo cáo';
      case NotificationGroup.system:
        return 'Thông báo từ hệ thống và Admin';
    }
  }
}
