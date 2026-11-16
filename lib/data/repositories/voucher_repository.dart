import '../../models/voucher.dart';

/// Lỗi tải mã giảm giá; [message] sẵn sàng để hiển thị.
class VoucherException implements Exception {
  final String message;

  const VoucherException(this.message);

  @override
  String toString() => 'VoucherException: $message';
}

/// Mã giảm giá của người chơi (chỉ xem; chưa áp khi đặt sân).
abstract class VoucherRepository {
  /// Mã của tài khoản đang đăng nhập, mới nhất trước. [status] `null` = tất cả trạng thái.
  Future<List<Voucher>> getMyVouchers({VoucherStatus? status});
}
