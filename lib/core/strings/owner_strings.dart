import '../../models/court_session.dart';
import '../utils/formatters.dart';

/// Chuỗi hiển thị cho giao diện Chủ sân.
class OwnerStrings {
  OwnerStrings._();

  // Điều hướng
  static const String navOverview = 'Tổng Quan';
  static const String navSchedule = 'Lịch Đặt';
  static const String navScan = 'Quét QR';
  static const String navFacilities = 'Cơ Sở';
  static const String navAccount = 'Tài Khoản';

  // Bộ chọn cơ sở
  static const String allFacilities = 'Tất cả cơ sở';
  static const String chooseFacility = 'Chọn cơ sở';

  // Tổng quan
  static String greeting(String name) => 'Xin chào, $name';
  static const String today = 'Hôm nay';
  static const String statSessions = 'Lượt sân';
  static const String statWaiting = 'Chờ check-in';
  static const String statPlaying = 'Đang chơi';
  static const String statDisbursed = 'Đã giải ngân';
  static const String needAction = 'Cần xử lý';
  static const String noAction = 'Không có lượt sân nào cần xử lý.';
  static const String nextUp = 'Sắp tới hôm nay';
  static const String noNextUp = 'Không còn lượt sân nào sắp tới hôm nay.';
  static const String viewSchedule = 'Xem lịch đặt';
  static const String revenueComingSoon = 'Báo cáo doanh thu chi tiết sẽ có ở mục Doanh thu & Ví.';

  // Lịch đặt
  static const String scheduleTitle = 'Lịch Đặt Sân';
  static const String emptyDay = 'Không có lượt sân nào trong ngày này';
  static const String loadError = 'Không tải được lịch đặt. Kéo xuống để thử lại.';
  static const String retry = 'Thử lại';

  // Trạng thái
  static const String statusUpcoming = 'Sắp tới';
  static const String statusWaiting = 'Chờ check-in';
  static const String statusPlaying = 'Đang chơi';
  static const String statusOverdue = 'Chờ check-out';
  static const String statusNoShow = 'Vắng mặt';
  static const String statusCompleted = 'Đã check-out';
  static const String statusCancelled = 'Đã hủy';

  // Thẻ / chi tiết lượt sân
  static const String kindBooking = 'Đặt sân';
  static const String kindLfg = 'Kèo LFG';
  static const String detailTitle = 'Chi Tiết Lượt Sân';
  static const String players = 'Người chơi';
  static String checkedInCount(int done, int total) => 'Đã check-in $done/$total';
  static const String noCourtYet = 'Chưa chỉ định sân';
  static String court(String name) => name;
  static const String booker = 'Người đặt';
  static const String host = 'Host';
  static const String checkedIn = 'Đã check-in';
  static String checkedInAt(String time) => 'Check-in $time';
  static const String absent = 'Vắng mặt';
  static const String notCheckedIn = 'Chưa check-in';
  static const String absentNote = 'Quá 15 phút sau giờ chơi chưa check-in: hệ thống tự ghi nhận vắng mặt và trừ Fair Play.';
  static String checkInWindow(String open, String close) => 'Check-in mở từ $open đến $close';

  // Tiền
  static const String money = 'Thanh toán';
  static const String totalPrice = 'Tiền sân';
  static const String paidViaApp = 'Đã trả qua app (giữ escrow)';
  static const String remainingToCollect = 'Bạn tự thu tại sân';
  static String disbursed(int amount) => 'Đã giải ngân ${Formatters.vnd(amount)}';

  // Check-in
  static const String checkIn = 'Check-in';
  static const String scanToCheckIn = 'Quét QR check-in';
  static const String chooseCourtTitle = 'Chỉ định sân con';
  static const String chooseCourtHint = 'Chọn sân con cho lượt này. Các người chơi khác của lượt sẽ vào cùng sân.';
  static const String noFreeCourt = 'Không còn sân con trống trong khung giờ này.';
  static const String confirmCheckIn = 'Xác nhận check-in';
  static String checkInSuccess(String name, String court) => 'Đã check-in $name • $court';
  static const String chooseCourtRequired = 'Hãy chọn sân con trước khi check-in.';
  static String courtBusy(String court) => '$court đang được dùng trong khung giờ này.';
  static const String alreadyCheckedIn = 'Người chơi này đã check-in.';
  static String checkInNotOpen(String time) => 'Chưa tới giờ check-in. Mở từ $time.';
  static String checkInClosed(String time) =>
      'Đã quá giờ check-in ($time). Hệ thống đã ghi nhận vắng mặt.';
  static const String sessionCancelled = 'Lượt sân này đã bị hủy.';
  static const String sessionCompleted = 'Lượt sân này đã check-out.';

  /// Câu báo cho lý do không check-in được.
  static String checkInBlocked(CourtSession s, CheckInBlock block) {
    switch (block) {
      case CheckInBlock.cancelled:
        return sessionCancelled;
      case CheckInBlock.completed:
        return sessionCompleted;
      case CheckInBlock.alreadyCheckedIn:
        return alreadyCheckedIn;
      case CheckInBlock.notOpen:
        return checkInNotOpen(Formatters.time(s.checkInOpensAt));
      case CheckInBlock.closed:
        return checkInClosed(Formatters.time(s.checkInClosesAt));
    }
  }

  // Check-out
  static const String checkOut = 'Check-out';
  static const String confirmCheckOutTitle = 'Check-out lượt sân?';
  static String confirmCheckOut({required int escrow, required int remaining, required bool isLfg}) =>
      '${isLfg ? 'Check-out cho tất cả người chơi trong kèo. ' : ''}'
      'Bấm check-out là xác nhận bạn đã nhận đủ tiền sân'
      '${remaining > 0 ? ' (gồm ${Formatters.vnd(remaining)} bạn tự thu tại sân)' : ''}. '
      'Hệ thống giải ngân ${Formatters.vnd(escrow)} đang giữ escrow cho bạn, không thu hoa hồng.';
  static String checkOutSuccess(int amount) => 'Đã check-out. Giải ngân ${Formatters.vnd(amount)}.';
  static const String checkOutNeedsCheckIn = 'Chưa có ai check-in nên chưa thể check-out.';
  static const String cancel = 'Để sau';
  static const String loginRequired = 'Vui lòng đăng nhập lại.';

  // Quét QR
  static const String scanTitle = 'Quét QR Check-in';
  static const String scanHint = 'Đưa mã QR của người chơi vào khung';
  static const String manualTitle = 'Hoặc nhập mã vé';
  static const String manualHint = 'VD: SPN-BK-XXXX';
  static const String lookup = 'Tra mã';
  static const String cameraError = 'Không mở được camera. Hãy cấp quyền camera hoặc nhập mã vé.';
  static const String ticketNotFound = 'Không tìm thấy vé hoặc vé không thuộc cơ sở của bạn.';
  static const String ticketTitle = 'Vé check-in';
  static const String viewSession = 'Xem lượt sân';

  // Tài khoản
  static const String accountTitle = 'Tài Khoản';
  static const String roleOwner = 'Chủ sân';
  static const String menuRevenue = 'Doanh thu & Ví';
  static const String menuReviews = 'Đánh giá từ người chơi';
  static const String menuNotifications = 'Thông báo';
  static const String menuTournaments = 'Giải đấu của tôi';
  static const String menuListingFee = 'Phí duy trì hàng tháng';
}
