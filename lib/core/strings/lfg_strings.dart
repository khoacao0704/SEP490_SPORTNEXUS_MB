import '../utils/formatters.dart';

/// Chuỗi hiển thị cho ghép trận LFG.
class LfgStrings {
  LfgStrings._();

  // Bảng tin
  static const String title = 'Ghép Trận LFG';
  static const String tabFeed = 'Bảng tin';
  static const String tabMine = 'Kèo của tôi';
  static const String createButton = 'Tạo Kèo';
  static const String allSports = 'Tất cả';
  static const String allFormats = 'Mọi hình thức';
  static const String allDistricts = 'Tất cả quận';
  static const String chooseCity = 'Chọn thành phố';
  static const String chooseDistrict = 'Chọn quận / huyện';
  static const String emptyFeed = 'Chưa có kèo nào phù hợp';
  static const String emptyFeedHint = 'Thử đổi bộ lọc hoặc tự tạo kèo mới.';
  static const String emptyMine = 'Bạn chưa tham gia kèo nào';
  static const String noSuggestions = 'Hiện chưa có kèo nào đang thiếu người.';
  static const String emptyMineHint = 'Flash Claim một kèo trên bảng tin hoặc tạo kèo của riêng bạn.';

  // Thẻ kèo
  static String slotsFilled(int filled, int total, bool isTeam) => '$filled/$total ${isTeam ? 'đội' : 'người'}';
  static const String depositPerSlot = 'CỌC / CHỖ';
  static const String flashClaim = 'FLASH CLAIM';
  static const String joined = 'Đã tham gia';
  static const String yourMatch = 'Kèo của bạn';
  static const String host = 'Host';
  static String fairPlay(int score) => 'Fair Play $score';
  static String fillDeadlineIn(String t) => 'Còn $t để đủ người';
  static String duration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} ngày ${d.inHours % 24} giờ';
    if (d.inHours >= 1) return '${d.inHours} giờ ${d.inMinutes % 60} phút';
    return '${d.inMinutes} phút';
  }

  // Trạng thái
  static const String statusOpen = 'Đang tìm người';
  static const String statusFull = 'Đủ người • chờ chốt';
  static const String statusConfirmed = 'Đã chốt';
  static const String statusCancelledNotEnough = 'Đã hủy • không đủ người, hoàn 100%';
  static const String statusCancelledByHost = 'Host đã hủy kèo';
  static const String statusCompleted = 'Đã kết thúc';

  // Chi tiết kèo
  static const String detailTitle = 'Chi Tiết Kèo';
  static const String members = 'Thành viên';
  static const String emptySlot = 'Chỗ trống';
  static const String heldSlot = 'Đang có người giữ chỗ';
  static const String you = '(Bạn)';
  static const String hostNote = 'Ghi chú của host';
  static const String courtPrice = 'Tiền sân';
  static const String fillDeadline = 'Hạn đủ người';
  static const String yourTicket = 'Vé QR check-in của bạn';
  static const String ticketNote = 'Mỗi người có mã QR riêng. Xuất trình cho chủ sân khi check-in và check-out.';
  static const String rulesTitle = 'Quy định cọc & hủy';
  static String rules(int deposit, bool isTeam) => [
        'Mỗi ${isTeam ? 'đội' : 'người'} cọc ${Formatters.vnd(deposit)} (chia đều tiền sân).',
        'Tiền được giữ tới khi chủ sân check-out mới chuyển cho chủ sân.',
        'Kèo phải đủ người trước giờ chơi 48 giờ, nếu không sẽ tự hủy và hoàn 100% cho tất cả.',
        'Rời kèo hoặc host hủy kèo: người rời/host mất cọc. Host hủy thì người khác được hoàn 100%.',
        'Vắng mặt không check-in sẽ mất cọc và bị trừ điểm Fair Play.',
      ].join('\n');
  static const String leave = 'Rời kèo';
  static const String cancelMatch = 'Hủy kèo';
  static const String confirmLeaveTitle = 'Rời kèo?';
  static String confirmLeaveMessage(int deposit, bool reopens) =>
      'Bạn sẽ mất ${Formatters.vnd(deposit)} tiền cọc. '
      '${reopens ? 'Chỗ của bạn sẽ mở lại cho người khác.' : 'Kèo đã chốt nên chỗ của bạn sẽ để trống.'}';
  static const String confirmCancelTitle = 'Hủy kèo?';
  static String confirmCancelMessage(int deposit, int others) =>
      'Bạn sẽ mất ${Formatters.vnd(deposit)} tiền cọc'
      '${others > 0 ? ' và $others người đã tham gia sẽ được hoàn 100%' : ''}. Hủy kèo cũng có thể bị trừ điểm Fair Play.';
  static const String keep = 'Không';
  static String leftMessage(int deposit) => 'Bạn đã rời kèo. ${Formatters.vnd(deposit)} tiền cọc không được hoàn.';
  static const String cancelledMessage = 'Đã hủy kèo. Những người đã tham gia được hoàn 100%.';
  static const String simulateJoin = 'Giả lập có người vào kèo';

  // Thanh toán cọc
  static const String paymentTitle = 'Thanh Toán Cọc';
  static String holdBanner(String t) => 'Đang giữ chỗ cho bạn • còn $t';
  static const String holdExpiredTitle = 'Hết thời gian giữ chỗ';
  static const String holdExpiredMessage = 'Chỗ đã được nhả cho người khác. Vui lòng thử lại.';
  static const String understood = 'Đã hiểu';
  static const String paymentMethod = 'Phương thức thanh toán';
  static const String payWallet = 'Ví SportNexus';
  static String balance(int amount) => 'Số dư: ${Formatters.vnd(amount)}';
  static const String payVietQr = 'Chuyển khoản VietQR';
  static const String payVietQrHint = 'Quét mã bằng app ngân hàng';
  static const String insufficient = 'Số dư ví không đủ. Hãy chọn VietQR hoặc nạp thêm tiền.';
  static const String amountToPay = 'Cọc cần trả';
  static const String confirmPay = 'XÁC NHẬN THANH TOÁN';
  static const String joinSuccess = 'Bạn đã vào kèo! Vé QR có trong chi tiết kèo.';
  static const String createSuccess = 'Đã đăng kèo lên bảng tin!';

  // Tạo kèo
  static const String createTitle = 'Tạo Kèo Mới';
  static const String stepSport = 'Môn thể thao';
  static const String stepFormat = 'Hình thức ghép';
  static const String stepFacility = 'Chọn sân';
  static const String stepTime = 'Chọn khung giờ';
  static const String stepNote = 'Ghi chú (không bắt buộc)';
  static const String noteHint = 'Trình độ, yêu cầu trang phục, ...';
  static const String timeWindowNote =
      'Chỉ chọn được khung giờ bắt đầu sau 48 giờ và trong vòng 5 ngày tới, để kèo kịp đủ người trước hạn chốt.';
  static const String noFacilities = 'Không có sân nào cho môn này ở khu vực đã chọn.';
  static const String noSlots = 'Không còn khung giờ phù hợp trong ngày này.';
  static String depositExplain(String formatLabel, int slots, bool isTeam) =>
      '$formatLabel: tiền sân chia đều $slots ${isTeam ? 'đội' : 'người'}, bạn cọc phần của mình.';
  static const String continueToPay = 'TIẾP TỤC THANH TOÁN CỌC';

  // Lỗi
  static const String loginRequired = 'Vui lòng đăng nhập để ghép trận.';
  static const String notFound = 'Không tìm thấy kèo.';
  static const String alreadyJoined = 'Bạn đã ở trong kèo này rồi.';
  static const String full = 'Kèo vừa hết chỗ. Hãy thử kèo khác.';
  static const String closed = 'Kèo đã qua hạn chốt (48 giờ trước giờ chơi) hoặc không còn nhận người.';
  static const String claimExpired = 'Đã hết thời gian giữ chỗ. Vui lòng Flash Claim lại.';
  static const String blocked = 'Điểm Fair Play dưới 30, tạm thời không thể ghép LFG.';
  static const String createWindow = 'Khung giờ phải bắt đầu sau 48 giờ và trong vòng 5 ngày tới.';
  static const String singleSlotOnly = 'Mỗi kèo chỉ chọn một khung giờ.';
  static const String invalidFormat = 'Hình thức ghép không phù hợp với môn này.';
  static const String hostCannotLeave = 'Host không thể rời kèo. Hãy dùng "Hủy kèo".';
  static const String notHost = 'Chỉ host mới hủy được kèo.';
  static const String notMember = 'Bạn không ở trong kèo này.';
  static const String alreadyEnded = 'Kèo đã kết thúc hoặc đã bị hủy.';
  static const String loadError = 'Không tải được dữ liệu kèo. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}

