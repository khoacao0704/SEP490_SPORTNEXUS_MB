import 'geo_point.dart';
import 'sport.dart';

/// Một môn thể thao mà cơ sở cung cấp.
/// Các sân con của cùng một môn là như nhau: người chơi không chọn sân cụ thể,
/// hệ thống trừ dần [courtCount] và chủ sân chỉ sân khi check-in.
class SportOffering {
  final Sport sport;
  final int courtCount;

  /// Giá thấp nhất trong các khung giờ chủ sân cấu hình cho môn này.
  final int priceFrom;

  const SportOffering({required this.sport, required this.courtCount, required this.priceFrom});

  factory SportOffering.fromJson(Map<String, dynamic> json) => SportOffering(
        sport: Sport.fromApi(json['sport'] as String),
        courtCount: (json['courtCount'] as num).toInt(),
        priceFrom: (json['priceFrom'] as num).toInt(),
      );
}

/// Cơ sở thể thao (một địa điểm có thể có nhiều môn, mỗi môn nhiều sân).
class Facility {
  final String id;
  final String name;
  final String address;
  final String city;
  final String district;
  final GeoPoint location;
  final List<SportOffering> offerings;
  final double rating;
  final int reviewCount;
  final List<String> imageUrls;
  final List<String> amenities;
  final List<String> rules;
  final String openTime;
  final String closeTime;
  final String phone;
  final String description;

  const Facility({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.district,
    required this.location,
    required this.offerings,
    required this.rating,
    required this.reviewCount,
    required this.imageUrls,
    this.amenities = const [],
    this.rules = const [],
    required this.openTime,
    required this.closeTime,
    required this.phone,
    this.description = '',
  });

  List<Sport> get sports => offerings.map((o) => o.sport).toList();

  int get priceFrom => offerings.map((o) => o.priceFrom).reduce((a, b) => a < b ? a : b);

  SportOffering? offeringFor(Sport sport) {
    for (final o in offerings) {
      if (o.sport == sport) return o;
    }
    return null;
  }

  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        district: json['district'] as String,
        location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
        offerings: (json['offerings'] as List)
            .map((e) => SportOffering.fromJson(e as Map<String, dynamic>))
            .toList(),
        rating: (json['rating'] as num).toDouble(),
        reviewCount: (json['reviewCount'] as num).toInt(),
        imageUrls: List<String>.from(json['imageUrls'] as List),
        amenities: List<String>.from(json['amenities'] as List? ?? const []),
        rules: List<String>.from(json['rules'] as List? ?? const []),
        openTime: json['openTime'] as String,
        closeTime: json['closeTime'] as String,
        phone: json['phone'] as String,
        description: json['description'] as String? ?? '',
      );
}
