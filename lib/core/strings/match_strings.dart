import '../utils/formatters.dart';

/// Chuỗi phần thi đấu: nhập tỉ số, lịch sân / xếp sân, trọng tài, khiếu nại phía BTC, bảng xếp hạng.
class MatchStrings {
  MatchStrings._();

  // ---- Nhập tỉ số ----
  static const String scoreTitle = 'Nhập tỉ số trận đấu';
  static const String saveScore = 'Lưu tỉ số';
  static const String saving = 'Đang lưu…';
  static const String scoreHint =
      'Nhập điểm từng hiệp. Hệ thống tự kiểm tra luật điểm của môn và tự xác định người thắng. Elo cập nhật sau khi hết hạn khiếu nại (15 – 20 phút).';
  static const String resultKind = 'Kết quả';
  static String setLabel(int i) => 'Hiệp $i';
  static const String addSet = 'Thêm hiệp';
  static const String removeSet = 'Xóa hiệp';
  static const String tiebreak = 'Luân lưu';
  static const String tiebreakGroupHint = 'Luân lưu (để trống nếu trận vòng bảng được hòa)';
  static const String drawNote = 'Tỉ số bằng nhau ở vòng bảng / vòng tròn: trận được ghi nhận là Hòa (không có người thắng).';
  static const String knockoutDrawNeedsTiebreak = 'Trận loại trực tiếp hòa: nhập tỉ số luân lưu (không được bằng nhau).';
  static const String walkoverWinner = 'Bên được xử thắng';
  static const String retiredWinner = 'Bên thắng (bên còn lại bỏ cuộc)';
  static String wins(String name) => '$name thắng';
  static const String goCheckIn = 'Điểm danh ở danh sách vận động viên tham gia rồi quay lại nhập tỉ số.';
  static const String note = 'Ghi chú gửi người khiếu nại';
  static const String noteHint = 'Ví dụ: Đã đối chiếu biên bản trọng tài, sửa tỉ số set 2.';
  static const String scoreSaved = 'Đã cập nhật tỉ số. Elo sẽ được cập nhật sau khi hết hạn khiếu nại (15 – 20 phút).';
  static const String sideA = 'Bên 1';
  static const String sideB = 'Bên 2';
  static const String loadError = 'Không tải được thông tin trận.';
  static const String tapToScore = 'Bấm vào trận đã đủ 2 đấu thủ để nhập tỉ số.';
  static String champion(String name) => 'Nhà vô địch: $name';

  // ---- Lịch sân ----
  static const String scheduleTitle = 'Lịch sân & lịch thi đấu';
  static const String scheduleEmpty = 'Chưa giữ sân và chưa xếp trận nào.';
  static const String heldCourts = 'Sân đang giữ: ';
  static const String none = 'không có';
  static String block(String court, DateTime start, DateTime end, int slots) =>
      '$court ${Formatters.time(start)} – ${Formatters.time(end)} ($slots ca) ✓ đã giữ';
  static const String noMatchesToday = 'Chưa xếp trận nào trong ngày.';
  static const String done = 'Đã xong';
  static const String tbd = 'Chờ xác định';
  static String versus(String a, String b) => '$a vs $b';
  static const String assignTitle = 'Xếp sân & trọng tài';
  static const String autoSchedule = 'Tự xếp ca + trọng tài';
  static const String autoScheduling = 'Đang xếp…';
  static const String autoScheduled = 'Đã tự xếp ca và đề xuất trọng tài cho các trận.';
  static const String notScheduled = 'Chưa xếp';
  static const String assignCourt = 'Xếp sân';
  static const String changeCourt = 'Đổi sân';
  static const String referee = 'Trọng tài';
  static const String pickReferee = '— Chọn —';
  static const String noReferee = 'Chưa có trọng tài';
  static const String refereeSet = 'Đã phân trọng tài.';
  static const String refereeCleared = 'Đã bỏ trọng tài.';
  static const String refereeNote = 'Phân công để hiển thị: mọi trọng tài của giải vẫn nhập được tỉ số mọi trận.';
  static const String courtHint = 'Ca sân do chủ sân giữ cho giải; Ban tổ chức là người chơi không tự giữ ca được.';

  // ---- Xếp sân cho trận ----
  static const String assignCourtTitle = 'Xếp sân cho trận';
  static const String prevDay = 'Ngày trước';
  static const String nextDay = 'Ngày sau';
  static const String noSlots = 'Không có ca trống trong ngày này.';
  static const String reserved = 'Đã giữ cho giải';
  static const String free = 'Còn trống';
  static const String pickSlot = 'Chọn một ca sân.';
  static String assigned(String court, DateTime at) => 'Đã xếp $court lúc ${Formatters.dateTime(at)}.';

  // ---- Bảng xếp hạng ----
  static const String standingsTitle = 'Bảng xếp hạng';

  // ---- Khiếu nại (BTC) ----
  static String complaintsTitle(int open) => open > 0 ? 'Khiếu nại kết quả trận ($open đang mở)' : 'Khiếu nại kết quả trận';
  static const String open = 'Đang mở';
  static const String all = 'Tất cả';
  static const String noOpenComplaints = 'Không có khiếu nại nào đang chờ.';
  static const String noComplaints = 'Chưa có khiếu nại nào.';
  static const String player = 'Người chơi';
  static String currentResult(String winner) => 'Kết quả hiện tại: $winner thắng';
  static String conclusion(String note) => 'Kết luận: $note';
  static const String keepResult = 'Giữ kết quả';
  static const String accept = 'Chấp nhận';
  static const String fixScore = 'Sửa tỉ số & đóng';
  static const String keepHint = 'Lý do giữ nguyên kết quả (gửi người khiếu nại)';
  static const String acceptHint = 'Lý do chấp nhận (gửi người khiếu nại)';
  static const String back = 'Thôi';
  static const String confirmKeep = 'Xác nhận giữ kết quả';
  static const String confirmAccept = 'Xác nhận chấp nhận';
  static const String noteRequired = 'Nhập lý do quyết định để gửi người khiếu nại.';
  static const String kept = 'Đã bác khiếu nại, giữ nguyên kết quả.';
  static const String accepted = 'Đã chấp nhận khiếu nại. Sửa tỉ số ở sơ đồ nếu cần.';
  static const String fixTitle = 'Sửa tỉ số và đóng khiếu nại';
  static const String fixed = 'Đã sửa tỉ số và đóng khiếu nại. Elo được tính lại sau.';

  // ---- Trọng tài (đợt 5) ----
  static const String tabReferee = 'Trận tôi làm trọng tài';
  static String refereeIntro(int n) => 'Bạn là trọng tài / người nhập điểm của $n giải. Chọn giải để xem lịch và nhập tỉ số.';
  static String waiting(int n) => '$n trận chờ nhập tỉ số';
  static String doneCount(int done, int total) => '$done/$total trận đã có kết quả';
  static const String refereeRule =
      'Bạn nhập được tỉ số các trận của giải tới khi giải kết thúc. Hai bên phải điểm danh trước khi thi đấu: bên vắng mặt bị xử thua. Sửa tỉ số trận đã xong sẽ tính lại Elo và mở lại thời gian khiếu nại.';
  static const String tabScore = 'Nhập tỉ số';
  static const String tabCheckIn = 'Điểm danh';
  static const String enterScore = 'Nhập tỉ số';
  static const String editScore = 'Sửa tỉ số';
  static const String notEnoughSides = 'Trận chưa đủ hai bên';
  static const String assignedToYou = 'Được phân công trận này';
  static const String hasResult = 'Đã có kết quả';
  static const String noTime = 'Chưa xếp giờ';
  static const String noCourt = 'Chưa xếp sân';
  static const String refereeSaved = 'Đã lưu tỉ số. Elo được tính sau khi hết thời gian khiếu nại.';
  static String scoreOf(String a, String b) => 'Tỉ số: $a vs $b';
  static const String searchName = 'Tìm tên vận động viên / đội';
  static String checkedInCount(int done, int total) => 'Đã điểm danh $done/$total';

  // ---- Chủ sân giữ / trả ca (đợt 5) ----
  static const String blockTitle = 'Giữ khung giờ sân cho giải';
  static const String fromDate = 'Từ ngày';
  static const String toDate = 'Đến ngày';
  static const String fromTime = 'Từ giờ';
  static const String toTime = 'Đến giờ';
  static const String anyTime = 'Cả ngày';
  static const String heldMark = ' ✓ đã giữ';
  static const String releaseHint = 'Trả ca: bỏ trống sân và giờ = trả mọi ca chưa tới giờ đang giữ.';
  static const String release = 'Trả ca';
  static const String blockAction = 'Giữ sân cho giải';
  static const String pickCourt = 'Chọn ít nhất 1 sân để giữ.';
  static const String dateOrder = 'Ngày kết thúc phải sau ngày bắt đầu.';
  static String blocked(int n, int already) => 'Đã giữ $n ca (đã giữ trước đó $already).';
  static String released(int n) => 'Đã trả $n ca cho khách đặt.';
  static String conflictsTitle(int n) => '$n ca không giữ được:';
  static const String noCourts = 'Cơ sở chưa có sân nào.';
}
