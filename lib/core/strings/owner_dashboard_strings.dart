import '../utils/formatters.dart';

/// Chuỗi hiển thị cho Tổng quan Chủ sân (theo Web: CourtOwner/Dashboard).
class OwnerDashboardStrings {
  OwnerDashboardStrings._();

  static const String title = 'Tổng quan';
  static String subtitle(String? facility, int days) => '${facility == null ? '' : '$facility • '}Số liệu $days ngày gần nhất';
  static String subtitleStats(String cancelPct, int reviews, String rating) => ' • $cancelPct đơn bị hủy • $reviews đánh giá ($rating★)';
  static String loadError(String m) => 'Không tải được thống kê: $m';
  static String periodDays(int d) => '$d ngày';
  static String courtsReady(int active, int total) => '$active/$total sân sẵn sàng';
  static String openReportsPill(int n) => ' • $n khiếu nại mở';
  static const String loading = 'Đang tải...';
  static const String dash = '—';

  // KPI
  static const String kpiBalance = 'Số dư khả dụng';
  static String kpiFrozen(String v) => 'Đang tạm giữ: $v';
  static String kpiBookings(int d) => 'Đơn đặt sân ($d ngày)';
  static String kpiBookingsSub(int checked, int cancelled, int upcoming) =>
      '$checked đã check-in • $cancelled đã hủy • $upcoming đơn sắp tới hôm nay';
  static const String unitBookings = 'đơn';
  static String kpiOccupancy(int d) => 'Tỷ lệ lấp đầy ($d ngày)';
  static String occupancySlots(int booked, int sellable) => '($booked/$sellable ca)';
  static String peakHour(int h, int n) => '🔥 Khung giờ đông nhất: ${h.toString().padLeft(2, '0')}:00 ($n đơn)';
  static const String occupancyHint = 'Ca đã có người đặt / ca mở bán';
  static String kpiRevenue(int d) => 'Doanh thu ($d ngày)';
  static String revenueSub(String online, String walkIn) => 'Online $online • Tại quầy $walkIn';
  static const String revenueHint = 'Đơn đã thanh toán + phí hủy';

  // Doanh thu theo ngày
  static const String revenueChart = 'Doanh thu theo ngày';
  static String revenueChartSub(int days, String total, String? best) =>
      '$days ngày gần nhất • Tổng $total${best == null ? '' : ' • Cao nhất $best'}';
  static const String noDataPeriod = 'Chưa có dữ liệu trong kỳ';
  static String noRevenue(int d) => 'Chưa có doanh thu trong $d ngày gần nhất';
  static const String noRevenueHint = 'Biểu đồ sẽ hiện khi cơ sở có đơn đặt sân đã thanh toán.';
  static const String showTable = 'Xem dạng bảng';
  static const String showChart = 'Xem biểu đồ';
  static const String colDay = 'Ngày';
  static const String colBookings = 'Số đơn';
  static const String colRevenue = 'Doanh thu';
  static String dayDetail(String day, String revenue, int n) => 'Ngày $day: $revenue • $n đơn';
  static const String tapBarHint = 'Chạm vào cột để xem chi tiết ngày.';

  // Việc cần xử lý
  static const String todoTitle = 'Việc cần xử lý';
  static const String todoSub = 'Những mục đang chờ bạn hành động';
  static const String allGood = 'Mọi thứ đều ổn';
  static String todoCheckin(int n) => '$n đơn chờ check-in hôm nay';
  static const String todoCheckinDesc = 'Quét QR hoặc check-in thủ công khi khách tới';
  static const String actionScan = 'Quét QR';
  static String todoReports(int n) => '$n khiếu nại đang mở';
  static const String todoReportsDesc = 'Người chơi đang chờ chủ sân phản hồi';
  static String todoRejected(int n) => '$n cơ sở bị từ chối duyệt';
  static const String actionReview = 'Xem lại';
  static String todoPending(int n) => '$n cơ sở đang chờ admin duyệt';
  static const String actionView = 'Xem';
  static String todoInactive(int n) => '$n sân đang tạm ngưng';
  static const String todoInactiveDesc = 'Mở lại sân khi đã bảo trì xong';
  static const String actionOpenCourt = 'Mở sân';

  // So sánh kỳ
  static String compareTitle(String unit) => 'So sánh số đơn theo $unit';
  static String compareSub(String prev, String cur) => '$prev và $cur • số đơn cộng dồn theo ngày';
  static const String compareLoading = 'Đang tải dữ liệu so sánh...';
  static String compareError(String m) => 'Không tải được dữ liệu: $m';
  static String compareCurrent(String label) => '$label (tới hôm nay)';
  static String comparePrevious(String label) => '$label (cả kỳ)';
  static String compareChange(String unit) => 'So với cùng mốc $unit trước';
  static String bookingsCount(int n) => '${Formatters.currency(n)} đơn';
  static String compareEmpty(String prev, String cur) => 'Chưa có đơn đặt sân trong $prev và $cur.';
  static String compareNote(String cur, int same, String prev, int day) =>
      '% thay đổi so sánh $cur với ${Formatters.currency(same)} đơn của $prev tính tới cùng ngày thứ $day.';

  // Số đơn theo từng sân
  static const String courtBookingsTitle = 'Số đơn theo từng sân';
  static String courtBookingsSub(int d, int total, int courts) => '$d ngày gần nhất • $total đơn / $courts sân';
  static const String noCourts = 'Cơ sở chưa có sân nào.';
  static String noBookings(int d) => 'Chưa có đơn đặt sân trong $d ngày gần nhất.';
  static String occupancyHintPct(int pct) => 'lấp đầy $pct%';

  // Khách hôm nay
  static const String todayTitle = 'Khách đặt sân hôm nay';
  static String todaySub(int waiting, int checked) => '$waiting đơn chờ check-in • $checked đã check-in';
  static const String todayEmpty = 'Hôm nay chưa có đơn đặt sân nào.';
  static const String scanLink = 'Quét QR';
  static const String checkedIn = '✓ Đã check-in';
  static const String scanNow = 'Quét QR ngay';
  static String timeRange(String range) => 'Khung giờ: $range';
  static String viewAllToday(int n) => 'Xem tất cả $n đơn hôm nay';
  static const String guest = 'Khách hàng';

  // Hiệu quả từng sân
  static const String courtPerfTitle = 'Hiệu quả từng sân';
  static String courtPerfSub(int d) => 'Tỷ lệ lấp đầy và doanh thu $d ngày gần nhất';
  static const String manageCourts = 'Quản lý sân';
  static const String noCourtData = 'Chưa có dữ liệu đặt sân trong kỳ.';
  static String fillPct(int pct) => 'Lấp đầy $pct%';
  static String courtMeta(int bookings, int booked, int sellable) => '$bookings đơn • $booked/$sellable ca';
  static String viewGrid(int courts) => 'Xem chi tiết lưới lịch $courts sân';

  // Bảng doanh thu từng sân con
  static const String tableTitle = 'Thống kê doanh thu từng sân con';
  static String tableSub(String from, String to) => 'Chi tiết số đơn, tỷ lệ lấp đầy và doanh thu từng sân từ $from đến $to';
  static const String fromDate = 'Từ ngày';
  static const String toDate = 'Đến ngày';
  static String resetRange(int d) => 'Theo kỳ ($d ngày)';
  static const String invalidRange = 'Ngày kết thúc phải bằng hoặc sau ngày bắt đầu.';
  static const String tableLoading = 'Đang tải thống kê doanh thu từng sân con...';
  static const String tableEmpty = 'Chưa có dữ liệu doanh thu từng sân trong khoảng thời gian này.';
  static const String colSlots = 'Ca đã đặt / Mở bán';
  static const String colOccupancy = 'Tỷ lệ lấp đầy';
  static String totalRow(int n) => 'Tổng cộng ($n sân)';
}
