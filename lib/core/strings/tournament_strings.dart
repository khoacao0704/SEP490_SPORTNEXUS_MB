import '../utils/formatters.dart';

/// Chuỗi hiển thị cho giải đấu.
class TournamentStrings {
  TournamentStrings._();

  // Danh sách
  static const String title = 'Giải Đấu';
  static const String tabExplore = 'Khám phá';
  static const String tabMine = 'Giải của tôi';
  static const String allSports = 'Tất cả môn';
  static const String allStatuses = 'Mọi trạng thái';
  static const String emptyExplore = 'Chưa có giải đấu nào phù hợp';
  static const String emptyExploreHint = 'Thử đổi thành phố, môn hoặc trạng thái.';
  static const String emptyMine = 'Bạn chưa đăng ký giải nào';
  static const String emptyMineHint = 'Tìm một giải đang mở đăng ký ở tab Khám phá.';

  // Trạng thái
  static const String statusOpen = 'Đang mở đăng ký';
  static const String statusUpcoming = 'Sắp diễn ra';
  static const String statusOngoing = 'Đang diễn ra';
  static const String statusFinished = 'Đã kết thúc';
  static const String statusCancelled = 'BTC đã hủy giải';
  static const String full = 'Hết suất';

  // Thẻ giải
  static String entries(int count, int max) => '$count/$max suất';
  static String deadlineIn(String t) => 'Còn $t để đăng ký';
  static String dateRange(DateTime start, DateTime end) {
    final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    return sameDay
        ? Formatters.weekdayDayMonth(start)
        : '${Formatters.dayMonth(start)} – ${Formatters.dayMonth(end)}/${end.year}';
  }
  static String feePer(String unit) => 'LỆ PHÍ / $unit';
  static String totalPrize(int amount) => 'Tổng giải thưởng ${Formatters.vnd(amount)}';
  static const String registered = 'Đã đăng ký';
  static const String withdrawnTag = 'Đã rút';
  static const String champion = 'Vô địch';

  static String unit(bool isTeam, bool isPair) => isTeam ? 'ĐỘI' : (isPair ? 'ĐÔI' : 'NGƯỜI');

  // Chi tiết
  static const String detailTitle = 'Chi Tiết Giải';
  static const String tabOverview = 'Tổng quan';
  static const String tabSchedule = 'Lịch thi đấu';
  static const String tabBracket = 'Sơ đồ nhánh';
  static const String organizer = 'Ban tổ chức';
  static const String venue = 'Địa điểm';
  static const String time = 'Thời gian';
  static const String format = 'Thể thức';
  static String formatValue(String entryLabel, int min, int max) {
    if (min == max && min <= 2) return '$entryLabel • Loại trực tiếp';
    return '$entryLabel ${min == max ? '$min' : '$min–$max'} người • Loại trực tiếp';
  }
  static const String registrationDeadline = 'Hạn đăng ký';
  static const String entryFee = 'Lệ phí';
  static const String about = 'Giới thiệu';
  static const String prizes = 'Giải thưởng';
  static const String rules = 'Điều lệ';
  static const String feeRulesTitle = 'Lệ phí & hoàn tiền';
  static String feeRules(int fee, String unitLower) => [
        'Lệ phí ${Formatters.vnd(fee)} mỗi $unitLower, người đăng ký (đội trưởng) trả cho cả ${unitLower == 'người' ? 'suất' : unitLower}.',
        'Rút trước hạn chót đăng ký: hoàn 100% lệ phí.',
        'Rút sau hạn chót: không hoàn lệ phí, các trận còn lại bị xử thua.',
        'Ban tổ chức hủy giải: hoàn 100% lệ phí cho tất cả.',
      ].join('\n');
  static const String participantsLabel = 'Đã đăng ký';
  static String participantsTitle(int count, int max) => 'Danh sách đăng ký ($count/$max)';
  static const String noParticipants = 'Chưa có ai đăng ký.';
  static const String you = '(Bạn)';
  static const String captain = 'Đội trưởng';
  static const String yourEntry = 'Đơn đăng ký của bạn';
  static const String yourNextMatch = 'Trận tiếp theo của bạn';
  static const String eliminated = 'Bạn đã dừng bước ở giải này.';
  static String championBanner(String name) => '🏆 Vô địch: $name';

  // Lịch thi đấu & sơ đồ
  static const String notDrawnYet = 'Ban tổ chức sẽ bốc thăm và công bố lịch thi đấu sau khi hết hạn đăng ký.';
  static const String tbd = 'Chờ xác định';
  static const String bye = 'Miễn thi đấu';
  static const String vs = 'VS';
  static const String timeTbd = 'Chưa xếp giờ';
  static const String walkover = 'Xử thắng (đối thủ rút)';
  static String roundName(int round, int roundCount) {
    final remaining = roundCount - round + 1;
    if (remaining == 1) return 'Chung kết';
    if (remaining == 2) return 'Bán kết';
    if (remaining == 3) return 'Tứ kết';
    return 'Vòng 1/${1 << (remaining - 1)}';
  }

  // Nút / hành động
  static const String register = 'ĐĂNG KÝ THAM GIA';
  static const String registrationClosed = 'Đã hết hạn đăng ký';
  static const String withdraw = 'Rút khỏi giải';
  static const String onlyCaptainWithdraws = 'Chỉ đội trưởng mới rút đội khỏi giải được.';
  static const String confirmWithdrawTitle = 'Rút khỏi giải?';
  static String confirmWithdrawMessage(int fee, bool refundable) => refundable
      ? 'Còn trong hạn đăng ký nên bạn được hoàn 100% lệ phí (${Formatters.vnd(fee)}). Suất của bạn sẽ mở lại cho người khác.'
      : 'Đã qua hạn đăng ký nên lệ phí ${Formatters.vnd(fee)} sẽ không được hoàn, các trận còn lại bị xử thua.';
  static const String keep = 'Không';
  static String withdrawnMessage(int refund) => refund > 0
      ? 'Đã rút khỏi giải. ${Formatters.vnd(refund)} đã được hoàn vào ví.'
      : 'Đã rút khỏi giải. Lệ phí không được hoàn.';
  static const String simulateCancel = 'Giả lập BTC hủy giải';
  static const String cancelledByOrganizer = 'Ban tổ chức đã hủy giải. Lệ phí được hoàn 100% vào ví.';

  // Đăng ký
  static const String registerTitle = 'Đăng Ký Giải';
  static const String teamName = 'Tên đội';
  static const String teamNameHint = 'Vd: FC Sài Gòn';
  static const String teamNameRequired = 'Vui lòng nhập tên đội.';
  static const String playerInfo = 'Người chơi';
  static String membersTitle(int count, int min, int max) =>
      'Thành viên ($count/${min == max ? '$min' : '$min–$max'}, gồm cả bạn)';
  static const String partnerTitle = 'Đồng đội';
  static const String addMemberHint = 'Email hoặc số điện thoại';
  static const String addMember = 'Thêm';
  static const String memberNote = 'Thành viên phải có tài khoản SportNexus. Nhập email hoặc số điện thoại họ đã đăng ký.';
  static String needMembers(int more) => 'Cần thêm ít nhất $more thành viên.';
  static const String needPartner = 'Vui lòng thêm đồng đội.';
  static const String agreeRules = 'Tôi đã đọc và đồng ý điều lệ giải, quy định lệ phí & hoàn tiền.';
  static const String mustAgree = 'Vui lòng đồng ý điều lệ giải.';
  static const String paymentMethod = 'Phương thức thanh toán';
  static const String payWallet = 'Ví SportNexus';
  static String balance(int amount) => 'Số dư: ${Formatters.vnd(amount)}';
  static const String payVietQr = 'Chuyển khoản VietQR';
  static const String payVietQrHint = 'Quét mã bằng app ngân hàng';
  static const String insufficient = 'Số dư ví không đủ. Hãy chọn VietQR hoặc nạp thêm tiền.';
  static const String amountToPay = 'Lệ phí cần trả';
  static const String confirmPay = 'XÁC NHẬN ĐĂNG KÝ';
  static const String registerSuccess = 'Đăng ký thành công! Theo dõi lịch thi đấu trong mục Giải của tôi.';

  // Lỗi
  static const String loginRequired = 'Vui lòng đăng nhập để đăng ký giải.';
  static const String notFound = 'Không tìm thấy giải đấu.';
  static const String closed = 'Giải đã hết hạn đăng ký.';
  static const String noSlots = 'Giải đã hết suất.';
  static const String alreadyRegistered = 'Bạn đã đăng ký giải này rồi.';
  static String memberTaken(String name) => '$name đã có tên trong một đơn đăng ký khác của giải.';
  static const String playerNotFound = 'Không tìm thấy người chơi với email / số điện thoại này.';
  static const String notAPlayer = 'Tài khoản này không phải tài khoản người chơi.';
  static const String cannotAddSelf = 'Bạn đã có trong đội rồi.';
  static const String duplicateMember = 'Người này đã có trong danh sách.';
  static const String tooManyMembers = 'Đội đã đủ số thành viên tối đa.';
  static const String wrongMemberCount = 'Số thành viên không đúng quy định của giải.';
  static const String notRegistered = 'Bạn chưa đăng ký giải này.';
  static const String notCaptain = onlyCaptainWithdraws;
  static const String alreadyWithdrawn = 'Bạn đã rút khỏi giải này.';
  static const String alreadyStarted = 'Giải đã khai mạc, kết thúc hoặc bị hủy nên không thể rút.';
  static const String loadError = 'Không tải được dữ liệu giải đấu. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
