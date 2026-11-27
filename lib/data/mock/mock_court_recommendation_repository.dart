import '../../models/court_recommendation.dart';
import '../../models/sport.dart';
import '../repositories/court_recommendation_repository.dart';
import '../repositories/facility_repository.dart';
import 'mock_facility_data.dart';

/// Bản giả lập: ca trống tối mai (giờ rảnh mẫu 18:00–21:00) ở vài cơ sở cầu lông, lấy từ bản giả lập khung giờ
/// nên "Đặt ca" giữ chỗ được như đặt từ chi tiết sân.
class MockCourtRecommendationRepository implements CourtRecommendationRepository {
  final FacilityRepository _facility;
  final DateTime Function() _now;

  MockCourtRecommendationRepository({required this._facility, DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const List<String> facilityIds = ['f-hcm-thientrieu', 'f-hcm-govap'];

  @override
  Future<List<CourtRecommendation>> getRecommendedCourts({int limit = CourtRecommendationRepository.homeLimit}) async {
    final now = _now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final result = <CourtRecommendation>[];
    for (final id in facilityIds) {
      final f = MockFacilityData.facilities.where((x) => x.id == id).firstOrNull;
      if (f == null) continue;
      final slots = await _facility.getTimeSlots(id, Sport.badminton, tomorrow);
      for (final s in slots.where((s) => s.isAvailable && s.start.hour >= 18 && s.start.hour < 21).take(3)) {
        result.add(
          CourtRecommendation(
            facilityId: f.id,
            facilityName: f.name,
            address: f.address,
            sport: Sport.badminton,
            sportName: Sport.badminton.label,
            distanceKm: 1.2 + result.length,
            courtSlotId: s.id,
            courtName: s.courtName,
            start: s.start,
            end: s.end,
            price: s.price,
          ),
        );
      }
    }
    return result.take(limit).toList();
  }
}
