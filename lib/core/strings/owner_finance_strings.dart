import '../utils/formatters.dart';

/// Chuỗi hiển thị cho Doanh thu, Ví và Phí duy trì của Chủ sân.
class OwnerFinanceStrings {
  OwnerFinanceStrings._();

  static String monthLabel(DateTime m) => 'Tháng ${m.month}/${m.year}';
  static String monthShort(DateTime m) => 'tháng ${m.month}/${m.year}';
  static String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // Doanh thu & Ví
  static const String title = 'Doanh Thu & Ví';
  static const String walletBalance = 'Số dư ví';
  static String pendingWithdrawal(int amount) => 'Đang chờ rút ${Formatters.vnd(amount)}';
  static const String withdraw = 'Rút tiền';
  static const String history = 'Lịch sử giao dịch';
  static const String revenue = 'Doanh thu';
  static const String totalRevenue = 'Tổng doanh thu';
  static const String viaApp = 'Qua app (vào ví)';
  static const String atCourt = 'Tự thu tại sân';
  static const String penalties = 'Tiền phạt hủy / vắng';
  static String sessions(int n) => '$n lượt sân';
  static const String estimatedFee = 'Phí duy trì tạm tính (10%)';
  static const String feeNote = 'Phí tính trên toàn bộ tiền sân, kể cả phần bạn tự thu tại sân.';
  static const String dailyChart = 'Doanh thu theo ngày';
  static const String chartHint = 'Chạm vào cột để xem số tiền.';
  static String chartTooltip(int day, int month, int amount) => '$day/$month: ${Formatters.vnd(amount)}';
  static const String byFacility = 'Theo cơ sở';
  static const String noRevenue = 'Chưa có doanh thu trong tháng này.';
  static const String loadError = 'Không tải được dữ liệu. Kéo xuống để thử lại.';

  // Phí duy trì
  static const String feeTitle = 'Phí Duy Trì Hàng Tháng';
  static const String feeRule =
      'Ngày 1 hàng tháng hệ thống chốt phí tháng trước = 10% tổng doanh thu. Hạn trả hết ngày 7. '
      'Quá hạn: tất cả cơ sở bị ẩn khỏi tìm kiếm và không rút tiền được cho tới khi trả xong. '
      'Lượt đã đặt vẫn diễn ra bình thường.';
  static String currentMonth(DateTime m) => 'Tạm tính ${monthShort(m)}';
  static String currentMonthNote(DateTime due) => 'Chốt ngày 01, hạn trả ${date(due)}';
  static const String bills = 'Các tháng đã chốt';
  static const String noBills = 'Chưa có phí nào được chốt.';
  static String billRevenue(int revenue) => 'Doanh thu ${Formatters.vnd(revenue)}';
  static String dueOn(DateTime d) => 'Hạn ${date(d)}';
  static String paidOn(DateTime d) => 'Đã trả ${date(d)}';
  static const String statusDue = 'Chưa trả';
  static const String statusOverdue = 'Quá hạn';
  static const String statusPaid = 'Đã trả';
  static const String pay = 'Trả phí';

  // Trả phí
  static String payTitle(DateTime m) => 'Trả phí ${monthShort(m)}';
  static const String payByWallet = 'Trừ vào ví';
  static String walletBalanceNote(int balance) => 'Số dư hiện tại ${Formatters.vnd(balance)}';
  static const String payByVietQr = 'Chuyển khoản VietQR';
  static const String vietQrNote = 'Quét mã bằng app ngân hàng, hệ thống xác nhận rồi trừ phí.';
  static const String insufficient = 'Số dư ví không đủ';
  static String paid(int amount) => 'Đã trả phí ${Formatters.vnd(amount)}.';
  static const String alreadyPaid = 'Phí tháng này đã được trả.';
  static const String billNotFound = 'Không tìm thấy hóa đơn phí.';

  // Cảnh báo
  static String overdueBanner(DateTime m, int amount) =>
      'Các cơ sở của bạn đang bị ẩn vì chưa trả phí ${monthShort(m)} (${Formatters.vnd(amount)}).';
  static String dueBanner(DateTime m, int amount, DateTime due) =>
      'Phí ${monthShort(m)}: ${Formatters.vnd(amount)}, hạn ${date(due)}. Quá hạn các cơ sở sẽ bị ẩn.';
  static const String withdrawBlockedTitle = 'Chưa rút tiền được';
  static const String withdrawBlocked = 'Bạn đang nợ phí duy trì quá hạn. Hãy trả phí trước rồi rút tiền.';
  static const String close = 'Đóng';
}
