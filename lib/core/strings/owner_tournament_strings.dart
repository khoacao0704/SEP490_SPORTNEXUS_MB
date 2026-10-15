import '../utils/formatters.dart';

/// Chuỗi hiển thị cho giải đấu do Chủ sân tổ chức.
class OwnerTournamentStrings {
  OwnerTournamentStrings._();

  // Danh sách
  static const String title = 'Giải Đấu Của Tôi';
  static const String create = 'Tạo giải';
  static const String empty = 'Bạn chưa tổ chức giải nào';
  static const String emptyHint = 'Tạo giải tại cơ sở đã duyệt, người chơi đăng ký và trả lệ phí qua app.';
  static String entries(int n, int max) => '$n/$max đơn';

  // Form
  static const String createTitle = 'Tạo Giải Đấu';
  static const String editTitle = 'Sửa Giải Đấu';
  static const String sectionBasic = 'Thông tin giải';
  static const String name = 'Tên giải';
  static const String facility = 'Cơ sở';
  static const String sport = 'Môn';
  static const String courtType = 'Loại sân thi đấu';
  static const String entryType = 'Thể thức đăng ký';
  static const String teamSize = 'Số người tối đa mỗi đội (gồm dự bị)';
  static String teamSizeHint(int min) => 'Tối thiểu $min người theo loại sân';
  static const String maxEntries = 'Số suất (kích thước sơ đồ)';
  static const String entryFee = 'Lệ phí mỗi đơn';
  static const String feeNote = 'Lệ phí giữ ở app, về ví bạn khi giải kết thúc (tính vào doanh thu, có phí 10%).';
  static const String sectionDates = 'Thời gian';
  static const String deadline = 'Hạn đăng ký';
  static const String startDate = 'Khai mạc';
  static const String endDate = 'Kết thúc';
  static const String closureNote =
      'Loại sân thi đấu sẽ tự tạm đóng trong các ngày thi đấu. Ngày đó đã có người đặt thì không tạo được giải.';
  static const String sectionInfo = 'Mô tả, giải thưởng & điều lệ';
  static const String description = 'Mô tả (không bắt buộc)';
  static const String prizes = 'Giải thưởng';
  static const String prizesNote = 'Bạn tự trao thưởng tại giải, app chỉ hiển thị.';
  static const String addPrize = 'Thêm giải thưởng';
  static const String prizeTitle = 'Tên giải (vd. Vô địch)';
  static const String prizeAmount = 'Tiền thưởng';
  static const String prizeExtra = 'Hiện vật (vd. Cúp)';
  static const String rules = 'Điều lệ';
  static const String addRule = 'Thêm điều lệ';
  static const List<String> defaultRules = [
    'Thể thức loại trực tiếp, bốc thăm chia nhánh sau khi hết hạn đăng ký.',
    'Có mặt trước giờ thi đấu 30 phút để check-in với ban tổ chức.',
    'Trễ quá 15 phút so với giờ thi đấu bị xử thua.',
  ];
  static const String lockedNote = 'Đã có người đăng ký: chỉ sửa được mô tả, giải thưởng và điều lệ.';
  static const String save = 'Lưu';
  static const String publish = 'Tạo giải & mở đăng ký';
  static const String created = 'Đã tạo giải và mở đăng ký.';
  static const String saved = 'Đã lưu thay đổi.';
  static const String add = 'Thêm';
  static const String cancel = 'Hủy';
  static const String required = 'Bắt buộc';

  // Lỗi
  static const String noFacility = 'Bạn cần có cơ sở đã duyệt để tạo giải.';
  static const String invalidName = 'Hãy nhập tên giải.';
  static const String invalidCourt = 'Loại sân không có ở cơ sở này hoặc đang bị khóa.';
  static const String invalidEntryType = 'Thể thức không phù hợp với môn.';
  static const String invalidMembers = 'Số người mỗi đội không hợp lệ.';
  static const String invalidSize = 'Số suất phải là 4, 8, 16 hoặc 32.';
  static const String invalidFee = 'Lệ phí không hợp lệ.';
  static const String invalidDates = 'Hạn đăng ký phải trước khai mạc, khai mạc không sau ngày kết thúc.';
  static const String deadlinePassed = 'Hạn đăng ký phải sau thời điểm hiện tại.';
  static const String lockedFields =
      'Đã có người đăng ký nên không đổi được tên, môn, thể thức, lệ phí, số suất hay ngày giờ.';
  static const String notOrganizer = 'Bạn không phải ban tổ chức giải này.';
  static const String alreadyCancelled = 'Giải đã bị hủy.';
  static const String alreadyFinished = 'Giải đã kết thúc.';
  static const String drawNotYet = 'Chỉ bốc thăm được sau hạn đăng ký.';
  static const String drawTooFew = 'Cần ít nhất 4 đơn để bốc thăm. Ít hơn thì chỉ có thể hủy giải.';
  static const String alreadyDrawn = 'Giải đã bốc thăm.';
  static const String matchNotReady = 'Trận chưa đủ hai bên.';
  static const String invalidWinner = 'Người thắng phải là một trong hai bên.';
  static const String scoreRequired = 'Hãy nhập tỉ số.';
  static const String nextPlayed = 'Trận vòng sau đã có kết quả nên không sửa được trận này.';
  static const String matchNotFound = 'Không tìm thấy trận.';

  // Chi tiết
  static const String detailTitle = 'Quản Lý Giải';
  static const String edit = 'Sửa';
  static const String cancelTournament = 'Hủy giải';
  static const String cancelTitle = 'Hủy giải đấu?';
  static String cancelConfirm(int entries, int fee) =>
      'Hủy giải sẽ hoàn 100% lệ phí cho $entries đơn (${Formatters.vnd(entries * fee)}) và mở lại sân. '
      'Không hoàn tác được.';
  static const String cancelled = 'Đã hủy giải và hoàn lệ phí.';
  static const String keep = 'Giữ giải';
  static String feeLine(int fee) => 'Lệ phí ${Formatters.vnd(fee)} / đơn';
  static String holding(int amount) => 'Lệ phí đang giữ: ${Formatters.vnd(amount)} (về ví khi giải kết thúc)';
  static String paidOut(int amount) => 'Đã giải ngân ${Formatters.vnd(amount)} vào ví';
  static const String entriesTitle = 'Đơn đăng ký';
  static const String noEntries = 'Chưa có đơn đăng ký.';
  static String members(int n) => '$n người';
  static const String withdrawn = 'Đã rút';
  static const String bracketTitle = 'Sơ đồ & lịch thi đấu';
  static const String draw = 'Bốc thăm';
  static String drawHint(String deadline) => 'Bốc thăm ngẫu nhiên sau hạn đăng ký ($deadline), cần ít nhất 4 đơn.';
  static const String drawTitle = 'Bốc thăm chia nhánh?';
  static String drawConfirm(int entries, int size) {
    final byes = size - entries;
    return 'Bốc thăm ngẫu nhiên $entries đơn vào sơ đồ $size.'
        '${byes > 0 ? ' $byes đơn được miễn thi đấu vòng 1.' : ''} Không bốc lại được.';
  }

  static const String drawn = 'Đã bốc thăm.';
  // Trận
  static const String schedule = 'Xếp lịch';
  static const String time = 'Giờ thi đấu';
  static const String court = 'Sân';
  static const String saveSchedule = 'Lưu lịch';
  static const String result = 'Kết quả';
  static const String winner = 'Bên thắng';
  static const String score = 'Tỉ số (vd. 21-18, 21-15)';
  static const String saveResult = 'Lưu kết quả';
  static const String resultSaved = 'Đã lưu kết quả.';
  static const String scheduleSaved = 'Đã xếp lịch.';
  static const String tapToUpdate = 'Chạm vào trận để xếp lịch hoặc nhập kết quả.';
  static String champion(String name) => 'Vô địch: $name';
  static const String closureReason = 'Giải đấu';
}
