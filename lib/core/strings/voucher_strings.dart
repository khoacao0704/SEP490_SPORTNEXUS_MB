/// Chuỗi hiển thị cho mã giảm giá (Voucher của tôi).
class VoucherStrings {
  VoucherStrings._();

  static const String title = 'Voucher của tôi';
  static const String tabActive = 'Còn dùng';
  static const String tabUsed = 'Đã dùng';
  static const String tabExpired = 'Hết hạn';

  static String discount(int percent) => 'Giảm $percent%';
  static const String compensation = 'Đền bù đơn bị chủ sân hủy';
  static String expiresOn(String date) => 'HSD: $date';
  static String receivedOn(String date) => 'Nhận ngày $date';

  static const String statusUsed = 'Đã dùng';
  static const String statusExpired = 'Hết hạn';

  static const String emptyActive = 'Bạn chưa có mã giảm giá nào';
  static const String emptyUsed = 'Chưa dùng mã giảm giá nào';
  static const String emptyExpired = 'Không có mã giảm giá hết hạn';

  static const String loadError = 'Không tải được mã giảm giá. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
