import '../../models/lfg_match.dart' show LfgMemberStatus;
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
  // Gợi ý & bộ lọc mới
  static const String recommended = 'Gợi ý cho bạn';
  static const String recommendedEmpty = 'Chưa có kèo phù hợp với hồ sơ của bạn';
  static const String recommendedEmptyHint =
      'Gợi ý dựa trên môn, trình độ, lịch rảnh và khu vực trong Hồ sơ thể thao. Cập nhật hồ sơ hoặc xem Bảng tin.';
  static String matchScore(int score) => 'Phù hợp $score%';
  static const String filters = 'Bộ lọc';
  static String filtersCount(int n) => 'Bộ lọc ($n)';
  static const String filterSkill = 'Trình độ kèo';
  static const String filterMaxPrice = 'Giá mỗi người tối đa';
  static const String anySkill = 'Mọi trình độ';
  static const String noPriceLimit = 'Không giới hạn';
  static const String applyFilters = 'ÁP DỤNG';
  static const String clearFilters = 'Xoá bộ lọc';
  static String skillTag(String level) => 'Trình độ: $level';
  static const String stepSkill = 'Trình độ kèo (không bắt buộc)';
  static const String stepSlotCount = 'Số ca liên tiếp';
  static String slotCountNote(int max) => 'Chơi dài hơn: gộp tối đa $max ca liền nhau cùng sân (giá sân cộng dồn).';
  static String slotCountLimited(int n) => 'Sân này chỉ còn $n ca liền nhau từ giờ bạn chọn.';
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
  static const String unnamedMember = 'Người chơi đã vào kèo';
  static const String hostNote = 'Ghi chú của host';
  static const String courtPrice = 'Giá sân';
  static const String fillDeadline = 'Hạn đủ người';
  static const String yourTicket = 'Vé QR check-in của bạn';
  static const String ticketNote = 'Mỗi người có mã QR riêng. Xuất trình cho chủ sân khi check-in và check-out.';
  static const String rulesTitle = 'Quy định cọc & hủy';
  /// [hostPaysCourt]: chủ kèo trả trước cả giá sân, người vào trả phần của mình cho chủ kèo (cách BE làm).
  /// [hostCanLeave]: host rời kèo thì quyền host chuyển cho người khác (bản giả lập); không thì host chỉ hủy kèo.
  /// [lateLeave]: sau T−48h người tham gia vẫn tự rời được nhưng không hoàn (cách BE làm).
  static String rules(int deposit, bool isTeam,
          {bool hostPaysCourt = false, bool hostCanLeave = true, bool lateLeave = false}) =>
      [
        'Mỗi ${isTeam ? 'đội' : 'người'} vào kèo trả ${Formatters.vnd(deposit)} (chia đều giá sân).',
        if (isTeam) 'Team vs Team: người đại diện mỗi đội trả Điểm, nhận hoàn Điểm và chịu cộng/trừ Fair Play thay cả đội.',
        hostPaysCourt
            ? 'Host đã trả trước toàn bộ giá sân. Điểm của người vào kèo được tạm giữ; khi check-in hoặc sau giờ chơi, phần đó góp vào giá sân và host được hoàn lại đúng số đó.'
            : 'Điểm được giữ tới khi chủ sân check-out mới chuyển cho chủ sân.',
        'Kèo phải đủ người trước giờ chơi 48 giờ, nếu không sẽ tự hủy và hoàn 100% cho tất cả.',
        'Trước giờ chơi 48 giờ: ai rời cũng được hoàn 100%, chỗ mở lại cho người khác.'
            '${hostCanLeave ? ' Host rời thì quyền host chuyển cho người vào sớm nhất.' : ''}',
        if (!hostCanLeave) ...[
          'Host không rời được, chỉ hủy kèo. Hủy trước giờ chơi 48 giờ: mọi người được hoàn 100%, host bị trừ 10 điểm Fair Play.',
          'Host hủy dưới 48 giờ (hủy đơn phương): mọi người vẫn được hoàn 100%, host bị trừ 50% giá sân để bồi thường '
              'chia đều cho người đã vào kèo và bị trừ 20 điểm Fair Play.',
        ],
        if (lateLeave)
          'Từ 48 giờ trước giờ chơi trở đi bạn vẫn tự rời được nhưng không được hoàn Điểm (Điểm cọc chuyển cho chủ kèo '
              'để đền bù), chỗ không mở lại và bạn bị trừ 10 điểm Fair Play.'
        else
          'Sau 48 giờ trước giờ chơi: không tự rời được nữa.',
        'Vắng mặt hoặc trễ quá 15 phút sẽ mất Điểm và bị trừ 10 điểm Fair Play.',
      ].join('\n');
  static const String leave = 'Rời kèo';
  static const String cancelMatch = 'Hủy kèo';
  static const String confirmCancelTitle = 'Hủy kèo?';
  static const String confirmLeaveTitle = 'Rời kèo?';
  static String confirmLeaveMessage(int deposit, {bool isHost = false, String? nextHost}) =>
      'Bạn được hoàn 100% Điểm cọc (${Formatters.vnd(deposit)}) và chỗ của bạn mở lại cho người khác.'
      '${!isHost ? '' : nextHost == null ? ' Bạn là người cuối cùng nên kèo sẽ bị hủy.' : ' Quyền host sẽ chuyển cho $nextHost.'}';
  static const String keep = 'Không';
  static String leftMessage(int refund) =>
      refund > 0 ? 'Đã rời kèo. ${Formatters.vnd(refund)} đã được hoàn vào Ví điểm.' : 'Đã rời kèo.';
  // Rời kèo sát giờ (từ 48 giờ trước giờ chơi trở xuống) = bùng kèo: không hoàn, cọc đền bù cho chủ kèo, −10 Fair Play.
  static const String lateLeaveTitle = 'Cảnh báo rời kèo sát giờ';
  static const String lateLeaveWarning =
      'Bạn đang rời kèo sát giờ thi đấu. Bạn sẽ KHÔNG ĐƯỢC HOÀN ĐIỂM và bị trừ 10 điểm Fair Play.';
  static String confirmLateLeaveMessage(int paid) =>
      'Điểm cọc ${Formatters.vnd(paid)} của bạn sẽ chuyển cho chủ kèo để đền bù và chỗ của bạn không mở lại.';
  static const String lateLeaveConfirm = 'Vẫn rời kèo';
  static const String lateLeftMessage = 'Đã rời kèo. Điểm cọc đã chuyển cho chủ kèo và bạn bị trừ 10 điểm Fair Play.';
  static const String lateLeaveNote = 'Kèo đã chốt (dưới 48 giờ trước giờ chơi). Bạn vẫn rời được tới giờ chơi nhưng '
      'không được hoàn Điểm (chuyển cho chủ kèo) và bị trừ 10 điểm Fair Play.';
  static String lateLeaveFairPlayReason(String sport, String facility) =>
      'Rời kèo $sport • $facility trong 48 giờ trước giờ chơi';
  static const String reasonTitle = 'Lý do';
  static const String reasonHint = 'Nhập lý do';

  static const String leaveTooLate = 'Đã qua hạn tự rời kèo (48 giờ trước giờ chơi).';
  static String hostCancelMessage(int courtPrice) =>
      'Mọi người trong kèo được hoàn 100%, giá sân ${Formatters.vnd(courtPrice)} của bạn cũng được hoàn đủ. '
      'Bạn sẽ bị trừ 10 điểm Fair Play vì hủy kèo.';
  static const String hostCancelledMessage = 'Đã hủy kèo. Mọi người đã được hoàn Điểm.';

  // Chủ kèo hủy đơn phương (dưới 48h trước giờ chơi)
  static const String lateCancelTitle = 'Cảnh báo hủy kèo đơn phương';
  static const String lateCancelWarning = 'Bạn đang hủy kèo đơn phương dưới 48h. Bạn sẽ bị TRỪ 50% GIÁ SÂN để bồi '
      'thường cho người chơi khác và trừ 20 điểm FairPlay.';
  static const String lateCancelWarningNoJoiner = 'Bạn đang hủy kèo đơn phương dưới 48h. Kèo chưa có người vào nên '
      'bạn được hoàn đủ giá sân, nhưng vẫn bị trừ 20 điểm FairPlay.';
  static const String lateCancelLossLabel = 'Bạn mất';
  static String lateCancelLossDetail(int courtPrice) => '50% giá sân ${Formatters.vnd(courtPrice)}';
  static String lateCancelCompensation(int joiners) => 'Bồi thường mỗi người chơi ($joiners người)';
  static const String lateCancelFairPlayLabel = 'Fair Play';
  static const String lateCancelFairPlay = '−20 điểm';
  static const String lateCancelRefundNote = 'Người chơi trong kèo vẫn được hoàn 100% Điểm của họ.';
  static const String lateCancelConfirm = 'Đồng ý Hủy';
  static const String lateCancelBack = 'Quay lại';
  static String lateCancelledMessage(int loss) => loss > 0
      ? 'Đã hủy kèo. Bạn bị trừ ${Formatters.vnd(loss)} và 20 điểm Fair Play.'
      : 'Đã hủy kèo. Bạn bị trừ 20 điểm Fair Play.';
  static const String withdrawRequest = 'Rút yêu cầu';
  static const String pendingApprovalNote = 'Bạn đã xin vào kèo. Chủ kèo duyệt thì mới trừ Điểm và có vé.';
  static const String withdrawnMessage = 'Đã rút yêu cầu tham gia.';
  static const String invitedNote = 'Bạn được mời vào kèo này. Chấp nhận thì trả phần của mình và nhận vé QR.';
  static String acceptInvite(int amount) => 'Chấp nhận • ${Formatters.vnd(amount)}';
  static const String declineInvite = 'Từ chối';
  static const String declinedMessage = 'Đã từ chối lời mời.';
  static const String tooLateNote = 'Đã qua hạn tự rời kèo (48 giờ trước giờ chơi). '
      'Vắng mặt hoặc trễ quá 15 phút sẽ mất cọc và bị trừ 10 điểm Fair Play.';
  static const String simulateJoin = 'Giả lập có người vào kèo';

  // ---- Kèo cần duyệt người (B1) ----
  static const String approvalTitle = 'Chế độ duyệt người tham gia';
  static const String approvalOn =
      'BẬT: Người tham gia gửi yêu cầu, bạn có quyền Duyệt hoặc Từ chối. Điểm cọc của họ chỉ bị giữ khi bạn duyệt.';
  static const String approvalOff = 'TẮT: Người tham gia chọn suất là trừ Điểm và vào kèo ngay (kèo công khai trực tiếp).';
  static const String needsApproval = 'Cần duyệt người';
  static const String autoJoin = 'Tự động vào';
  static const String sendRequest = 'GỬI YÊU CẦU';
  static const String sendRequestLong = 'Gửi Yêu Cầu Vào Kèo';
  static const String requestDialogTitle = 'Kèo cần chủ kèo duyệt';
  static String requestDialogMessage(int deposit) =>
      'Bạn chỉ gửi yêu cầu tham gia tới chủ kèo, chưa bị trừ Điểm. Khi chủ kèo duyệt, '
      '${Formatters.vnd(deposit)} cọc sẽ được giữ từ Ví điểm của bạn và bạn có vé QR.';
  static const String requestSent = 'Đã gửi yêu cầu! Yêu cầu của bạn đã tới chủ kèo, Điểm cọc chỉ bị giữ khi chủ kèo duyệt.';
  static const String pendingSection = 'Chờ duyệt';
  static const String pastSection = 'Đã rời / bị loại / bị từ chối';
  static String pendingCountLabel(int n) => '$n người chờ duyệt';
  static const String approve = 'Duyệt';
  static const String reject = 'Từ chối';
  static const String remove = 'Loại';
  static String approvedMessage(String name) => 'Đã duyệt $name vào kèo. Điểm cọc của họ đã được tạm giữ.';
  static String rejectedMessage(String name) => 'Đã từ chối yêu cầu tham gia của $name.';
  static const String removeTitle = 'Loại khỏi kèo?';
  static String removeMessage(String name) =>
      'Xác nhận loại $name khỏi kèo? Hoàn 100% Điểm cho họ và mở lại 1 suất trống.';
  static String removedMessage(String name) =>
      'Đã loại $name khỏi kèo. Họ được hoàn 100% Điểm và kèo mở lại 1 suất trống.';
  static String memberStatus(LfgMemberStatus s) => switch (s) {
        LfgMemberStatus.accepted => 'Đã vào kèo',
        LfgMemberStatus.pending => 'Đang chờ duyệt',
        LfgMemberStatus.rejected => 'Bị từ chối',
        LfgMemberStatus.left => 'Đã rời kèo',
        LfgMemberStatus.removed => 'Bị chủ kèo loại',
        LfgMemberStatus.cancelled => 'Đã hủy',
      };
  static const String requestNotFound = 'Yêu cầu này không còn chờ duyệt.';
  static const String hostOnly = 'Chỉ chủ kèo mới làm được việc này.';

  // ---- Sửa kèo (B2) ----
  static const String editMatch = 'Sửa kèo';
  static const String editTitle = 'Chỉnh Sửa Kèo';
  static const String lockedInfo = 'Không đổi được sân, ca, thể thức và giá sau khi đã tạo kèo.';
  static const String stepSlotsNeeded = 'Số người cần tìm thêm (không tính bạn)';
  static String slotsNeededNote(int joined) =>
      joined == 0 ? 'Chưa có ai vào kèo.' : 'Đã có $joined người vào kèo nên không giảm thấp hơn số này.';
  static const String teamSlotsLocked = 'Kèo Đội vs Đội: không đổi được số người mỗi đội.';
  static const String saveEdit = 'LƯU THAY ĐỔI KÈO';
  static const String editSaved = 'Đã lưu thay đổi kèo.';
  static const String slotsBelowJoined = 'Số người cần tìm không được ít hơn số người đã vào kèo.';

  // Thanh toán cọc
  static const String paymentTitle = 'Thanh Toán Cọc';
  static String holdBanner(String t) => 'Đang giữ chỗ cho bạn • còn $t';
  static const String holdExpiredTitle = 'Hết thời gian giữ chỗ';
  static const String holdExpiredMessage = 'Chỗ đã được nhả cho người khác. Vui lòng thử lại.';
  static const String understood = 'Đã hiểu';
  static const String paymentMethod = 'Phương thức thanh toán';
  static const String payWallet = 'Đổi Điểm';
  static String balance(int amount) => 'Số dư: ${Formatters.vnd(amount)}';
  static const String payVietQr = 'Chuyển khoản VietQR';
  static const String payVietQrHint = 'Quét mã bằng app ngân hàng';
  static const String insufficient = 'Không đủ Điểm. Hãy chọn VietQR hoặc nạp thêm Điểm.';
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
      'Bạn là người đại diện đội: cọc, hoàn Điểm và cộng/trừ Fair Play của cả đội đều tính cho bạn.';
  static const String stepFacility = 'Chọn sân';
  static const String stepTime = 'Chọn khung giờ';
  static const String stepNote = 'Ghi chú (không bắt buộc)';
  static const String noteHint = 'Trình độ, yêu cầu trang phục, ...';
  static const String timeWindowNote =
      'Chỉ chọn được khung giờ bắt đầu sau 48 giờ và trong vòng 5 ngày tới, để kèo kịp đủ người trước hạn chốt.';
  static const String noFacilities = 'Không có sân nào cho môn này ở khu vực đã chọn.';
  static const String noSlots = 'Không còn khung giờ phù hợp trong ngày này.';
  static String depositExplain(String formatLabel, int slots, bool isTeam) =>
      '$formatLabel: giá sân chia đều $slots ${isTeam ? 'đội' : 'người'}, bạn cọc phần của mình.';
  static const String continueToPay = 'TIẾP TỤC THANH TOÁN CỌC';
  static const String continueToPayCourt = 'TIẾP TỤC THANH TOÁN GIÁ SÂN';
  static String hostPaysCourtExplain(int courtPrice, int perPerson) =>
      'Bạn trả trước toàn bộ giá sân ${Formatters.vnd(courtPrice)}. Mỗi người vào kèo trả lại cho bạn '
      '${Formatters.vnd(perPerson)} khi check-in hoặc sau giờ chơi.';
  static const String amountToPayCourt = 'Giá sân cần trả';
  static const String hostPaysCourtNote =
      'Bạn trả trước toàn bộ giá sân; mỗi người vào kèo trả lại phần chia đều cho bạn khi check-in hoặc sau giờ chơi.';

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
  static const String slotsNotConsecutive = 'Các ca của một kèo phải liên tiếp nhau trên cùng một sân.';
  static const String presetSlotUnavailable =
      'Ca được gợi ý không còn trống hoặc không nằm trong khung 48 giờ – 5 ngày tới. Vui lòng chọn ca khác.';
  static const String invalidFormat = 'Hình thức ghép không phù hợp với môn này.';
  static const String cannotLeaveConfirmed = 'Kèo đã đủ người nên không thể rời.';
  static const String notMember = 'Bạn không ở trong kèo này.';
  static const String alreadyEnded = 'Kèo đã kết thúc hoặc đã bị hủy.';
  static const String loadError = 'Không tải được dữ liệu kèo. Vui lòng thử lại.';
  static const String retry = 'Thử lại';

  // ---- Kèo Đội vs Đội ----
  static const String stepSideSize = 'Số người mỗi đội';
  static String sideSizeLabel(int n) => '${n}v$n';
  static const String pickTeamTitle = 'Chọn Đội đại diện thi đấu';
  static const String pickTeamHint = 'Chọn đội bạn làm đội trưởng';
  static String teamMembers(int n) => '$n thành viên';
  static String teamWrongSize(int need, int has) => 'Cần đúng $need người, đội đang có $has';
  static const String teamWrongSport = 'Đội thuộc môn khác';
  static const String teamLocked = 'Đội đang bị khóa';
  static const String noCaptainTeam = 'Bạn cần là đội trưởng của một đội đúng môn và đủ người để tạo / nhận kèo đội.';
  static const String openMyTeams = 'Mở Đội của tôi';
  static const String teamsLoadError = 'Không tải được danh sách đội.';
  static const String teamRequired = 'Chọn đội đại diện thi đấu';
  static String teamMatchNote(int side) =>
      'Kèo Đội vs Đội ${side}v$side: chỉ đội trưởng nhận kèo thay cả đội. Mỗi thành viên 2 đội (trừ chủ kèo) '
      'tự bị giữ phần Điểm của mình; ai thiếu Điểm thì cả đội chưa vào được.';
  static const String claimTeamTitle = 'Nhận kèo bằng đội';
  static const String claimTeamAction = 'Tiếp tục';
  static const String cancel = 'Hủy';
  static String teamVs(String a, String b) => '$a vs $b';
  static const String waitingTeam = 'Đang chờ đội nhận kèo';
  static const String sideA = 'Phe A';
  static const String sideB = 'Phe B';
}
