import '../../models/voucher.dart';
import '../repositories/voucher_repository.dart';

/// Bản giả lập [VoucherRepository]: vài mã đền bù mẫu (giống BE: chủ sân hủy đơn → giảm 10%, hạn 30 ngày).
class MockVoucherRepository implements VoucherRepository {
  final List<Voucher> _vouchers;

  MockVoucherRepository({List<Voucher>? vouchers}) : _vouchers = vouchers ?? _samples(DateTime.now());

  @override
  Future<List<Voucher>> getMyVouchers({VoucherStatus? status}) async {
    final now = DateTime.now();
    // Như BE: mã còn dùng mà quá hạn thì trả về là đã hết hạn.
    final items = _vouchers
        .map((v) => v.status == VoucherStatus.active && !v.expiresAt.isAfter(now)
            ? Voucher(
                id: v.id,
                discountPercent: v.discountPercent,
                status: VoucherStatus.expired,
                expiresAt: v.expiresAt,
                sourceBookingId: v.sourceBookingId,
                createdAt: v.createdAt,
              )
            : v)
        .where((v) => status == null || v.status == status)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static List<Voucher> _samples(DateTime now) {
    Voucher make(String id, int ageDays, VoucherStatus status) {
      final createdAt = now.subtract(Duration(days: ageDays));
      return Voucher(
        id: id,
        discountPercent: 10,
        status: status,
        expiresAt: createdAt.add(const Duration(days: 30)),
        sourceBookingId: 'mock-booking-$id',
        createdAt: createdAt,
      );
    }

    return [
      make('v1', 2, VoucherStatus.active),
      make('v2', 25, VoucherStatus.active),
      make('v3', 12, VoucherStatus.used),
      make('v4', 40, VoucherStatus.active),
    ];
  }
}
