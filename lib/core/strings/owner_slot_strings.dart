import '../utils/formatters.dart';

/// Chuỗi trang "Sân & giá" và "Ca sân" của Chủ sân (câu chữ lấy từ Web).
class OwnerSlotStrings {
  OwnerSlotStrings._();

  // ---------------- Lối vào từ chi tiết cơ sở ----------------
  static const String courtsEntry = 'Sân & giá';
  static const String courtsEntryHint = 'Sân con theo khu vực, giá mặc định, giờ mở cửa và thời lượng ca.';
  static const String slotsEntry = 'Ca sân';
  static const String slotsEntryHint = 'Lịch 7 ngày, sinh ca, khóa / mở, đổi giá, xóa ca và đợt giá đặc biệt.';

  // ---------------- Sân & giá ----------------
  static const String courtsTitle = 'Sân & giá';
  static String courtsSubtitle(String facility, int zones, int active, int total) =>
      '$facility • $zones khu vực • $active/$total sân đang phục vụ';
  static const String pendingFacility = 'Cơ sở chờ Admin duyệt';
  static const String rejectedFacility = 'Cơ sở bị từ chối';
  static const String tabZones = 'Sân theo khu vực';
  static const String tabPricing = 'Bảng giá';
  static const String tabTimeGrid = 'Giờ mở cửa';
  static const String addCourt = 'Thêm sân';
  static const String addCourtInZone = 'Thêm sân con';
  static const String noCourts = 'Cơ sở chưa có sân nào.';
  static String zoneName(String sport) => 'Khu $sport';
  static String zoneSummary(String sport, int n) => '$sport • $n sân';
  static String zoneTotal(int n) => 'Tổng: $n sân đấu';
  static const String zonePriceLabel = 'Mức giá áp dụng cho khu này';
  static String zoneDefaultPrice(int price) => 'Giá mặc định: ${Formatters.vnd(price)}/h';
  static String zoneCourtsTitle(String zone) => 'Danh sách các sân con trong $zone';
  static const String courtActive = 'Hoạt động tốt';
  static const String courtInactive = 'Tạm ngưng / Bảo trì';
  static const String noSurface = 'Chưa cập nhật mặt sân';
  static const String suspendCourt = 'Tạm ngưng sân';
  static const String reopenCourt = 'Mở lại sân';
  static const String edit = 'Sửa';
  static const String delete = 'Xóa';
  static String courtToggled(bool active, String name) => 'Đã ${active ? 'mở lại' : 'tạm ngưng'} $name!';
  static String deleteCourtConfirm(String name) =>
      'Xóa $name? Các ca tương lai chưa có người đặt của sân này cũng bị xóa.';
  static String courtDeleted(String name, int slots) => 'Đã xóa $name${slots > 0 ? ' và $slots ca tương lai' : ''}.';
  static String courtAdded(String name) => 'Đã thêm sân "$name".';
  static String courtUpdated(String name) => 'Đã cập nhật $name.';

  // Áp dụng cấu hình mới cho ca đã sinh
  static const String regenerateTitle = 'Áp dụng cho lịch đã sinh';
  static const String regenerateBody =
      'Bạn có muốn áp dụng cấu hình mới này cho các ca trống từ ngày mai không? (Các đơn khách đã đặt sẽ được giữ nguyên)';
  static const String regenerateYes = 'Có, áp dụng';
  static const String regenerateNo = 'Không';
  static String regenerated(String target) => 'Đã sinh lại ca trống từ ngày mai cho $target.';
  static String regenerateTarget(int n, String first) => n > 1 ? '$n sân' : first;
  static String regenerateFailed(int failed, int total, String reason) =>
      'Không sinh lại được ca cho $failed/$total sân: $reason';

  // Bảng giá
  static const String pricingNote =
      'Giá chuẩn của từng khu được lưu trực tiếp lên sân (giá mặc định). Hiện hệ thống chưa có API lưu quy tắc định giá '
      'động tự động — để áp dụng giá riêng cho giờ cao điểm / cuối tuần, vui lòng dùng chức năng "Đổi giá" ở trang Ca sân.';
  static const String pricingTitle = 'Bảng giá cơ sở theo từng cụm sân (Điểm/Giờ)';
  static const String pricingEmpty = 'Cơ sở chưa có sân nào. Hãy thêm sân ở tab "Sân theo khu vực".';
  static String pricingCourts(int n) => '$n sân';
  static const String pricingPriceLabel = 'Giá mặc định (Điểm/Giờ)';
  static const String savePrice = 'Lưu giá';
  static const String saving = 'Đang lưu...';
  static String zonePriceSaved(String zone, int price) => 'Đã cập nhật giá chuẩn $zone: ${Formatters.vnd(price)}/h';

  // Giờ mở cửa
  static const String timeGridTitle = 'Cấu hình khung giờ hoạt động & lưới thời gian';
  static const String timeGridHint = 'Thiết lập giờ mở cửa, đóng cửa của cơ sở và thời lượng mỗi ca cho từng sân.';
  static const String openTime = 'Giờ mở cửa cơ sở';
  static const String openTimeHint = 'Bắt đầu nhận ca đặt sân đầu tiên';
  static const String closeTime = 'Giờ đóng cửa cơ sở';
  static const String closeTimeHint = 'Ca chơi cuối cùng kết thúc';
  static const String saveHours = 'Lưu giờ mở / đóng cửa cơ sở';
  static const String hoursSaved = 'Đã lưu giờ mở cửa / đóng cửa của cơ sở!';
  static const String hoursInvalid = 'Giờ đóng cửa phải sau giờ mở cửa.';
  static const String slotMinutesTitle = 'Thời lượng mỗi ca theo từng sân';
  static const String slotMinutesHint =
      'Áp dụng cho các ca sinh sau khi đổi (sinh ca hàng loạt và tự sinh hằng ngày). Ca đã sinh giữ nguyên: xóa ca trống '
      'ở trang Ca sân rồi sinh lại nếu muốn đổi.';
  static const String mergeNote = 'Người chơi đặt nhiều ca liền nhau trên cùng sân sẽ được gộp thành 1 đơn, 1 mã QR.';
  static String bySport(int minutes) => 'Theo môn ($minutes phút)';
  static String minutes(int m) => '$m phút';
  static String slotMinutesChanged(String court, int? m) => 'Đã đổi thời lượng ca $court: ${m == null ? 'theo môn' : '$m phút'}.';
  static String previewTitle(String open, String close, String? court, int m) =>
      'Mô phỏng lưới thời gian trong ngày ($open - $close) • ${court == null ? '' : '$court: '}$m phút / ca';
  static const List<int> slotMinuteOptions = [30, 45, 60, 90, 120, 150, 180, 240];

  // Form sân con
  static const String addCourtTitle = 'Thêm sân mới';
  static String editCourtTitle(String name) => 'Sửa $name';
  static const String addCourtHint = 'Sau khi thêm, vào trang Ca sân để sinh ca cho sân này.';
  static const String editCourtHint = 'Thông tin để trống sẽ được xóa khỏi sân.';
  static String courtStats(int? free, int? minutes, int? minPrice, int? maxPrice) => [
        if (free != null) '$free ca trống 7 ngày tới',
        if (minutes != null) 'Thời lượng áp dụng: $minutes phút',
        if (minPrice != null)
          'Giá sắp tới: ${Formatters.currency(minPrice)}–${Formatters.currency(maxPrice ?? minPrice)} Điểm',
      ].join(' • ');
  static const String sport = 'Bộ môn *';
  static const String loadingSports = 'Đang tải…';
  static const String courtName = 'Tên sân *';
  static const String courtNameHint = 'VD: Sân 1';
  static const String defaultPrice = 'Giá mặc định / giờ (đ) *';
  static const String courtType = 'Loại sân';
  static const String courtTypeHint = 'VD: Sân 5 người';
  static const String notDeclared = 'Chưa khai báo';
  static String legacy(String v) => '$v (dữ liệu cũ)';
  static const String surface = 'Mặt sân';
  static const String surfaceHint = 'VD: Thảm PU, cỏ nhân tạo';
  static const String indoor = 'Trong nhà / ngoài trời';
  static const String indoorYes = 'Trong nhà';
  static const String indoorNo = 'Ngoài trời';
  static const String maxPlayers = 'Số người tối đa';
  static const String teamSize = 'Số người mỗi đội';
  static String people(int n) => '$n người';
  static const String slotMinutes = 'Thời lượng mỗi ca';
  static const String cancel = 'Hủy';
  static const String save = 'Lưu thay đổi';
  static const String create = 'Thêm sân';
  static const String errSport = 'Vui lòng chọn bộ môn.';
  static const String errName = 'Vui lòng nhập tên sân.';
  static const String errPrice = 'Giá mặc định không hợp lệ.';
  static const String errMaxPlayers = 'Số người tối đa phải từ 1 đến 100.';
  static const String errTeamSize = 'Số người mỗi đội phải từ 1 đến 15.';

  // ---------------- Ca sân ----------------
  static const String slotsTitle = 'Ca sân';
  static String slotsSubtitle(String facility) => 'Sinh ca, khóa / mở, đổi giá và xóa ca của $facility.';
  static const String weekTitle = 'Lịch 7 ngày';
  static const String prevWeek = 'Tuần trước';
  static const String nextWeek = 'Tuần sau';
  static const String today = 'Hôm nay';
  static String allSportsChip(int n) => 'Tất cả ($n sân)';
  static String sportChip(String sport, int n) => '$sport ($n sân)';
  static String availabilityToday(int slots, int bookable, int total) =>
      'Khách tìm sân hôm nay đặt được: $slots ca trống trên $bookable/$total sân.';
  static const String wholeFacilityNote = 'Số liệu dưới đây tính cho toàn cơ sở.';
  static const String statTotal = 'Tổng ca';
  static const String statBooked = 'Đã đặt';
  static const String statFree = 'Còn trống';
  static const String statLocked = 'Đã khóa';
  static const String statReserved = 'Giữ cho giải';
  static const String loadingWeek = 'Đang tải lịch…';
  static const String noCourtsYet = 'Cơ sở chưa có sân con. Thêm sân ở mục Sân & giá.';
  static String dayCell(int total) => '$total ca';
  static String dayCellSub(int booked, int free) => '$booked đặt • $free trống';
  static String dayTitle(String court, String date) => '$court • $date';
  static String daySlotsCount(int n) => '$n ca';
  static String deleteSlotConfirm(String time) => 'Xóa ca $time?';
  static const String slotDeleted = 'Đã xóa ca.';
  static const String past = 'Đã qua';

  /// Nhãn trạng thái ca (src/CourtOwner/shared.js).
  static String slotStatus(String s) => switch (s) {
        'AVAILABLE' => 'Còn trống',
        'LOCKING' => 'Đang giữ chỗ',
        'BOOKED' => 'Đã đặt',
        'LOCKED' => 'Đã khóa',
        'MAINTENANCE' => 'Bảo trì',
        'RESERVED' => 'Giữ cho giải',
        '' => '—',
        _ => s,
      };

  // Sinh ca hàng loạt
  static const String generateTitle = 'Sinh ca hàng loạt';
  static const String allCourts = 'Tất cả sân';
  static String allCourtsOf(String sport) => 'Tất cả sân $sport';
  static const String fromDate = 'Từ ngày';
  static const String toDate = 'Đến ngày';
  static const String openAt = 'Giờ mở';
  static const String closeAt = 'Giờ đóng';
  static const String duration = 'Mỗi ca (phút)';
  static const String durationHint = 'Theo sân';
  static const String slotPrice = 'Giá mỗi ca (đ)';
  static const String slotPriceHint = 'Giá mặc định';
  static const String priceRules = 'Khung giá riêng (giờ vàng / cuối tuần):';
  static const String addRule = '+ Thêm khung giá';
  static const String ruleFrom = 'Từ giờ';
  static const String ruleTo = 'Đến giờ';
  static const String rulePrice = 'Giá (đ)';
  static const String rulePriceHint = 'VD: 150000';
  static const String generate = 'Sinh ca';
  static const String generating = 'Đang sinh…';
  static const String errDateOrder = 'Ngày kết thúc phải sau ngày bắt đầu.';
  static const String errHourOrder = 'Giờ đóng phải sau giờ mở.';
  static const String errDuration = 'Thời lượng mỗi ca phải là số nguyên từ 15 đến 480 phút.';
  static const String errSlotPrice = 'Giá mỗi ca không hợp lệ.';
  static String errRuleTime(int i) => 'Khung giá riêng #$i: giờ kết thúc phải sau giờ bắt đầu.';
  static String errRulePrice(int i) => 'Khung giá riêng #$i: vui lòng nhập giá hợp lệ.';
  static const String generateAllFailed = 'Không sinh được ca nào. Kiểm tra chi tiết bên dưới.';
  static String generatePartial(int created, int failed) => 'Đã tạo $created ca mới ($failed sân không thành công).';
  static String generated(int created) => created > 0 ? 'Đã sinh $created ca mới.' : 'Đã sinh ca.';
  static String resultRow(int created, int updated, int skipped, int past) =>
      'Tạo mới $created • Cập nhật $updated • Bỏ qua $skipped • Đã qua $past';

  // Chọn thứ
  static const String weekDays = 'Áp dụng các thứ';
  static const String everyDay = 'Mọi ngày';
  static const String pickDays = 'Chọn thứ trong tuần';
  static String picking(String summary) => 'Đang chọn: $summary';
  static const String weekdaysPreset = 'T2 – T6';
  static const String weekendPreset = 'Cuối tuần (T7 – CN)';

  // Thao tác hàng loạt
  static const String bulkTitle = 'Thao tác hàng loạt';
  static const String bulkLock = 'Khóa ca trống';
  static const String bulkUnlock = 'Mở lại ca đã khóa';
  static const String bulkPrice = 'Đổi giá';
  static const String bulkDelete = 'Xóa ca';
  static const String newPrice = 'Giá mới (đ)';
  static const String processing = 'Đang xử lý…';
  static const String errNewPrice = 'Vui lòng nhập giá mới.';
  static const String bulkDeleteConfirm = 'Xóa mọi ca trống khớp bộ lọc? Không hoàn tác được.';
  static const String overlapTitle = 'Trùng đợt giá đặc biệt';
  static String overlapBody(String lines) =>
      'Các sân sau đang áp dụng tuần lễ vàng / giá đặc biệt:\n$lines\n\nĐổi giá sẽ ghi đè giá của đợt trên các ca còn trống. Vẫn tiếp tục?';
  static const String overlapYes = 'Vẫn đổi giá';
  static const String overlapNo = 'Không đổi';
  static String bulkDone(int matched, int affected, int skipped) =>
      'Khớp $matched ca • đã áp dụng $affected • bỏ qua $skipped.';

  // Đợt giá đặc biệt
  static const String periodsTitle = 'Tuần lễ vàng / Giá ngày đặc biệt';
  static const String periodsHint =
      'Đặt giá riêng cho vài ngày: sale dịp lễ, cuối năm hoặc phụ thu Tết. Người chơi thấy tên đợt trên ca.';
  static const String newPeriod = '+ Tạo đợt giá';
  static const String periodsLoading = 'Đang tải đợt giá…';
  static const String periodsUnavailable = 'Tính năng đang chờ hệ thống cập nhật, sẽ dùng được khi hoàn tất.';
  static const String periodsUnavailableSave = 'Hệ thống chưa hỗ trợ lưu đợt giá (đang chờ cập nhật).';
  static const String periodsEmpty = 'Chưa có đợt giá nào sắp diễn ra.';
  static const String periodName = 'Tên đợt';
  static const String periodNameHint = 'VD: Phụ thu Tết, Sale cuối năm';
  static const String periodPrice = 'Giá mỗi ca (đ)';
  static const String periodPriceHint = 'VD: 130000';
  static const String periodFromTime = 'Từ giờ (trống = cả ngày)';
  static const String periodToTime = 'Đến giờ';
  static const String periodNote = 'Áp dụng cho các ca còn trống trong đợt; ca đã có khách đặt giữ nguyên giá cũ.';
  static const String savePeriod = 'Lưu đợt giá';
  static const String wholeDay = 'Cả ngày';
  static const String deletedCourt = 'Sân đã xóa';
  static const String errPeriodName = 'Vui lòng đặt tên đợt (vd: Phụ thu Tết, Sale cuối năm).';
  static const String errPeriodOrder = 'Đến ngày phải từ ngày bắt đầu trở đi.';
  static const String errPeriodTimes = 'Nhập đủ cả giờ bắt đầu và giờ kết thúc, hoặc để trống cả hai (cả ngày).';
  static const String errPeriodTimeOrder = 'Giờ kết thúc phải sau giờ bắt đầu.';
  static const String errPeriodPrice = 'Vui lòng nhập giá mỗi ca.';
  static String periodSaved(bool editing, String name, int? updated, int? skipped) =>
      '${editing ? 'Đã cập nhật' : 'Đã tạo'} đợt "$name".'
      '${updated != null || skipped != null ? ' Đã đổi giá ${updated ?? 0} ca trống, giữ nguyên ${skipped ?? 0} ca đã có khách.' : ''}';
  static String deletePeriodConfirm(String name) => 'Xóa đợt "$name"? Các ca còn trống trong đợt sẽ trở về giá thường.';
  static String periodDeleted(String name) => 'Đã xóa đợt "$name".';

  // Chung
  static const String confirm = 'Đồng ý';
  static const String close = 'Đóng';
  static const String timeEmpty = '--:--';
}
