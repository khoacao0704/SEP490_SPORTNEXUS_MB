import '../utils/formatters.dart';

/// Chuỗi phần tổ chức giải (Giải tôi tổ chức, form tạo giải, sửa / hủy / xóa).
class OrganizerStrings {
  OrganizerStrings._();

  static const String tabOrganized = 'Giải tôi tổ chức';
  static const String createNew = 'Tạo giải đấu mới';
  static const String all = 'Tất cả';
  static const String empty = 'Bạn chưa tổ chức giải nào.';
  static const String loadError = 'Không tải được danh sách giải.';
  static const String retry = 'Thử lại';
  static const String stillManage = 'Các giải bạn đã tạo vẫn quản lý bình thường.';
  static const String fairPlayHint = 'Điểm tăng khi bạn thi đấu đúng hẹn và được người chơi khác đánh giá tốt.';
  static const String kycPending = 'Hồ sơ xác minh danh tính (CCCD) đang chờ Admin duyệt.';
  static const String kycRequired = 'Cần xác minh danh tính (CCCD) và được Admin duyệt để tổ chức giải.';
  static const String verifyNow = 'Xác minh ngay';

  // ---- Form ----
  static const String createTitle = 'Tạo giải đấu';
  static const String facility = 'Cơ sở tổ chức';
  static const String facilityHint = 'Gõ tên hoặc địa chỉ cơ sở (không cần dấu)';
  static const String facilityNone = 'Không tìm thấy cơ sở phù hợp.';
  static const String change = 'Đổi';
  static const String name = 'Tên giải đấu';
  static const String sport = 'Bộ môn';
  static const String start = 'Ngày bắt đầu';
  static const String end = 'Ngày kết thúc';
  static const String deadline = 'Hạn đăng ký';
  static const String pickDate = 'Chọn ngày';
  static const String tier = 'Cấp giải';
  static const String tierAmateurHint = 'Không xét Elo.';
  static const String tierRatedHint = 'Ban tổ chức tự đặt Elo tối thiểu, Elo tối đa và số trận giải tối thiểu.';
  static const String minRating = 'Elo tối thiểu';
  static const String maxRating = 'Elo tối đa';
  static const String minRatedMatches = 'Số trận giải tối thiểu';
  static const String purpose = 'Mục đích';
  static const String purposeDevelopmentNote = 'Phát triển chuyên môn (từ Bán chuyên)';
  static const String purposeInternalNote = 'Nội bộ (chỉ người được mời, BTC được thi đấu)';
  static const String type = 'Hình thức đăng ký';
  static String maxCount(bool team) => 'Số ${team ? 'đội' : 'người'} tham gia tối đa';
  static const String format = 'Thể thức thi đấu';
  static const String suggested = ' (gợi ý)';
  static const String formatLocked = 'Thể thức chốt khi tạo giải, không đổi được.';
  static String estimate(int n) => 'Ước tính $n trận.';
  static const String schedule = 'Lịch sân cần dùng (không bắt buộc)';
  static const String scheduleHint = 'Mỗi dòng: ngày, buổi, số sân. Chủ sân dựa vào đây để giữ khung giờ cho giải.';
  static const String addScheduleRow = 'Thêm dòng lịch sân';
  static const String courtCount = 'Số sân';
  static const String day = 'Ngày';
  static const String session = 'Buổi';
  static const String entryFee = 'Lệ phí (Điểm, 0 = miễn phí)';
  static const String prizes = 'Giải thưởng (BTC tự trao ngoài hệ thống)';
  static const String prizePosition = 'Hạng';
  static const String prizeAmount = 'Giá trị';
  static const String addPrize = 'Thêm giải thưởng';
  static const String champion = 'Vô địch';
  static const String description = 'Giới thiệu giải (không bắt buộc)';
  static const String documents = 'Tài liệu gửi Admin duyệt (PDF)';
  static const String documentsHint =
      'Chi tiết giải, luật lệ chi tiết, danh sách nhân sự… Chọn được nhiều file. Người chơi không thấy các file này.';
  static const String contract = 'Hợp đồng với chủ sân (PDF)';
  static const String contractHint = 'Bản thỏa thuận thuê sân với chủ cơ sở tổ chức giải (không bắt buộc).';
  static const String uploadPdf = 'Tải file PDF';
  static const String addFile = 'Thêm file';
  static const String changeFile = 'Đổi file';
  static const String uploading = 'Đang tải…';
  static const String pdfOnly = 'Chỉ nhận file PDF.';
  static const String submit = 'Gửi giải chờ duyệt';
  static const String submitted = 'Đã gửi giải, chờ Admin duyệt trước khi công khai và nhận đăng ký.';
  static const String submittedApproved = 'Đã tạo giải, giải đã công khai và mở đăng ký.';
  static const String sportsError = 'Không tải được danh sách bộ môn.';

  // ---- Lỗi form ----
  static const String nameRequired = 'Vui lòng nhập tên giải.';
  static const String sportRequired = 'Vui lòng chọn bộ môn.';
  static const String facilityRequired = 'Vui lòng chọn cơ sở tổ chức giải.';
  static const String maxCountTooSmall = 'Số người / đội tham gia tối đa phải từ 4 trở lên.';
  static const String developmentNeedsRated = 'Mục đích "Phát triển chuyên môn" chỉ áp dụng cho giải từ Bán chuyên.';
  static const String ratingRequired =
      'Giải Bán chuyên / Chuyên nghiệp cần nhập Elo tối thiểu, Elo tối đa và số trận giải tối thiểu.';
  static const String ratingOrder = 'Elo tối thiểu không được lớn hơn Elo tối đa.';
  static String formatFix(String error) => '$error Đổi thể thức hoặc số người tối đa.';

  // ---- Chi tiết / quản lý ----
  static const String manageTitle = 'Quản lý giải';
  static const String pendingBanner = 'Giải đang chờ Admin duyệt: chưa hiện công khai và chưa nhận đăng ký.';
  static String rejectedBanner(String note) => note.isEmpty ? 'Admin đã từ chối giải.' : 'Admin đã từ chối giải: $note';
  static const String internalBanner =
      'Giải nội bộ: không hiện công khai, người chơi chỉ tham gia qua lời mời của Ban tổ chức.';
  static String cancelledBanner(String reason) => reason.isEmpty ? 'Giải đã hủy.' : 'Giải đã hủy: $reason';
  static const String participants = 'Số người đăng ký';
  static const String requestedSchedule = 'Lịch sân yêu cầu';
  static const String sentDocuments = 'Tài liệu đã gửi Admin';
  static const String noDocuments = 'Chưa gửi tài liệu nào.';
  static const String noPrizes = 'Không có';
  static String prizeTotal(int total) => '(tổng ${Formatters.vnd(total)})';
  static const String editInfo = 'Sửa thông tin giải';
  static const String editFee = 'Sửa lệ phí';
  static const String editFeeHint = 'Chỉ sửa được khi giải còn mở và chưa có ai đăng ký.';
  static const String saveFee = 'Lưu lệ phí';
  static const String feeSaved = 'Đã cập nhật lệ phí.';
  static const String cancel = 'Hủy giải';
  static const String cancelLocked = 'Hủy giải (đã khóa)';
  static const String cancelLockedReason =
      'Ban tổ chức chỉ được hủy giải tới 24 giờ trước hạn đăng ký. Hết hạn đăng ký mà thiếu người thì chọn Hủy trong mục quyết định thiếu người.';
  static String cancelTitle(String name) => 'Hủy giải "$name"';
  static const String cancelHint = 'Lý do hủy giải (người tham gia sẽ thấy)';
  static const String cancelReasonRequired = 'Vui lòng nhập lý do hủy giải.';
  static const String cancelConfirm = 'Xác nhận hủy';
  static const String keep = 'Quay lại';
  static const String cancelled = 'Đã hủy giải, hoàn lệ phí cho người tham gia.';
  static const String delete = 'Xóa giải';
  static String deleteConfirm(String name) => 'Xóa vĩnh viễn giải "$name"?';
  static const String deleted = 'Đã xóa giải đấu.';

  // ---- Sửa thông tin ----
  static const String image = 'Ảnh bìa giải';
  static const String pickImage = 'Chọn ảnh';
  static const String save = 'Lưu thay đổi';
  static const String saved = 'Đã lưu thông tin giải.';

  // ---- Người tham gia (đợt 3) ----
  static String participantsTitle(bool team, int n, int max) => '${team ? 'Đội' : 'Vận động viên'} tham gia ($n/$max)';
  static const String noParticipants = 'Chưa có người đăng ký.';
  static const String checkIn = 'Điểm danh';
  static const String checkedIn = '✓ Đã điểm danh';
  static String checkedInDone(String name) => 'Đã điểm danh "$name".';
  static const String remove = 'Xóa khỏi giải';
  static String removeConfirm(String name) => 'Xóa "$name" khỏi giải?';
  static String removed(String name) => 'Đã xóa "$name" khỏi giải.';
  static const String publicNote =
      'Giải công khai: người chơi tự đăng ký. Muốn mời người, hãy tạo giải với mục đích "Nội bộ".';
  static const String invitePhoneHint = 'Số điện thoại VĐV cần mời';
  static const String inviteTeamHint = 'Tìm đội theo tên đội hoặc tên đội trưởng';
  static const String invite = 'Mời';
  static const String invitedPlayer = 'Đã gửi lời mời tới vận động viên.';
  static const String invitedTeam = 'Đã gửi lời mời tới đội trưởng.';
  static const String noTeams = 'Không tìm thấy đội phù hợp.';
  static String teamSubtitle(String captain, int members) => 'Đội trưởng: $captain • $members thành viên';
  static String sentInvitations(int n) => 'Lời mời đã gửi ($n)';
  static const String revoke = 'Thu hồi';
  static const String revoked = 'Đã thu hồi lời mời.';
  static const String loadPartError = 'Không tải được dữ liệu.';

  // ---- Thiếu người ----
  static const String shortTitle = 'Hết hạn đăng ký nhưng chưa đủ người';
  static const String shortBody =
      'Chọn trong 24 giờ sau khi nhận thông báo: hủy giải (hoàn 100% lệ phí) hoặc vẫn thi đấu với số người hiện có (cần ≥ 2).';
  static const String keepPlaying = 'Vẫn thi đấu';
  static const String cancelRefund = 'Hủy giải (hoàn 100% lệ phí)';
  static const String reasonOptional = 'Lý do (không bắt buộc)';
  static const String confirm = 'Xác nhận';
  static const String cancelRefundConfirm = 'Hủy giải và hoàn 100% lệ phí cho người đã đăng ký?';
  static const String decided = 'Đã ghi nhận quyết định.';

  // ---- Sơ đồ ----
  static const String pairing = 'Bốc thăm ghép đôi';
  static const String paired = 'Bốc thăm ghép đôi hoàn tất, các cặp đấu đã được tạo.';
  static const String generate = 'Chốt danh sách & sinh nhánh';
  static const String generateConfirm =
      'Chốt danh sách và sinh sơ đồ nhánh đấu? Sau bước này không thể thêm / xóa người tham gia.';
  static const String generated = 'Đã chốt danh sách và sinh sơ đồ nhánh đấu. Giải chuyển sang Đang thi đấu.';
  static String formatSummary(String format, int n, bool team, int matches) =>
      '$format (đã chốt khi tạo giải) với $n ${team ? 'đội' : 'đấu thủ'}: khoảng $matches trận.';
  static const String needTwo = 'Cần ít nhất 2 người / đội để sinh sơ đồ.';
  static const String formatLockedWait =
      ' Thể thức đã chốt nên chưa sinh được sơ đồ: chờ thêm người đăng ký hoặc chọn hủy khi hết hạn.';
  static const String bracketTitle = 'Sơ đồ nhánh đấu';
  static const String bracketEmpty = 'Chưa có sơ đồ nhánh đấu. Sơ đồ được sinh khi chốt danh sách.';

  // ---- Nhân sự ----
  static String staffTitle(int n) => 'Nhân sự giải ($n)';
  static const String role = 'Vai trò';
  static const String phone = 'Số điện thoại';
  static const String find = 'Tìm';
  static const String finding = 'Đang tìm…';
  static const String fullName = 'Họ tên';
  static const String fullNameAuto = 'Tự điền sau khi tìm';
  static const String note = 'Ghi chú';
  static const String accountLinked = '✓ Đã gắn tài khoản: điểm danh và nhập được tỉ số các trận của giải';
  static const String accountNeeded = 'Người này phải có tài khoản SportNexus.';
  static const String accountNotFound = 'Không tìm thấy tài khoản với số điện thoại này.';
  static const String staffNeedAccount = 'Trọng tài / người ghi điểm phải có tài khoản: nhập số điện thoại rồi bấm Tìm.';
  static const String staffNeedNamePhone = 'Nhập họ tên và số điện thoại.';
  static const String hasAccount = 'Có tài khoản (nhập được tỉ số)';
  static const String addStaff = 'Thêm nhân sự';
  static const String cancelEdit = 'Hủy sửa';
  static const String edit = 'Sửa';
  static const String staffAdded = 'Đã thêm nhân sự.';
  static const String staffUpdated = 'Đã cập nhật nhân sự.';
  static String staffRemoveConfirm(String name) => 'Xóa $name khỏi nhân sự giải?';
  static const String staffRemoved = 'Đã xóa nhân sự.';

  // ---- Chủ sân (đợt 5) ----
  static const String ownerTitle = 'Giải đấu';
  static const String ownerMine = 'Tôi tổ chức';
  static const String ownerAtFacility = 'Giải tại sân của tôi';
  static String atFacilityNote(String organizer) =>
      'Giải do $organizer tổ chức tại cơ sở của bạn: bạn xem lịch và giữ khung giờ sân cho giải ở phần bên dưới.';
  static const String someoneElse = 'người khác';
  static const String noFacility = 'Bạn chưa có cơ sở được duyệt nên chưa tạo được giải.';
  static const String emptyAtFacility = 'Chưa có giải nào của người khác tại cơ sở này.';
  static const String menuTitle = 'MENU';
}
