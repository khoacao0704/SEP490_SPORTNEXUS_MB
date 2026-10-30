import '../../models/tournament_listing.dart';
import '../utils/formatters.dart';

/// Chuỗi hiển thị cho giải đấu phía người chơi (dữ liệu BE).
class PlayerTournamentStrings {
  PlayerTournamentStrings._();

  // Danh sách
  static const String title = 'Giải Đấu';
  static const String tabExplore = 'Khám phá';
  static const String tabMine = 'Đã đăng ký';
  static const String tabMatches = 'Lịch đấu';
  static const String searchHint = 'Tìm theo tên giải';
  static const String allSports = 'Tất cả môn';
  static const String registrationOpenOnly = 'Đang nhận đăng ký';
  static const String sortTooltip = 'Sắp xếp';
  static const String empty = 'Chưa có giải đấu nào phù hợp';
  static const String emptyHint = 'Thử đổi từ khoá, môn hoặc bộ lọc.';
  static const String emptyMine = 'Bạn chưa đăng ký giải nào';
  static const String emptyMatches = 'Chưa có trận đấu nào';
  static const String emptyMatchesHint = 'Lịch thi đấu hiện khi ban tổ chức bốc thăm và xếp lịch.';
  static const String promoted = 'Nổi bật';
  static const String registrationOpen = 'Đang nhận đăng ký';
  static String divisionCount(int n) => '$n nội dung';
  static const String myTeams = 'Đội của tôi';

  static String dateRange(DateTime? start, DateTime? end) {
    if (start == null) return 'Chưa có lịch';
    if (end == null || Formatters.dayMonth(start) == Formatters.dayMonth(end)) return _date(start);
    return '${Formatters.dayMonth(start)} – ${_date(end)}';
  }

  static String deadline(DateTime d) => 'Hạn đăng ký: ${Formatters.time(d)} ${_date(d)}';
  static String _date(DateTime d) => '${Formatters.dayMonth(d)}/${d.year}';

  // Chi tiết
  static const String divisions = 'Nội dung thi đấu';
  static const String prizes = 'Giải thưởng';
  static const String rules = 'Điều lệ';
  static const String sportRules = 'Luật thi đấu';
  static const String participants = 'Danh sách tham gia';
  static const String noParticipants = 'Chưa có ai đăng ký';
  static const String noDivisions = 'Giải chưa có nội dung đăng ký';
  static String prizePosition(int position) => position == 1 ? 'Vô địch' : 'Hạng $position';
  static String fee(int amount) => amount == 0 ? 'Miễn phí' : Formatters.vnd(amount);
  static String teamSize(int min, int max) => min == max ? '$min người / đội' : '$min–$max người / đội';
  static String entries(int count, int max, DivisionType type) =>
      '$count/$max ${type.needsTeam ? 'đội' : 'người'}';
  static const String register = 'Đăng ký';
  static const String registered = 'Đã đăng ký';
  static const String registrationClosed = 'Hết hạn đăng ký';
  static const String full = 'Hết suất';
  static const String bracket = 'Sơ đồ thi đấu';
  static const String bracketEmpty = 'Chưa bốc thăm. Sơ đồ sẽ hiện khi ban tổ chức xếp cặp.';
  static const String ticket = 'Vé QR';
  static const String withdraw = 'Rút đăng ký';
  static const String checkedIn = 'Đã check-in';

  // Đăng ký
  static const String registerTitle = 'Đăng Ký Giải';
  static const String entryFee = 'Lệ phí';
  static const String walletBalance = 'Số dư ví';
  static const String feeNote = 'Lệ phí được tạm giữ trong ví cho tới khi giải kết thúc. '
      'Rút trước hạn đăng ký được hoàn 100%, sau hạn không hoàn.';
  static const String randomDoublesNote = 'Bạn đăng ký cá nhân, ban tổ chức sẽ ghép đôi sau khi hết hạn đăng ký.';
  static const String chooseTeam = 'Chọn đội';
  static String teamSizeRequired(int min, int max) =>
      'Đội cần ${min == max ? '$min' : '$min–$max'} thành viên đã nhận lời mời.';
  static const String noEligibleTeam = 'Bạn chưa có đội phù hợp.';
  static const String createTeam = 'Tạo đội mới';
  static String teamSizeInvalid(int count) => '$count thành viên (không đủ điều kiện)';
  static const String confirmRegister = 'XÁC NHẬN ĐĂNG KÝ';
  static const String notEnoughBalance = 'Số dư không đủ để trả lệ phí.';
  static const String topUp = 'Nạp tiền';
  static const String registerSuccess = 'Đăng ký thành công!';

  // Rút
  static const String withdrawTitle = 'Rút đăng ký?';
  static String withdrawRefund(int amount) =>
      'Lệ phí ${Formatters.vnd(amount)} được hoàn 100% về ví của người đã trả. Giải đội: cả đội sẽ bị rút.';
  static const String withdrawNoRefund = 'Đã quá hạn đăng ký nên lệ phí KHÔNG được hoàn. Giải đội: cả đội sẽ bị rút.';
  static const String withdrawConfirm = 'Rút';
  static const String back = 'Quay lại';
  static const String withdrawn = 'Đã rút đăng ký';

  // Vé
  static const String ticketTitle = 'Vé Check-in Giải';
  static const String ticketHint = 'Đưa mã này cho chủ sân quét khi đến thi đấu. Mỗi thành viên có một mã riêng.';

  // Lịch đấu
  static String versus(String a, String b) => '$a  vs  $b';
  static String winner(String name) => 'Thắng: $name';

  static const String loadError = 'Không tải được dữ liệu. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
