import '../../models/owner_finance.dart';

/// Doanh thu mẫu của Chủ sân demo: từ ngày 1 của hai tháng trước tới hết hôm qua (số liệu cố định theo ngày).
/// Doanh thu hôm nay lấy từ các lượt sân check-out / vắng mặt thật trong bản giả lập.
class MockOwnerFinanceData {
  MockOwnerFinanceData._();

  static const _tt = (id: 'f-hcm-thientrieu', name: 'Sân Cầu Lông Thiên Triều');
  static const _hl = (id: 'f-hcm-hoalu', name: 'Sân Bóng Hoa Lư');

  static int _round1000(double v) => (v / 1000).round() * 1000;

  static DateTime firstMonth(DateTime now) => DateTime(now.year, now.month - 2, 1);

  static List<RevenueItem> seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final items = <RevenueItem>[];
    var i = 0;
    for (var d = firstMonth(now); d.isBefore(today); d = DateTime(d.year, d.month, d.day + 1), i++) {
      final key = '${d.year}${d.month}${d.day}';
      final ttSessions = 6 + (i * 7) % 5;
      final ttAmount = ttSessions * 150000;
      items.add(RevenueItem(
        id: 'rv-tt-$key',
        date: d,
        facilityId: _tt.id,
        facilityName: _tt.name,
        kind: RevenueKind.courtFee,
        amount: ttAmount,
        viaApp: _round1000(ttAmount * 0.7),
        sessions: ttSessions,
      ));
      final hlSessions = 2 + (i * 3) % 3;
      final hlAmount = hlSessions * 650000;
      items.add(RevenueItem(
        id: 'rv-hl-$key',
        date: d,
        facilityId: _hl.id,
        facilityName: _hl.name,
        kind: RevenueKind.courtFee,
        amount: hlAmount,
        viaApp: _round1000(hlAmount * 0.6),
        sessions: hlSessions,
      ));
      if (i % 6 == 2) {
        items.add(RevenueItem(
          id: 'rv-pen-$key',
          date: d,
          facilityId: _hl.id,
          facilityName: _hl.name,
          kind: RevenueKind.penalty,
          amount: 125000,
          viaApp: 125000,
          description: 'Hủy trong 24 giờ',
        ));
      }
    }
    return items;
  }
}
