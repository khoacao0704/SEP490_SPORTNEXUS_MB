import '../../models/court_recommendation.dart';
import '../repositories/court_recommendation_repository.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// [CourtRecommendationRepository] gọi Backend thật:
/// GET /api/v1/recommendations/courts?limit → [{facilityId, facilityName, address, sportName, distanceKm,
/// courtSlotId, courtId, courtName, startTime, endTime, price}] (giống Web). Lỗi thì ném [ApiException]
/// (Trang chủ ẩn khối).
class ApiCourtRecommendationRepository implements CourtRecommendationRepository {
  static const String path = '/api/v1/recommendations/courts';

  final ApiClient _api;

  ApiCourtRecommendationRepository({required this._api});

  @override
  Future<List<CourtRecommendation>> getRecommendedCourts({int limit = CourtRecommendationRepository.homeLimit}) async {
    final data = await _api.get(path, query: {'limit': limit});
    final list = data is Map ? data['items'] : data;
    if (list is! List) return const [];
    final result = <CourtRecommendation>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final start = DateTime.tryParse('${m['startTime']}')?.toLocal();
      final end = DateTime.tryParse('${m['endTime']}')?.toLocal();
      final slotId = m['courtSlotId']?.toString();
      if (start == null || end == null || slotId == null || slotId.isEmpty) continue;
      final sportName = '${m['sportName'] ?? ''}';
      result.add(
        CourtRecommendation(
          facilityId: '${m['facilityId'] ?? ''}',
          facilityName: '${m['facilityName'] ?? ''}',
          address: '${m['address'] ?? m['facilityAddress'] ?? ''}',
          sport: ApiFacilityRepository.sportFromName(sportName),
          sportName: sportName,
          distanceKm: (m['distanceKm'] as num?)?.toDouble(),
          courtSlotId: slotId,
          courtName: m['courtName']?.toString(),
          start: start,
          end: end,
          price: (m['price'] as num?)?.round() ?? 0,
        ),
      );
    }
    return result.take(limit).toList();
  }
}
