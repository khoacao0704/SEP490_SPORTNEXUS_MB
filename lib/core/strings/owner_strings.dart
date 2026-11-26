import '../../models/owner_booking.dart';
import '../utils/formatters.dart';

/// Chuỗi hiển thị cho giao diện Chủ sân. Phần vận hành (đơn, lịch, check-in) lấy đúng câu chữ của Web.
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
  static const String noFacility = 'Bạn chưa có cơ sở nào';
  static const String noFacilityHint =
      'Tạo cơ sở thể thao để bắt đầu nhận khách. Cơ sở mới cần Admin duyệt; hồ sơ xác minh chủ sân phải được duyệt trước.';

  // Tổng quan (đợt 5 làm lại theo Web)
  static String greeting(String name) => 'Xin chào, $name';
  static const String today = 'Hôm nay';
  static const String viewSchedule = 'Mở lịch đặt sân';

  static const String loadError = 'Không tải được dữ liệu. Kéo xuống để thử lại.';
  static const String retry = 'Thử lại';
  static const String loginRequired = 'Vui lòng đăng nhập lại.';
  static const String close = 'Đóng';

  // ---------------- Lịch đặt sân (lưới) ----------------
  static const String viewGrid = 'Lưới lịch';
  static const String viewList = 'Danh sách đơn';
  static String scheduleTitle(String date) => 'Lịch đặt sân ngày $date';
  static const String allSports = 'Tất cả môn';
  static const String gridLoading = 'Đang tải lịch đặt sân...';
  static const String gridError = 'Không thể tải lịch đặt sân';
  static const String gridEmpty = 'Chưa có ca sân nào trong ngày này';
  static const String gridEmptyHint = 'Vào quản lý cụm sân để sinh ca cho các sân con, hoặc chọn ngày khác.';
  static String gridScale(int total, int available, int locked) => '$total ca • $available trống • $locked khóa';
  static const String statOccupancy = 'Tỷ lệ lấp đầy trong ngày';
  static String statOccupancySub(int booked, int total) => '$booked/$total ca đã có khách';
  static const String statCheckedInGrid = 'Đã check-in & vào sân';
  static String statCheckedInValue(int n) => '$n ca';
  static String statWaitingSub(int n) => '$n ca đang chờ khách tới';
  static const String statRevenue = 'Doanh thu dự kiến trong ngày';
  static const String statRevenueSub = 'Tổng giá các ca đã có khách';
  static const String statCourts = 'Sân sẵn sàng phục vụ';
  static String statCourtsValue(int active, int total) => '$active/$total sân';
  static const String statCourtsSub = 'Sân con đang hoạt động';
  static const String courtSuspended = 'Tạm ngưng';
  static const String cellFree = '+ Trống';
  static const String cellPick = '+ Chọn';
  static const String cellPicked = 'Đã chọn';
  static const String cellMaintenance = 'Bảo trì';
  static const String cellPast = 'Đã qua';
  static const String cellCustomer = 'Khách hàng';
  static const String cellMatch = 'Trận đấu giải';
  static const String cellWalkIn = ' • Vãng lai';
  static const String legendCheckedIn = 'Đã check-in';
  static const String legendPaid = 'Đã thanh toán (Chờ vào sân)';
  static const String legendPending = 'Chờ góp tiền';
  static const String legendReserved = 'Giữ cho giải đấu';
  static const String legendMaintenance = 'Bảo trì / khóa';
  static const String legendFree = 'Còn trống (Bấm để nhận khách)';

  static String cellLabel(SlotCellState s) => switch (s) {
        SlotCellState.checkedIn => 'Đã vào sân',
        SlotCellState.paid => 'Đã thanh toán',
        SlotCellState.pending => 'Chờ góp tiền',
        SlotCellState.reserved => 'Giữ cho giải',
        SlotCellState.maintenance => cellMaintenance,
        SlotCellState.past => cellPast,
        SlotCellState.available => cellFree,
      };

  // Chọn nhiều ca / nhập giờ thủ công
  static const String multiMode = 'Chọn nhiều ca';
  static const String multiModeExit = 'Thoát chọn nhiều ca';
  static const String multiHint = 'Bấm vào các ô trống trên lưới để chọn ca (có thể khác giờ, khác sân).';
  static String multiPicked(int n, int total) => 'Đã chọn $n ca • Tổng ${Formatters.vnd(total)}';
  static const String clearPicks = 'Bỏ chọn';
  static String bookPicked(int n) => 'Đặt $n ca đã chọn';
  static const String manualRange = 'Nhập giờ thủ công';
  static const String manualCourt = 'Sân';
  static const String manualCourtHint = '— Chọn sân —';
  static const String manualFrom = 'Từ giờ';
  static const String manualTo = 'Đến giờ';
  static const String manualSubmit = 'Tìm ca & nhận khách';
  static String manualHelp(String date) =>
      'Ngày $date. Hệ thống ghép các ca trống liên tiếp của sân trong khoảng giờ này thành 1 đơn.';
  static const String rangeNoCourt = 'Vui lòng chọn sân.';
  static const String rangeNoTime = 'Vui lòng nhập giờ bắt đầu và giờ kết thúc.';
  static const String rangeOrder = 'Giờ kết thúc phải sau giờ bắt đầu.';
  static String rangeNone(String court, String from, String to) => '$court không có ca nào nằm trọn trong $from – $to.';
  static String rangeMisaligned(String first, String last) =>
      'Khoảng giờ phải khớp mốc ca của sân. Khoảng gần nhất có ca: $first – $last.';
  static String rangeGap(String from, String to) => 'Từ $from đến $to sân chưa có ca.';
  static String rangeTaken(String from, String to) => 'Ca $from – $to không còn trống.';

  // Khách vãng lai
  static const String walkInTitle = 'Đặt giữ chỗ nhanh (Khách vãng lai)';
  static String walkInMulti(int n, String date) => '$n ca ngày $date';
  static const String walkInTotal = 'Tổng cộng';
  static String walkInStart(String time, String date) => 'Bắt đầu: $time ngày $date';
  static String walkInPrice(int price) => 'Giá: ${Formatters.vnd(price)}/ca';
  static const String changePrice = 'Đổi giá';
  static const String newPriceHint = 'Giá mới của ca';
  static const String savePrice = 'Lưu giá';
  static const String cancelEdit = 'Hủy';
  static const String priceTooLow = 'Giá ca phải từ 1.000 Điểm trở lên.';
  static String priceChanged(String time, int price) => 'Đã đổi giá ca $time thành ${Formatters.vnd(price)}.';
  static const String walkInName = 'Tên khách hàng / đội bóng:';
  static const String walkInNameHint = 'VD: Anh Tuấn, FC Hoàng Gia...';
  static const String walkInNameRequired = 'Vui lòng nhập tên khách hàng / đội bóng.';
  static const String walkInPhone = 'Số điện thoại:';
  static const String walkInPhoneHint = '09xx xxx xxx';
  static const String walkInSlots = 'Số ca liên tiếp:';
  static const String walkInNote = 'Ghi chú tại quầy:';
  static const String walkInNoteHint = 'VD: Đã thu tiền mặt 100%';
  static const String walkInAutoCheckIn = 'Khách đã có mặt — check-in luôn';
  static const String lockSlot = 'Khóa ca';
  static const String walkInSubmit = 'Xác nhận giữ sân';
  static const String walkInSubmitting = 'Đang tạo đơn...';
  static String walkInDone(String name, String court, String time) => 'Đã nhận đặt sân cho "$name" tại $court lúc $time!';
  static String walkInDoneMulti(int n, String name) => 'Đã nhận đặt $n ca cho "$name"!';
  static const String slotLocked = 'Đã khóa ca để bảo trì.';
  static const String slotUnlocked = 'Đã mở lại ca cho khách đặt.';

  // Ca đang khóa / ca đã đặt
  static const String maintenanceTitle = 'Ca đang khóa / bảo trì';
  static String maintenanceBody(String court, String time, String date) =>
      '$court • $time ngày $date. Mở lại để người chơi có thể đặt ca này.';
  static const String unlockSlot = 'Mở lại ca';
  static const String slotPast = 'Ca đã qua giờ';
  static const String processing = 'Đang xử lý...';
  static String slotBookingTitle(String court) => 'Chi tiết đặt sân: $court';
  static String slotStatusLabel(SlotCellState s) => switch (s) {
        SlotCellState.checkedIn => 'ĐÃ CHECK-IN (ĐANG CHƠI)',
        SlotCellState.pending => 'ĐƠN CHIA TIỀN (CHỜ GÓP ĐỦ)',
        _ => 'ĐÃ THANH TOÁN (CHỜ CHECK-IN)',
      };
  static const String rowBooker = 'Người đặt:';
  static const String rowWalkInSuffix = ' (Khách vãng lai)';
  static const String rowPhone = 'Số điện thoại:';
  static const String rowTime = 'Khung giờ:';
  static const String rowPrice = 'Giá ca:';
  static const String rowCode = 'Mã đơn:';
  static const String manualCheckIn = 'Check-in thủ công';
  static const String checkingIn = 'Đang check-in...';
  static const String manualCheckInDone = '✅ Đã check-in cho đơn đặt sân!';
  static const String cancelSlotBooking = 'Hủy đặt sân';
  static const String checkedInNoCancel = 'Khách đã check-in — đơn không thể hủy.';
  static const String openBooking = 'Xem chi tiết đơn';

  // ---------------- Danh sách đơn ----------------
  static const String statusAll = 'Mọi trạng thái';
  static const Map<String, String> statusFilters = {
    '': statusAll,
    OwnerBookingStatus.pending: 'Chờ thanh toán',
    OwnerBookingStatus.paid: 'Đã thanh toán',
    OwnerBookingStatus.checkedIn: 'Đã check-in',
    OwnerBookingStatus.cancelled: 'Đã hủy',
  };
  static const String statCount = 'Số đơn';
  static const String statActiveRevenue = 'Doanh thu (đơn còn hiệu lực)';
  static const String statPaid = 'Đã thanh toán';
  static const String statChecked = 'Đã check-in';
  static const String statCancelled = 'Đã hủy';
  static const String dateFrom = 'Từ';
  static const String dateTo = 'đến';
  static const String searchHint = 'Tên hoặc SĐT khách';
  static const String search = 'Tìm';
  static const String listLoading = 'Đang tải đơn…';
  static const String listEmpty = 'Không có đơn nào trong khoảng này.';
  static String listCheckedIn(int done, int total) => '$done/$total đã vào';
  static const String walkInTag = ' • Vãng lai';
  static const String noShowBadge = 'Không đến (no-show)';
  static const String detail = 'Chi tiết';
  static const String prevPage = 'Trước';
  static const String nextPage = 'Sau';
  static String pageOf(int page, int total) => 'Trang $page / $total';
  static String until(String time) => 'đến $time';

  /// Nhãn badge trạng thái đơn (src/CourtOwner/shared.js của Web).
  static String bookingBadge(String status) => switch (status) {
        'PENDING' => 'Chờ xử lý',
        'PENDING_PAYMENT' => 'Chờ thanh toán',
        'CONFIRMED' => 'Đã xác nhận',
        'PAID' => 'Đã thanh toán',
        'CHECKED_IN' => 'Đã check-in',
        'COMPLETED' => 'Hoàn thành',
        'CANCELLED' => 'Đã hủy',
        'NO_SHOW' => 'Vắng mặt',
        'REFUNDED' => 'Đã hoàn tiền',
        'HELD' => 'Đang tạm giữ',
        'RELEASED' => 'Đã chuyển',
        '' => '—',
        _ => status,
      };

  // ---------------- Chi tiết đơn ----------------
  static const String detailTitle = 'Chi tiết đơn đặt sân';
  static const String walkInBadge = 'Khách vãng lai';
  static const String lfgBadge = 'Kèo ghép LFG';
  static const String detailBooker = 'Người đặt';
  static const String detailTotal = 'Tổng tiền';
  static const String detailPaid = 'Đã thanh toán';
  static const String detailPending = 'Còn chờ';
  static const String detailCreated = 'Tạo lúc';
  static const String detailNote = 'Ghi chú của khách';
  static String cancelledInfo(String at, String reason, int refund, int penalty) =>
      'Đã hủy lúc $at: $reason • Hoàn ${Formatters.vnd(refund)} • Phạt ${Formatters.vnd(penalty)}';
  static String playersTitle(bool lfg, int n) => '${lfg ? 'Người đặt sân' : 'Người chơi'} ($n)';
  static const String hostSuffix = ' • Chủ đơn';
  static const String inCourt = 'Đã vào sân';
  static const String notInCourt = 'Chưa vào';
  static String lfgTitle(int accepted, int checkedIn) =>
      'Người chơi kèo LFG ($accepted đã vào kèo • $checkedIn đã check-in)';
  static String lfgCancelled(String? reason) => 'Kèo đã hủy${reason == null ? '' : ': $reason'}';
  static String lfgSummary(int? total, int? remaining, int price) =>
      'Cần ${total ?? '—'} người • còn ${remaining ?? '—'} suất • ${Formatters.vnd(price)}/người';
  static String lfgExpected(int accepted) => 'Tổng dự kiến tại sân: ${1 + accepted} người (gồm chủ kèo)';
  static const String lfgEmpty = 'Chưa có người chơi nhận suất.';
  static const Map<String, String> lfgPlayerStatus = {
    'PENDING': 'Chờ duyệt',
    'ACCEPTED': 'Đã vào kèo',
    'REJECTED': 'Bị từ chối',
    'LEFT': 'Đã rời',
    'REMOVED': 'Bị loại',
    'CANCELLED': 'Đã hủy',
  };
  static const String endEarly = 'Kết thúc ca sớm';
  static const String endEarlyTitle = 'Kết thúc ca sớm';
  static const String endEarlyBody =
      'Kết thúc ca sớm? Mọi người chơi đang trong sân sẽ được check-out. Không hoàn tiền cho phần thời gian còn lại.';
  static const String endEarlyConfirm = 'Kết thúc ca';
  static const String endingEarly = 'Đang kết thúc…';
  static const String endEarlyDone = 'Đã kết thúc ca, check-out mọi người chơi.';
  static const String endEarlyFailed = 'Không kết thúc được ca.';

  // ---------------- Chủ sân hủy đơn ----------------
  static const String cancelBooking = 'Hủy đơn';
  static const String cancelBookingTitle = 'Cảnh báo hủy đơn đặt sân';
  static const String cancelPenaltyLabel = 'Tiền phạt dự kiến';
  static String cancelPenaltyValue(int percent) => '$percent% giá trị đơn';
  static const String cancelFairPlayLabel = 'Điểm uy tín (Fair Play)';
  static String cancelFairPlay(int points) => points > 0 ? '-$points điểm' : '0 điểm';
  static String cancelWarning(int percent, {required int fairPlay, required bool walkIn}) {
    if (walkIn || (percent == 0 && fairPlay == 0)) {
      return 'Đơn khách vãng lai trả tại quầy: không bị phạt tiền và không trừ uy tín.';
    }
    if (fairPlay > 0) return 'Nếu hủy đơn này, bạn sẽ bị phạt $percent% giá trị đơn và trừ uy tín.';
    return 'Nếu hủy đơn này, bạn sẽ bị phạt $percent% giá trị đơn (không trừ điểm uy tín vì hủy trước 48 giờ).';
  }

  static const String cancelPolicyNote =
      'Người đặt được hoàn 100% và nhận voucher 10%. Hủy dưới 48h phạt 20% + trừ 10 điểm Fair Play; '
      'từ 48h trở lên phạt 10%; đơn vãng lai tại quầy không phạt.';
  static const String cancelReasonLabel = 'Lý do hủy đơn:';
  static const String cancelReasonHint = 'Nhập lý do hủy đơn...';
  static const String cancelReasonRequired = 'Vui lòng nhập lý do hủy đơn.';
  static const String cancelLockSlot = 'Khóa ca này để bảo trì sau khi hủy';
  static const String cancelBack = 'Quay lại';
  static const String cancelConfirm = 'Xác nhận hủy đơn';
  static const String cancelConfirmPenalty = 'Chấp nhận phạt & Hủy đơn';
  static const String cancelling = 'Đang hủy...';
  static const String cancelFailed = 'Không thể hủy đơn đặt sân.';
  static String cancelledMessage(OwnerCancelResult r) => [
        'Đã hủy đơn. Người đặt được hoàn 100% và nhận voucher 10%.',
        if (r.penaltyAmount > 0) 'Tiền phạt đã trừ vào ví: ${Formatters.vnd(r.penaltyAmount)}.',
        if (r.fairPlayPenalty > 0) 'Trừ ${r.fairPlayPenalty} điểm Fair Play.',
      ].join(' ');

  // ---------------- Quét QR ----------------
  static const String scanTitle = 'Quét QR check-in';
  static const String scanHint = 'Đưa mã QR vé người chơi vào giữa khung hình';
  static const String manualTitle = 'Hoặc nhập mã vé / dùng máy quét cầm tay:';
  static const String manualHint = 'Mã QR trên vé của người chơi...';
  static const String lookup = 'Kiểm tra';
  static const String cameraError = 'Không mở được camera. Hãy nhập mã hoặc dùng máy quét cầm tay.';
  static const String scannedTitle = 'Đã đọc được mã vé';
  static String scannedBody(String facility) =>
      'Xác nhận check-in vé này tại $facility? Hệ thống sẽ kiểm tra vé đúng cơ sở, chưa bị hủy và chưa được điểm danh.';
  static const String confirmCheckIn = 'Xác nhận check-in';
  static const String scanSuccess = 'Check-in thành công';
  static const String scanSuccessDefault = 'Check-in thành công!';
  static const String scanFailed = 'Check-in thất bại';
  static const String compareFace = 'Đối chiếu ảnh với người cầm vé';
  static String scanCode(String code) => 'Mã: $code';
  static const String scanNext = 'Quét vé tiếp theo';
  static const Map<String, String> ticketTypes = {
    'BOOKING': 'Vé đặt sân',
    'LFG': 'Vé kèo ghép',
    'TOURNAMENT': 'Vé giải đấu',
  };
  static const String rowTicketType = 'Loại vé';
  static const String rowCustomer = 'Khách hàng';
  static const String rowCourt = 'Sân';
  static const String rowPlayTime = 'Giờ chơi';
  static const String rowAmount = 'Số tiền';
  static const String scanLog = 'Nhật ký quét trong phiên';
  static const String scanLogEmpty = 'Chưa quét vé nào trong phiên này.';
  static const String todayBookings = 'Đơn đặt sân hôm nay';
  static const String todayHint = 'Khách quên vé QR? Check-in thủ công ngay tại danh sách chờ.';
  static String tabWaiting(int n) => 'Chờ check-in ($n)';
  static String tabChecked(int n) => 'Đã check-in ($n)';
  static const String todayLoading = 'Đang tải danh sách đơn...';
  static const String todayNoWaiting = 'Không còn đơn nào chờ check-in hôm nay.';
  static const String todayNoChecked = 'Chưa có lượt check-in nào hôm nay.';
  static String todayInCourt(int done, int total) => '$done/$total đã vào sân';
  static const String walkInShort = ' (Vãng lai)';
  static String todayCheckedIn(String customer, String court) => 'Đã check-in cho $customer ($court).';

  // Tài khoản
  static const String accountTitle = 'Tài Khoản';
  static const String roleOwner = 'Chủ sân';
  static const String menuRevenue = 'Doanh thu & Ví';
  static const String menuReviews = 'Đánh giá của khách';
  static const String menuComplaints = 'Khiếu nại của khách';
  static const String menuPromotions = 'Quảng bá';
  static const String menuShop = 'Shop tại sân';
  static const String menuNotifications = 'Thông báo';
  static const String menuTournaments = 'Giải đấu của tôi';
  static const String menuListingFee = 'Phí duy trì hàng tháng';
}
