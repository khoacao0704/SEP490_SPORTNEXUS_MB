import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/constants/booking_rules.dart';

/// Luật hoàn khi hủy đặt sân, khớp BE BookingCancelPolicy (24/11/2026).
void main() {
  group('bậc hoàn theo thời gian còn lại', () {
    test('7 ngày 100%, 3 ngày 80%, 48 giờ 50%, dưới 48 giờ 0% (đúng mốc vẫn được bậc cao)', () {
      int p(Duration d) => BookingCancelPolicy.refundPercent(d);
      expect(p(const Duration(days: 10)), 100);
      expect(p(const Duration(days: 7)), 100);
      expect(p(const Duration(days: 7) - const Duration(minutes: 1)), 80);
      expect(p(const Duration(days: 3)), 80);
      expect(p(const Duration(days: 3) - const Duration(minutes: 1)), 50);
      expect(p(const Duration(hours: 48)), 50);
      expect(p(const Duration(hours: 47, minutes: 59)), 0);
      expect(p(Duration.zero), 0);
    });

    test('bậc đang áp kèm hạn: hủy trước mốc đó được % đó; dưới 48 giờ thì không còn bậc', () {
      final start = DateTime(2030, 1, 20, 18);
      final t1 = BookingCancelPolicy.currentTier(start, DateTime(2030, 1, 10))!;
      expect((t1.percent, t1.until), (100, DateTime(2030, 1, 13, 18)));
      final t2 = BookingCancelPolicy.currentTier(start, DateTime(2030, 1, 15))!;
      expect((t2.percent, t2.until), (80, DateTime(2030, 1, 17, 18)));
      final t3 = BookingCancelPolicy.currentTier(start, DateTime(2030, 1, 18))!;
      expect((t3.percent, t3.until), (50, DateTime(2030, 1, 18, 18)));
      expect(BookingCancelPolicy.currentTier(start, DateTime(2030, 1, 19)), isNull);
    });
  });

  group('số tiền hoàn', () {
    test('làm tròn tới Điểm như .NET Math.Round (.5 về số chẵn)', () {
      expect(BookingCancelPolicy.refund(168000, 80), 134400);
      expect(BookingCancelPolicy.refund(100001, 50), 50000); // 50000.5 → 50000 (chẵn)
      expect(BookingCancelPolicy.refund(100003, 50), 50002); // 50001.5 → 50002 (chẵn)
      expect(BookingCancelPolicy.refund(99999, 80), 79999); // 79999.2
      expect(BookingCancelPolicy.refund(120000, 100), 120000);
      expect(BookingCancelPolicy.refund(120000, 0), 0);
    });

    test('chia tiền đã đủ góp: chia theo tỷ lệ phần đã góp, người cuối nhận phần còn lại', () {
      expect(BookingCancelPolicy.split(80000, [50000, 50000]), [40000, 40000]);
      final shares = BookingCancelPolicy.split(10001, [1, 1, 1]);
      expect(shares.reduce((a, b) => a + b), 10001);
      expect(shares, [3334, 3334, 3333]);
      expect(BookingCancelPolicy.split(0, [50000, 50000]), [0, 0]);
    });
  });
}
