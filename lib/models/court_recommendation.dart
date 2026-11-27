import 'sport.dart';

/// Một ca trống trong giờ rảnh của người chơi (GET /recommendations/courts, dựa trên khảo sát người chơi).
class CourtRecommendation {
  final String facilityId;
  final String facilityName;
  final String address;

  /// Môn của app; `null` khi BE trả môn app chưa có (khi đó không đặt được từ gợi ý).
  final Sport? sport;
  final String sportName;
  final double? distanceKm;
  final String courtSlotId;
  final String? courtName;
  final DateTime start;
  final DateTime end;
  final int price;

  const CourtRecommendation({
    required this.facilityId,
    required this.facilityName,
    required this.address,
    required this.sport,
    required this.sportName,
    required this.courtSlotId,
    required this.start,
    required this.end,
    required this.price,
    this.distanceKm,
    this.courtName,
  });
}
