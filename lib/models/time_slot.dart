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
