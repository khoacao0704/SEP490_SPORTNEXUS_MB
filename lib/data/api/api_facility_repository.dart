import '../../core/strings/facility_strings.dart';
import '../../core/utils/text_utils.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_search.dart';
import '../../models/geo_point.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../repositories/facility_repository.dart';
import 'api_client.dart';

/// [FacilityRepository] gọi Backend thật (các API công khai, không cần đăng nhập).
///
/// - Tìm sân: GET /api/v1/facilities/search. Chi tiết: GET /api/v1/facilities/{id}.
///   Khung giờ: GET /api/v1/facilities/{id}/availability (theo từng sân con).
/// - Môn thể thao của BE là danh mục (categoryId) do Admin tạo; app ghép với 5 môn cố định theo TÊN.
///   Sân con thuộc môn app không có thì bỏ qua.
/// - BE chưa có: lọc tỉnh/quận, loại sân (mọi sân con là sân tiêu chuẩn), nội quy cơ sở, giữ chỗ khi thanh toán
///   → [supportsAreaFilter] = false, giữ chỗ báo "đang phát triển".
class ApiFacilityRepository implements FacilityRepository {
  static const String searchPath = '/api/v1/facilities/search';
  static const String sportsPath = '/api/v1/master-data/sports';
  static String facilityPath(String id) => '/api/v1/facilities/$id';
  static String availabilityPath(String id) => '/api/v1/facilities/$id/availability';

  /// pageSize tối đa BE cho phép.
  static const int pageSize = 50;

  final ApiClient _api;

  /// categoryId của từng môn, lấy từ danh mục môn và từ dữ liệu cơ sở đã tải.
  final Map<Sport, String> _categoryIds = {};
  bool _sportsLoaded = false;

  ApiFacilityRepository({required this._api});

  @override
  bool get supportsAreaFilter => false;

  @override
  Future<List<FacilitySearchResult>> searchFacilities(FacilitySearchQuery query) async {
    final location = query.userLocation;
    final params = <String, dynamic>{
      'page': 1,
      'pageSize': pageSize,
      if (query.keyword.trim().isNotEmpty) 'keyword': query.keyword.trim(),
      if (location != null) 'lat': location.latitude,
      if (location != null) 'lng': location.longitude,
    };
    // "Gần nhất" mà không có vị trí thì để BE dùng mặc định (mới nhất), gửi distance sẽ bị 400.
    final sortBy = switch (query.sort) {
      FacilitySort.distance => location == null ? null : 'distance',
      FacilitySort.priceLowToHigh => 'price_asc',
      FacilitySort.rating => 'rating',
    };
    if (sortBy != null) params['sortBy'] = sortBy;

    final sport = query.sport;
    if (sport != null) {
      final categoryId = await _categoryIdOf(sport);
      if (categoryId == null) return []; // server chưa có môn này
      params['categoryId'] = categoryId;
    }

    final data = await _call(() => _api.get(searchPath, query: params)) as Map<String, dynamic>;
    final items = (data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return items
        .map((json) => FacilitySearchResult(
              facility: _facilityFromSearch(json),
              distanceKm: (json['distanceKm'] as num?)?.toDouble(),
            ))
        .toList();
  }

  /// BE chưa có lọc tỉnh/quận.
  @override
  Future<List<String>> getDistricts(String city) async => const [];

  @override
  Future<Facility> getFacility(String facilityId) async =>
      _facilityFromDetail(await _call(() => _api.get(facilityPath(facilityId))) as Map<String, dynamic>);

  @override
  Future<List<TimeSlot>> getTimeSlots(String facilityId, Sport sport, DateTime date, {CourtType? courtType}) async {
    final categoryId = await _categoryIdOf(sport);
    if (categoryId == null) return [];
    final data = await _call(() => _api.get(availabilityPath(facilityId), query: {
          'date': _dateParam(date),
          'categoryId': categoryId,
        })) as Map<String, dynamic>;

    final slots = <TimeSlot>[];
    for (final court in (data['courts'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      if (court['categoryId']?.toString() != categoryId) continue;
      final courtName = court['courtName'] as String? ?? '';
      for (final slot in (court['slots'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        slots.add(TimeSlot(
          id: slot['id'].toString(),
          facilityId: facilityId,
          sport: sport,
          courtName: courtName,
          start: DateTime.parse(slot['startTime'] as String).toLocal(),
          end: DateTime.parse(slot['endTime'] as String).toLocal(),
          price: _money(slot['price']),
          isAvailable: slot['isBookable'] == true,
        ));
      }
    }
    return slots;
  }

  // ---------------- Giữ chỗ: BE chưa có (bàn ở bước nối Đặt sân) ----------------

  @override
  Future<SlotHold> holdSlots(List<TimeSlot> slots) async =>
      throw const FacilityException(FacilityStrings.featureInDevelopment);

  @override
  Future<void> releaseHold(String holdId) async {}

  @override
  Future<SlotHold> transferHold(String holdId, {required DateTime until, List<String>? slotIds}) async =>
      throw const FacilityException(FacilityStrings.featureInDevelopment);

  // ---------------- Chuyển đổi dữ liệu BE ----------------

  /// Ghép tên môn của BE ("Cầu lông", "Bóng đá", "Badminton"...) với môn của app; không khớp → null.
  static Sport? sportFromName(String? name) {
    final n = TextUtils.normalize(name ?? '');
    if (n.isEmpty) return null;
    if (n.contains('cau long') || n.contains('badminton')) return Sport.badminton;
    if (n.contains('pickleball')) return Sport.pickleball;
    if (n.contains('bong da') || n.contains('football') || n.contains('soccer')) return Sport.football;
    if (n.contains('bong ro') || n.contains('basketball')) return Sport.basketball;
    if (n.contains('tennis') && !n.contains('ban')) return Sport.tennis;
    return null;
  }

  /// Một cơ sở trong kết quả tìm kiếm: chỉ có ảnh đại diện, giá thấp nhất, tổng số sân con.
  Facility _facilityFromSearch(Map<String, dynamic> json) {
    final sports = <Sport>{};
    for (final s in (json['sports'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final sport = sportFromName(s['name'] as String?);
      if (sport == null) continue;
      sports.add(sport);
      _categoryIds[sport] = s['id'].toString();
    }
    final courtCount = (json['courtCount'] as num?)?.toInt() ?? 0;
    final minPrice = _money(json['minPrice']);
    final thumbnail = json['thumbnailUrl'] as String?;
    return Facility(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: '',
      district: '',
      location: _location(json),
      // Kết quả tìm kiếm không chia số sân theo môn: cơ sở một môn thì lấy tổng, nhiều môn thì để 0
      // (màn chi tiết tải lại đầy đủ).
      offerings: sports
          .map((s) => SportOffering(sport: s, courtCount: sports.length == 1 ? courtCount : 0, priceFrom: minPrice))
          .toList(),
      rating: _rating(json['averageRating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      imageUrls: thumbnail == null || thumbnail.isEmpty ? const [] : [thumbnail],
      amenities: _amenities(json),
      openTime: _time(json['openTime']),
      closeTime: _time(json['closeTime']),
      phone: json['phone'] as String? ?? '',
    );
  }

  /// Chi tiết cơ sở: mỗi môn = các sân con (Court) đang hoạt động của môn đó; "giá từ" = DefaultPrice thấp nhất.
  Facility _facilityFromDetail(Map<String, dynamic> json) {
    final counts = <Sport, int>{};
    final prices = <Sport, int>{};
    for (final court in (json['courts'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final sport = sportFromName(court['categoryName'] as String?);
      if (sport == null) continue;
      _categoryIds[sport] = court['categoryId'].toString();
      if ((court['status'] as String? ?? 'Active').toLowerCase() != 'active') continue;
      counts[sport] = (counts[sport] ?? 0) + 1;
      final price = _money(court['defaultPrice']);
      final current = prices[sport];
      prices[sport] = current == null || price < current ? price : current;
    }
    return Facility(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: '',
      district: '',
      location: _location(json),
      offerings: counts.entries
          .map((e) => SportOffering(sport: e.key, courtCount: e.value, priceFrom: prices[e.key] ?? 0))
          .toList(),
      rating: _rating(json['averageRating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      imageUrls: (json['images'] as List? ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      amenities: _amenities(json),
      openTime: _time(json['openTime']),
      closeTime: _time(json['closeTime']),
      phone: json['phone'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  /// categoryId của [sport]; chưa biết thì tải danh mục môn (một lần).
  Future<String?> _categoryIdOf(Sport sport) async {
    if (!_categoryIds.containsKey(sport) && !_sportsLoaded) {
      final list = await _call(() => _api.get(sportsPath)) as List? ?? const [];
      for (final item in list.cast<Map<String, dynamic>>()) {
        final s = sportFromName(item['name'] as String?);
        if (s != null) _categoryIds.putIfAbsent(s, () => item['id'].toString());
      }
      _sportsLoaded = true;
    }
    return _categoryIds[sport];
  }

  /// Cơ sở chưa có tọa độ → [Facility.noLocation] (không hiện trên bản đồ).
  static GeoPoint _location(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    return lat == null || lng == null ? Facility.noLocation : GeoPoint(lat, lng);
  }

  static List<String> _amenities(Map<String, dynamic> json) => (json['amenities'] as List? ?? const [])
      .map((a) => a is Map ? a['name']?.toString() ?? '' : a.toString())
      .where((a) => a.isNotEmpty)
      .toList();

  /// "06:00:00" → "06:00".
  static String _time(Object? value) {
    final s = value?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  /// Làm tròn 1 chữ số thập phân (BE trả trung bình, vd. 4.3333).
  static double _rating(Object? value) => (((value as num?)?.toDouble() ?? 0) * 10).round() / 10;

  /// Tiền BE là decimal nhưng luôn là VNĐ nguyên.
  static int _money(Object? value) => value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;

  /// Ngày theo lịch VN dạng yyyy-MM-dd.
  static String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Gọi BE; lỗi thành [FacilityException] mang câu tiếng Việt của BE.
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw FacilityException(e.message);
    }
  }
}
