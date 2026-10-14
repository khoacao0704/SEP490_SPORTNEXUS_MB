import 'facility.dart';
import 'geo_point.dart';
import 'sport.dart';

enum FacilitySort { distance, priceLowToHigh, rating }

class FacilitySearchQuery {
  final String city;
  final String? district;
  final Sport? sport;
  final String keyword;
  final FacilitySort sort;

  /// Vị trí GPS thật của người dùng; `null` thì không tính khoảng cách.
  final GeoPoint? userLocation;

  const FacilitySearchQuery({
    required this.city,
    this.district,
    this.sport,
    this.keyword = '',
    this.sort = FacilitySort.distance,
    this.userLocation,
  });
}

class FacilitySearchResult {
  final Facility facility;

  /// Khoảng cách từ vị trí người dùng (km); `null` khi không có GPS.
  final double? distanceKm;

  const FacilitySearchResult({required this.facility, this.distanceKm});
}
