import 'owner_court.dart' show dayKey;

int _int(Object? v) => (v as num?)?.round() ?? 0;
double? _dbl(Object? v) => (v as num?)?.toDouble();

/// Một ngày trong revenueByDay.
class DayStat {
  final DateTime date;
  final int revenue;
  final int bookings;

  const DayStat({required this.date, required this.revenue, required this.bookings});

  factory DayStat.fromJson(Map<String, dynamic> j) {
    final s = '${j['date'] ?? ''}';
    final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s) ?? DateTime(1970);
    return DayStat(date: DateTime(d.year, d.month, d.day), revenue: _int(j['revenue']), bookings: _int(j['bookings']));
  }
}

/// Một sân con trong revenueByCourt.
class CourtStat {
  final String courtId;
  final String courtName;
  final int bookings;
  final int bookedSlots;
  final int sellableSlots;
  final int revenue;

  const CourtStat({
    required this.courtId,
    required this.courtName,
    required this.bookings,
    required this.bookedSlots,
    required this.sellableSlots,
    required this.revenue,
  });

  /// Lấp đầy (%) như Web: ca đã đặt / ca mở bán, làm tròn.
  int get occupancy => sellableSlots == 0 ? 0 : (bookedSlots * 100 / sellableSlots).round();

  factory CourtStat.fromJson(Map<String, dynamic> j) => CourtStat(
        courtId: '${j['courtId'] ?? ''}',
        courtName: '${j['courtName'] ?? ''}',
        bookings: _int(j['bookings']),
        bookedSlots: _int(j['bookedSlots']),
        sellableSlots: _int(j['sellableSlots']),
        revenue: _int(j['revenue']),
      );
}

/// GET /owner/dashboard?FacilityId&From&To — các trường Web đang đọc.
class OwnerDashboard {
  final int totalBookings;
  final int checkedInBookings;
  final int cancelledBookings;
  final int upcomingTodayBookings;
  final double? occupancyRate;
  final int bookedSlots;
  final int sellableSlots;
  final int totalRevenue;
  final int onlineRevenue;
  final int walkInRevenue;
  final double? cancellationRate;
  final int reviewCount;
  final double averageRating;
  final int openReports;

  /// Giờ (0..23) → số đơn.
  final Map<int, int> bookingsByHour;
  final List<DayStat> revenueByDay;
  final List<CourtStat> revenueByCourt;

  const OwnerDashboard({
    this.totalBookings = 0,
    this.checkedInBookings = 0,
    this.cancelledBookings = 0,
    this.upcomingTodayBookings = 0,
    this.occupancyRate,
    this.bookedSlots = 0,
    this.sellableSlots = 0,
    this.totalRevenue = 0,
    this.onlineRevenue = 0,
    this.walkInRevenue = 0,
    this.cancellationRate,
    this.reviewCount = 0,
    this.averageRating = 0,
    this.openReports = 0,
    this.bookingsByHour = const {},
    this.revenueByDay = const [],
    this.revenueByCourt = const [],
  });

  /// Khung giờ đông nhất (giờ, số đơn); null khi chưa có đơn.
  (int, int)? get peakHour {
    (int, int)? best;
    bookingsByHour.forEach((h, n) {
      if (n > 0 && (best == null || n > best!.$2)) best = (h, n);
    });
    return best;
  }

  factory OwnerDashboard.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(Object? v) =>
        v is List ? [for (final e in v.whereType<Map>()) Map<String, dynamic>.from(e)] : const [];
    return OwnerDashboard(
      totalBookings: _int(j['totalBookings']),
      checkedInBookings: _int(j['checkedInBookings']),
      cancelledBookings: _int(j['cancelledBookings']),
      upcomingTodayBookings: _int(j['upcomingTodayBookings']),
      occupancyRate: _dbl(j['occupancyRate']),
      bookedSlots: _int(j['bookedSlots']),
      sellableSlots: _int(j['sellableSlots']),
      totalRevenue: _int(j['totalRevenue']),
      onlineRevenue: _int(j['onlineRevenue']),
      walkInRevenue: _int(j['walkInRevenue']),
      cancellationRate: _dbl(j['cancellationRate']),
      reviewCount: _int(j['reviewCount']),
      averageRating: _dbl(j['averageRating']) ?? 0,
      openReports: _int(j['openReports']),
      bookingsByHour: {for (final h in list(j['bookingsByHour'])) _int(h['hour']): _int(h['bookings'])},
      revenueByDay: [for (final d in list(j['revenueByDay'])) DayStat.fromJson(d)],
      revenueByCourt: [for (final c in list(j['revenueByCourt'])) CourtStat.fromJson(c)],
    );
  }
}

// ---------------- So sánh kỳ (utils/periodCompare.js của Web) ----------------

enum CompareKind {
  month('Tháng'),
  quarter('Quý');

  const CompareKind(this.label);

  final String label;
}

class ComparePeriod {
  final DateTime from;
  final DateTime to;

  /// Số ngày cả kỳ.
  final int length;

  /// Kỳ hiện tại: số ngày đã qua tính cả hôm nay.
  final int elapsed;
  final String label;

  const ComparePeriod({required this.from, required this.to, required this.length, required this.elapsed, required this.label});
}

/// Kỳ hiện tại (tới hôm nay) và kỳ trước (trọn kỳ).
(ComparePeriod current, ComparePeriod previous) comparePeriods(CompareKind kind, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final span = kind == CompareKind.quarter ? 3 : 1;
  final startMonth = (today.month - 1) ~/ span * span + 1;
  final curFrom = DateTime(today.year, startMonth, 1);
  final curEnd = DateTime(today.year, startMonth + span, 0);
  final prevFrom = DateTime(today.year, startMonth - span, 1);
  final prevTo = DateTime(curFrom.year, curFrom.month, curFrom.day - 1);
  int days(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  String label(DateTime d) =>
      kind == CompareKind.quarter ? 'Quý ${(d.month - 1) ~/ 3 + 1}/${d.year}' : 'Tháng ${d.month}/${d.year}';
  return (
    ComparePeriod(from: curFrom, to: today, length: days(curFrom, curEnd) + 1, elapsed: days(curFrom, today) + 1, label: label(curFrom)),
    ComparePeriod(from: prevFrom, to: prevTo, length: days(prevFrom, prevTo) + 1, elapsed: days(prevFrom, prevTo) + 1, label: label(prevFrom)),
  );
}

/// Số đơn cộng dồn theo ngày trong kỳ ([length] ngày đầu).
List<int> cumulativeBookings(List<DayStat> days, DateTime from, int length) {
  final per = List.filled(length, 0);
  final start = DateTime.utc(from.year, from.month, from.day);
  for (final d in days) {
    final i = DateTime.utc(d.date.year, d.date.month, d.date.day).difference(start).inDays;
    if (i >= 0 && i < length) per[i] += d.bookings;
  }
  var sum = 0;
  return [for (final v in per) sum += v];
}

/// Kết quả so sánh: kỳ này (tới hôm nay), cả kỳ trước, kỳ trước tới cùng mốc, % thay đổi.
class ComparisonSummary {
  final List<int> previous;
  final List<int> current;
  final int currentTotal;
  final int previousTotal;
  final int previousSameDay;
  final double? change;

  const ComparisonSummary({
    required this.previous,
    required this.current,
    required this.currentTotal,
    required this.previousTotal,
    required this.previousSameDay,
    required this.change,
  });

  factory ComparisonSummary.of(ComparePeriod cur, ComparePeriod prev, List<DayStat> curDays, List<DayStat> prevDays) {
    final p = cumulativeBookings(prevDays, prev.from, prev.length);
    final c = cumulativeBookings(curDays, cur.from, cur.elapsed);
    final current = c.isEmpty ? 0 : c.last;
    final prevTotal = p.isEmpty ? 0 : p.last;
    final same = p.isEmpty ? 0 : p[(cur.elapsed < p.length ? cur.elapsed : p.length) - 1];
    return ComparisonSummary(
      previous: p,
      current: c,
      currentTotal: current,
      previousTotal: prevTotal,
      previousSameDay: same,
      change: same > 0 ? (current - same) * 100 / same : null,
    );
  }
}

/// Ngày dạng yyyy-MM-dd gửi lên BE.
String dashboardDay(DateTime d) => dayKey(d);
