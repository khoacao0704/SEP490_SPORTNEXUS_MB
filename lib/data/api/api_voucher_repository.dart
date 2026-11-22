import '../../models/voucher.dart';
import '../repositories/voucher_repository.dart';
import 'api_client.dart';

/// [VoucherRepository] gọi Backend thật.
///
/// GET /api/v1/wallet/vouchers?status=ACTIVE|USED|EXPIRED → mảng voucher (không phân trang, mới nhất trước;
/// không có mã thì mảng rỗng). Mỗi voucher: id, discountPercent, status, expiredDate, sourceBookingId, createdAt.
class ApiVoucherRepository implements VoucherRepository {
  static const String vouchersPath = '/api/v1/wallet/vouchers';

  final ApiClient _api;

  ApiVoucherRepository({required this._api});

  @override
  Future<List<Voucher>> getMyVouchers({VoucherStatus? status}) async {
    final Object? data;
    try {
      data = await _api.get(vouchersPath, query: {'status': ?status?.apiValue});
    } on ApiException catch (e) {
      throw VoucherException(e.message);
    }
    final list = data is List ? data : const [];
    return [
      for (final m in list)
        if (m is Map<String, dynamic>) voucherFromApi(m),
    ];
  }

  static Voucher voucherFromApi(Map<String, dynamic> m) {
    final createdAt = _time(m['createdAt']) ?? DateTime.now();
    return Voucher(
      id: m['id'].toString(),
      discountPercent: (m['discountPercent'] as num?)?.round() ?? 0,
      status: VoucherStatus.fromApi(m['status'] as String?),
      expiresAt: _time(m['expiredDate'] ?? m['expiryDate'] ?? m['expiresAt']) ?? createdAt,
      sourceBookingId: m['sourceBookingId']?.toString(),
      createdAt: createdAt,
    );
  }

  static DateTime? _time(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
