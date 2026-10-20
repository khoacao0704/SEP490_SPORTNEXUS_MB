import 'court_type.dart';
import 'geo_point.dart';
import 'sport.dart';

/// Một loại sân của một môn mà cơ sở cung cấp (vd. Bóng đá • Sân 7 người).
/// Loại sân có [courtCount] sân con (Sân 1, Sân 2, ...); người chơi chọn đúng sân con khi đặt.
class SportOffering {
  final Sport sport;
  final CourtType courtType;
  final int courtCount;

  /// Giá thấp nhất trong các khung giờ chủ sân cấu hình cho môn này.
  final int priceFrom;

  const SportOffering({
    required this.sport,
    required this.courtCount,
    required this.priceFrom,
    this.courtType = CourtType.standard,
  });

  factory SportOffering.fromJson(Map<String, dynamic> json) => SportOffering(
        sport: Sport.fromApi(json['sport'] as String),
        courtType: CourtType.fromApi(json['courtType'] as String?),
        courtCount: (json['courtCount'] as num).toInt(),
        priceFrom: (json['priceFrom'] as num).toInt(),
      );
}

/// Tiện ích dùng cho bộ lọc tìm sân (danh mục do Admin quản lý).
class Amenity {
  final String id;
  final String name;

  /// Mã icon của BE (parking, wifi, air_conditioner...); `null` thì dùng icon chung.
  final String? iconCode;

  const Amenity({required this.id, required this.name, this.iconCode});
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

  /// Cơ sở đang mua gói đẩy tin (BE đã xếp lên đầu kết quả tìm kiếm).
  final bool isPromoted;

  /// Mã icon theo tên tiện ích trong [amenities]; tiện ích không có mã thì dùng icon chung.
  final Map<String, String> amenityIcons;

  /// Thông tin thêm của từng sân con theo môn rồi theo tên (vd. "Sân 5 người · Trong nhà · Cỏ nhân tạo");
  /// sân chủ sân chưa khai báo thì không có trong map. Tách theo môn vì hai môn có thể cùng tên "Sân 1".
  final Map<Sport, Map<String, String>> courtDetails;

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
    this.isPromoted = false,
    this.amenityIcons = const {},
    this.courtDetails = const {},
  });

  /// Tọa độ của cơ sở chưa được chủ sân ghim vị trí.
  static const GeoPoint noLocation = GeoPoint(0, 0);

  bool get hasLocation => location != noLocation;

  /// Thông tin thêm của sân con [court] thuộc môn [sport]; `null` khi chủ sân chưa khai báo.
  String? courtDetailOf(Sport sport, String? court) => court == null ? null : courtDetails[sport]?[court];

  /// Địa chỉ kèm thành phố (dữ liệu BE chỉ có địa chỉ đầy đủ, không tách thành phố).
  String get fullAddress => city.isEmpty ? address : '$address, $city';

  List<Sport> get sports => offerings.map((o) => o.sport).toSet().toList();

  int get priceFrom =>
      offerings.isEmpty ? 0 : offerings.map((o) => o.priceFrom).reduce((a, b) => a < b ? a : b);

  /// Các loại sân của [sport] tại cơ sở, rẻ nhất trước.
  List<SportOffering> offeringsFor(Sport sport) =>
      offerings.where((o) => o.sport == sport).toList()..sort((a, b) => a.priceFrom.compareTo(b.priceFrom));

  /// Loại sân [courtType] của [sport]; bỏ trống [courtType] thì lấy loại rẻ nhất (dùng cho "giá từ").
  SportOffering? offeringFor(Sport sport, {CourtType? courtType}) {
    final list = offeringsFor(sport);
    if (courtType == null) return list.firstOrNull;
    return list.where((o) => o.courtType == courtType).firstOrNull;
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
