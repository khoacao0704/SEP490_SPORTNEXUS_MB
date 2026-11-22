/// Trạng thái mã giảm giá. BE tự tính "hết hạn" lúc truy vấn (mã còn dùng mà quá hạn thì trả EXPIRED).
enum VoucherStatus {
  active('ACTIVE'),
  used('USED'),
  expired('EXPIRED');

  const VoucherStatus(this.apiValue);

  final String apiValue;

  static VoucherStatus fromApi(String? value) =>
      values.firstWhere((s) => s.apiValue == value?.toUpperCase(), orElse: () => VoucherStatus.expired);
}

/// Mã giảm giá của người chơi. Hiện BE chỉ cấp một loại: chủ sân hủy đơn thì mỗi người đã trả
/// nhận một mã giảm theo % (đền bù, nền tảng chịu). Chưa áp được khi đặt sân.
class Voucher {
  final String id;

  /// Phần trăm giảm, vd. 10.
  final int discountPercent;
  final VoucherStatus status;
  final DateTime expiresAt;

  /// Đơn bị chủ sân hủy dẫn tới mã đền bù này (`null` nếu cấp vì lý do khác).
  final String? sourceBookingId;
  final DateTime createdAt;

  const Voucher({
    required this.id,
    required this.discountPercent,
    required this.status,
    required this.expiresAt,
    this.sourceBookingId,
    required this.createdAt,
  });
}
