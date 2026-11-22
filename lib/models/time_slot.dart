import 'court_type.dart';
import 'sport.dart';

/// Khung giờ do chủ sân cấu hình sẵn, trên một sân con cụ thể; người chơi chỉ chọn trong danh sách này.
class TimeSlot {
  final String id;
  final String facilityId;
  final Sport sport;
  final CourtType courtType;

  /// Sân con người chơi sẽ được xếp vào, vd. "Sân 2".
  final String courtName;
  final DateTime start;
  final DateTime end;
  final int price;

  /// Sân con này còn trống ở khung giờ này (chưa ai đặt, không ai đang giữ chỗ).
  final bool isAvailable;

  const TimeSlot({
    required this.id,
    required this.facilityId,
    required this.sport,
    this.courtType = CourtType.standard,
    required this.courtName,
    required this.start,
    required this.end,
    required this.price,
    required this.isAvailable,
  });

  bool get isFull => !isAvailable;

  bool hasStarted(DateTime now) => !start.isAfter(now);

  bool isBookable(DateTime now) => !isFull && !hasStarted(now);
}

/// Kết quả giữ chỗ 10 phút cho một hoặc nhiều khung giờ trong lúc người chơi thanh toán.
class SlotHold {
  final String holdId;

  /// Các khung giờ đã giữ, sắp theo thời gian bắt đầu.
  final List<TimeSlot> slots;
  final DateTime expiresAt;

  const SlotHold({required this.holdId, required this.slots, required this.expiresAt});

  int get totalPrice => slots.fold(0, (sum, s) => sum + s.price);

  int secondsRemaining(DateTime now) {
    final seconds = expiresAt.difference(now).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}

/// Một sân con thiếu khung giờ so với các sân khác cùng ngày (xem [findCourtsMismatch]).
class CourtsMismatch {
  final DateTime day;
  final String court;

  /// Các khung (bắt đầu, kết thúc) sân này chưa chọn mà sân khác cùng ngày đã chọn.
  final List<(DateTime, DateTime)> missing;

  const CourtsMismatch({required this.day, required this.court, required this.missing});
}

/// Đặt nhiều sân con cùng lúc: trong mỗi ngày, các sân đã chọn phải cùng bộ khung giờ
/// (Sân 1 slot 1-2 thì Sân 2 cũng slot 1-2; Sân 1 slot 1-2 + Sân 2 slot 1 là không được).
/// Trả về sân thiếu khung đầu tiên (theo ngày rồi tên sân); `null` = hợp lệ.
CourtsMismatch? findCourtsMismatch(Iterable<TimeSlot> slots) {
  final byDay = <DateTime, Map<String, Map<String, (DateTime, DateTime)>>>{};
  for (final s in slots) {
    final day = DateTime(s.start.year, s.start.month, s.start.day);
    final key = '${s.start.hour}:${s.start.minute}-${s.end.hour}:${s.end.minute}';
    ((byDay[day] ??= {})[s.courtName] ??= {})[key] = (s.start, s.end);
  }
  final days = byDay.keys.toList()..sort();
  for (final day in days) {
    final courts = byDay[day]!;
    if (courts.length < 2) continue;
    final all = <String, (DateTime, DateTime)>{for (final c in courts.values) ...c};
    final names = courts.keys.toList()..sort();
    for (final name in names) {
      final missing = all.keys.where((k) => !courts[name]!.containsKey(k)).map((k) => all[k]!).toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
      if (missing.isNotEmpty) return CourtsMismatch(day: day, court: name, missing: missing);
    }
  }
  return null;
}
