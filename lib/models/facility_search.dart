import 'facility.dart';
import 'geo_point.dart';
import 'sport.dart';

enum FacilitySort { distance, priceLowToHigh, priceHighToLow, rating, newest }

class FacilitySearchQuery {
  final String city;
  final String? district;
  final Sport? sport;
  final String keyword;
  final FacilitySort sort;

  /// Vị trí GPS thật của người dùng; `null` thì không tính khoảng cách.
  final GeoPoint? userLocation;

  /// Khoảng giá (giá mặc định một ca của sân con): cơ sở có ít nhất một sân con giá nằm trong khoảng.
  /// `null` = không giới hạn.
  final int? minPrice;
  final int? maxPrice;

  /// Số sao tối thiểu (1–5); `null` = không lọc.
  final double? minRating;

  /// Cơ sở phải có ĐỦ các tiện ích này ([Amenity.id]).
  final Set<String> amenityIds;

  const FacilitySearchQuery({
    required this.city,
    this.district,
    this.sport,
    this.keyword = '',
    this.sort = FacilitySort.distance,
    this.userLocation,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.amenityIds = const {},
  });
}

class FacilitySearchResult {
  final Facility facility;

  /// Khoảng cách từ vị trí người dùng (km); `null` khi không có GPS.
  final double? distanceKm;

  const FacilitySearchResult({required this.facility, this.distanceKm});
}
