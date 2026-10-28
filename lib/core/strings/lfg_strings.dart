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
  static const String allCourtTypes = 'Mọi loại sân';
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
  static const String statusConfirmed = 'Đã chốt • đủ người';
  static const String statusCancelledNotEnough = 'Đã hủy • không đủ người, hoàn 100%';
  static const String statusCancelledMutual = 'Đã hủy • cả kèo đồng ý, hoàn 100%';
  static const String statusCancelledEveryoneLeft = 'Đã hủy • mọi người đã rời kèo';
  static const String statusCancelled = 'Đã hủy';
  static String playersLabel(int n) => 'Ghép $n người';
  static const String statusPendingApproval = 'Chờ chủ kèo duyệt';
  static const String statusInvited = 'Bạn được mời';
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
  /// [hostPaysCourt]: chủ kèo trả trước cả tiền sân, người vào trả phần của mình cho chủ kèo (cách BE làm).
  /// [hostCanLeave]: host rời kèo thì quyền host chuyển cho người khác (bản giả lập); không thì host chỉ hủy kèo.
  /// [lateLeave]: sau T−48h người tham gia vẫn tự rời được nhưng không hoàn (cách BE làm).
  static String rules(int deposit, bool isTeam,
          {bool hostPaysCourt = false, bool hostCanLeave = true, bool lateLeave = false}) =>
      [
        'Mỗi ${isTeam ? 'đội' : 'người'} vào kèo trả ${Formatters.vnd(deposit)} (chia đều tiền sân).',
        if (isTeam) 'Team vs Team: người đại diện mỗi đội trả tiền, nhận hoàn tiền và chịu cộng/trừ Fair Play thay cả đội.',
        hostPaysCourt
            ? 'Host đã trả trước toàn bộ tiền sân. Tiền của người vào kèo được tạm giữ, chuyển cho host khi check-in hoặc sau giờ chơi.'
            : 'Tiền được giữ tới khi chủ sân check-out mới chuyển cho chủ sân.',
        'Kèo phải đủ người trước giờ chơi 48 giờ, nếu không sẽ tự hủy và hoàn 100% cho tất cả.',
        'Trước giờ chơi 48 giờ: ai rời cũng được hoàn 100%, chỗ mở lại cho người khác.'
            '${hostCanLeave ? ' Host rời thì quyền host chuyển cho người vào sớm nhất.' : ' Host không rời được, chỉ có thể hủy kèo (mọi người được hoàn 100%, host bị trừ 10 điểm Fair Play).'}',
        'Từ 48 giờ đến 24 giờ trước giờ chơi: muốn hủy kèo phải ${hostCanLeave ? '' : 'được host '}gửi yêu cầu và tất cả đồng ý; '
            'khi đó hoàn 100% và không ai bị trừ Fair Play.',
        if (lateLeave) ...[
          'Sau 48 giờ trước giờ chơi bạn vẫn tự rời được nhưng không được hoàn tiền (chuyển cho host), chỗ không mở lại.',
          'Rời trong 24 giờ trước giờ chơi còn bị trừ 10 điểm Fair Play.',
        ] else
          'Trong 24 giờ trước giờ chơi: không thể rời hay hủy kèo.',
        'Vắng mặt hoặc trễ quá 15 phút sẽ mất tiền và bị trừ 10 điểm Fair Play.',
      ].join('\n');
  static const String leave = 'Rời kèo';
  static const String cancelMatch = 'Hủy kèo';
  static const String confirmCancelTitle = 'Hủy kèo?';
  static const String confirmLeaveTitle = 'Rời kèo?';
  static String confirmLeaveMessage(int deposit, {bool isHost = false, String? nextHost}) =>
      'Bạn được hoàn 100% tiền cọc (${Formatters.vnd(deposit)}) và chỗ của bạn mở lại cho người khác.'
      '${!isHost ? '' : nextHost == null ? ' Bạn là người cuối cùng nên kèo sẽ bị hủy.' : ' Quyền host sẽ chuyển cho $nextHost.'}';
  static const String keep = 'Không';
  static String leftMessage(int refund) =>
      refund > 0 ? 'Đã rời kèo. ${Formatters.vnd(refund)} đã được hoàn vào ví.' : 'Đã rời kèo.';
  static String confirmLateLeaveMessage(int paid, {required bool fairPlayPenalty}) =>
      'Kèo đã chốt nên bạn không được hoàn ${Formatters.vnd(paid)} (chuyển cho chủ kèo) và chỗ của bạn không mở lại.'
      '${fairPlayPenalty ? ' Đã trong 24 giờ trước giờ chơi nên bạn còn bị trừ 10 điểm Fair Play.' : ''}';
  static const String lateLeaveNote =
      'Kèo đã chốt. Bạn vẫn rời được tới giờ chơi nhưng không được hoàn tiền; trong 24 giờ trước giờ chơi còn bị trừ 10 điểm Fair Play.';
  static const String reasonTitle = 'Lý do';
  static const String reasonHint = 'Nhập lý do';

  // Yêu cầu hủy kèo đã chốt
  static const String requestCancel = 'Yêu cầu hủy kèo';
  static const String confirmRequestTitle = 'Gửi yêu cầu hủy kèo?';
  static String confirmRequestMessage(int others, String deadline) =>
      'Kèo chỉ bị hủy khi cả $others người còn lại đồng ý trước $deadline. Khi đó mọi người được hoàn 100% '
      'và không ai bị trừ Fair Play. Chỉ cần 1 người từ chối thì yêu cầu bị bác và kèo vẫn diễn ra.';
  static const String sendRequest = 'Gửi yêu cầu';
  static const String requestSent = 'Đã gửi yêu cầu hủy. Chờ mọi người đồng ý.';
  static String cancelRequestBy(String name) => '$name đề nghị hủy kèo';
  static String approvalsCount(int approved, int total) => 'Đã đồng ý $approved/$total';
  static String cancelRequestDeadline(String t) => 'Hạn trả lời: $t. Chưa đủ tất cả đồng ý thì kèo vẫn diễn ra.';
  static const String approve = 'Đồng ý hủy';
  static const String reject = 'Từ chối';
  static const String approved = 'Đã đồng ý';
  static const String notAnswered = 'Chưa trả lời';
  static const String waitingOthers = 'Bạn đã đồng ý. Đang chờ những người còn lại.';
  static const String rejectedMessage = 'Bạn đã từ chối. Kèo vẫn diễn ra.';
  static const String mutualCancelledMessage = 'Tất cả đã đồng ý, kèo đã hủy. Mọi người được hoàn 100%.';
  static const String confirmedNote =
      'Đã qua hạn tự rời kèo (48 giờ trước giờ chơi). Muốn hủy, hãy gửi yêu cầu – cần tất cả đồng ý trước giờ chơi 24 giờ.';
  static const String leaveTooLate = 'Đã qua hạn tự rời kèo (48 giờ trước giờ chơi). Hãy gửi yêu cầu hủy kèo.';
  static String hostCancelMessage(int courtPrice) =>
      'Mọi người trong kèo được hoàn 100%, tiền sân ${Formatters.vnd(courtPrice)} của bạn cũng được hoàn đủ. '
      'Bạn sẽ bị trừ 10 điểm Fair Play vì hủy kèo.';
  static const String hostCancelledMessage = 'Đã hủy kèo. Mọi người đã được hoàn tiền.';
  static const String withdrawRequest = 'Rút yêu cầu';
  static const String pendingApprovalNote = 'Bạn đã xin vào kèo. Chủ kèo duyệt thì mới trừ tiền và có vé.';
  static const String withdrawnMessage = 'Đã rút yêu cầu tham gia.';
  static const String invitedNote = 'Bạn được mời vào kèo này. Chấp nhận thì trả phần của mình và nhận vé QR.';
  static String acceptInvite(int amount) => 'Chấp nhận • ${Formatters.vnd(amount)}';
  static const String declineInvite = 'Từ chối';
  static const String declinedMessage = 'Đã từ chối lời mời.';
  static const String tooLateNote =
      'Đã vào 24 giờ trước giờ chơi nên kèo không thể hủy. Vắng mặt hoặc trễ quá 15 phút sẽ mất cọc và bị trừ 10 điểm Fair Play.';
  static const String simulateApprove = 'Giả lập: mọi người đồng ý';
  static const String simulateReject = 'Giả lập: có người từ chối';
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
  static const String stepTeamSize = 'Số người mỗi đội (loại sân)';
  static const String teamRepresentativeNote =
      'Bạn là người đại diện đội: cọc, hoàn tiền và cộng/trừ Fair Play của cả đội đều tính cho bạn.';
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
  static const String continueToPayCourt = 'TIẾP TỤC THANH TOÁN TIỀN SÂN';
  static String hostPaysCourtExplain(int courtPrice, int perPerson) =>
      'Bạn trả trước toàn bộ tiền sân ${Formatters.vnd(courtPrice)}. Mỗi người vào kèo trả lại cho bạn '
      '${Formatters.vnd(perPerson)} khi check-in hoặc sau giờ chơi.';
  static const String amountToPayCourt = 'Tiền sân cần trả';
  static const String hostPaysCourtNote =
      'Bạn trả trước toàn bộ tiền sân; mỗi người vào kèo trả lại phần chia đều cho bạn khi check-in hoặc sau giờ chơi.';

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
  static const String cannotLeaveConfirmed = 'Kèo đã đủ người nên không thể rời. Hãy gửi yêu cầu hủy kèo.';
  static const String cancelOnlyConfirmed = 'Kèo chưa đủ người: bạn có thể rời kèo và được hoàn 100%.';
  static const String tooLateToCancel = 'Đã quá hạn hủy kèo (24 giờ trước giờ chơi).';
  static const String cancelRequestExists = 'Kèo đang có một yêu cầu hủy chờ trả lời.';
  static const String noCancelRequest = 'Yêu cầu hủy không còn hiệu lực.';
  static const String alreadyResponded = 'Bạn đã trả lời yêu cầu này rồi.';
  static const String notMember = 'Bạn không ở trong kèo này.';
  static const String alreadyEnded = 'Kèo đã kết thúc hoặc đã bị hủy.';
  static const String loadError = 'Không tải được dữ liệu kèo. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}

