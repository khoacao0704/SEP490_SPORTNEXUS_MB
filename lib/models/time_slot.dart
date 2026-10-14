import 'sport.dart';

/// Khung giờ do chủ sân cấu hình sẵn; người chơi chỉ chọn trong danh sách này.
class TimeSlot {
  final String id;
  final String facilityId;
  final Sport sport;
  final DateTime start;
  final DateTime end;
  final int price;
  final int totalCourts;

  /// Số sân còn trống (đã trừ sân đã đặt và sân đang được giữ chỗ).
  final int availableCourts;

  const TimeSlot({
    required this.id,
    required this.facilityId,
    required this.sport,
    required this.start,
    required this.end,
    required this.price,
    required this.totalCourts,
    required this.availableCourts,
  });

  bool get isFull => availableCourts <= 0;

  bool hasStarted(DateTime now) => !start.isAfter(now);

  bool isBookable(DateTime now) => !isFull && !hasStarted(now);
}

/// Kết quả giữ chỗ 10 phút trong lúc người chơi thanh toán.
class SlotHold {
  final String holdId;
  final TimeSlot slot;
  final DateTime expiresAt;

  const SlotHold({required this.holdId, required this.slot, required this.expiresAt});

  int secondsRemaining(DateTime now) {
    final seconds = expiresAt.difference(now).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}
