import '../../models/court_recommendation.dart';

/// Ca sân trống trong giờ rảnh của người chơi cho khối "Sân trống trong giờ rảnh của bạn" ở Trang chủ.
/// Chưa làm khảo sát giờ rảnh / không có ca phù hợp thì rỗng.
abstract class CourtRecommendationRepository {
  /// Như Web: tối đa 6 gợi ý trên Trang chủ.
  static const int homeLimit = 6;

  Future<List<CourtRecommendation>> getRecommendedCourts({int limit = homeLimit});
}
