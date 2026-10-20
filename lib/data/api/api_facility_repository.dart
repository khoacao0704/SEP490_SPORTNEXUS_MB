import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
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
/// - Lọc thêm: khoảng giá (theo giá mặc định của sân con), số sao, tiện ích (phải có đủ). Cơ sở đẩy tin luôn đứng đầu.
/// - Sân con: courtType / trong nhà / mặt sân / số người là chuỗi tự do chủ sân nhập → chỉ hiển thị
///   ([Facility.courtDetails]); app vẫn coi mọi sân con là [CourtType.standard].
/// - BE chưa có: lọc tỉnh/quận ([supportsAreaFilter] = false), nội quy cơ sở, API giữ chỗ
///   (giữ chỗ 10 phút đếm trên máy, xem [holdSlots]).
class ApiFacilityRepository implements FacilityRepository {
  static const String searchPath = '/api/v1/facilities/search';
  static const String sportsPath = '/api/v1/master-data/sports';
  static const String amenitiesPath = '/api/v1/master-data/amenities';
  static String facilityPath(String id) => '/api/v1/facilities/$id';
  static String availabilityPath(String id) => '/api/v1/facilities/$id/availability';

  /// pageSize tối đa BE cho phép.
  static const int pageSize = 50;

  final ApiClient _api;

  /// categoryId của từng môn, lấy từ danh mục môn và từ dữ liệu cơ sở đã tải.
  final Map<Sport, String> _categoryIds = {};
  bool _sportsLoaded = false;

  List<Amenity>? _amenities;

  ApiFacilityRepository({required this._api});

  @override
  bool get supportsAreaFilter => false;

  /// courtType của BE là chữ tự do chủ sân nhập, không dùng để lọc / ghép được.
  @override
  bool get supportsCourtTypes => false;

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
      FacilitySort.priceHighToLow => 'price_desc',
      FacilitySort.rating => 'rating',
      FacilitySort.newest => 'newest',
    };
    if (sortBy != null) params['sortBy'] = sortBy;
    // BE lọc giá theo giá mặc định của sân con; sao 1–5; tiện ích gửi lặp tham số và phải có đủ tất cả.
    if (query.minPrice != null) params['minPrice'] = query.minPrice;
    if (query.maxPrice != null) params['maxPrice'] = query.maxPrice;
    if (query.minRating != null) params['minRating'] = query.minRating;
    if (query.amenityIds.isNotEmpty) params['amenityIds'] = query.amenityIds.toList();

    final sport = query.sport;
    if (sport != null) {
      final categoryId = await categoryIdOf(sport);
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

  /// Danh mục tiện ích ít thay đổi: tải một lần.
  @override
  Future<List<Amenity>> getAmenities() async {
    final cached = _amenities;
    if (cached != null) return cached;
    final data = await _call(() => _api.get(amenitiesPath)) as List? ?? const [];
    return _amenities = data
        .cast<Map<String, dynamic>>()
        .map((a) => Amenity(id: a['id'].toString(), name: a['name'] as String? ?? '', iconCode: a['iconCode'] as String?))
        .where((a) => a.name.isNotEmpty)
        .toList();
  }

  @override
  Future<Facility> getFacility(String facilityId) async =>
      _facilityFromDetail(await _call(() => _api.get(facilityPath(facilityId))) as Map<String, dynamic>);

  @override
  Future<List<TimeSlot>> getTimeSlots(String facilityId, Sport sport, DateTime date, {CourtType? courtType}) async {
    final categoryId = await categoryIdOf(sport);
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

  // ---------------- Giữ chỗ: BE chưa có API → giữ trên máy ----------------

  /// Thời gian giữ chỗ để thanh toán (đếm trên máy).
  static const Duration holdDuration = Duration(minutes: 10);

  /// Lượt giữ trên máy: holdId → các khung đang giữ.
  final Map<String, List<TimeSlot>> _holds = {};
  int _holdCounter = 0;

  /// BE chưa có API giữ chỗ: kiểm tra lại các khung còn trống ngay lúc bấm (một khung lỗi thì không giữ khung nào)
  /// rồi đếm 10 phút trên máy. Server KHÔNG khóa ca: người khác vẫn đặt được trước khi thanh toán xong,
  /// khi đó bước đặt sân nhận lỗi "đã có người đặt".
  @override
  Future<SlotHold> holdSlots(List<TimeSlot> slots) async {
    if (slots.isEmpty) throw const FacilityException(FacilityStrings.noSlotSelected);
    final now = DateTime.now();
    final unique = {for (final s in slots) s.id: s}.values.toList()..sort((a, b) => a.start.compareTo(b.start));

    // Khung giờ mới nhất theo từng (cơ sở, môn, ngày): mỗi ngày chỉ tải một lần.
    final latestByDay = <String, List<TimeSlot>>{};
    final fresh = <TimeSlot>[];
    for (final slot in unique) {
      final label = '${slot.courtName} • ${Formatters.slotLabel(slot.start, slot.end)}';
      if (slot.hasStarted(now)) throw FacilityException(FacilityStrings.slotStarted(label));
      final key = '${slot.facilityId}|${slot.sport.name}|${_dateParam(slot.start)}';
      final day = latestByDay[key] ??= await getTimeSlots(slot.facilityId, slot.sport, slot.start);
      final latest = day.where((s) => s.id == slot.id).firstOrNull;
      if (latest == null || latest.isFull) throw FacilityException(FacilityStrings.slotJustFull(label));
      fresh.add(latest);
    }

    final holdId = 'local-${++_holdCounter}';
    _holds[holdId] = fresh;
    return SlotHold(holdId: holdId, slots: fresh, expiresAt: now.add(holdDuration));
  }

  @override
  Future<void> releaseHold(String holdId) async => _holds.remove(holdId);

  @override
  Future<SlotHold> transferHold(String holdId, {required DateTime until, List<String>? slotIds}) async {
    final old = _holds[holdId];
    final moving = old == null ? const <TimeSlot>[] : old.where((s) => slotIds == null || slotIds.contains(s.id)).toList();
    if (moving.isEmpty) throw const FacilityException(FacilityStrings.holdExpired);
    final rest = old!.where((s) => !moving.contains(s)).toList();
    if (rest.isEmpty) {
      _holds.remove(holdId);
    } else {
      _holds[holdId] = rest;
    }
    final newId = 'local-${++_holdCounter}';
    _holds[newId] = moving;
    return SlotHold(holdId: newId, slots: moving, expiresAt: until);
  }

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
      amenities: _amenityNames(json),
      amenityIcons: _amenityIcons(json),
      openTime: _time(json['openTime']),
      closeTime: _time(json['closeTime']),
      phone: json['phone'] as String? ?? '',
      isPromoted: json['isPromoted'] == true,
    );
  }

  /// Chi tiết cơ sở: mỗi môn = các sân con (Court) đang hoạt động của môn đó; "giá từ" = DefaultPrice thấp nhất.
  Facility _facilityFromDetail(Map<String, dynamic> json) {
    final counts = <Sport, int>{};
    final prices = <Sport, int>{};
    final details = <Sport, Map<String, String>>{};
    for (final court in (json['courts'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final sport = sportFromName(court['categoryName'] as String?);
      if (sport == null) continue;
      _categoryIds[sport] = court['categoryId'].toString();
      if ((court['status'] as String? ?? 'Active').toLowerCase() != 'active') continue;
      counts[sport] = (counts[sport] ?? 0) + 1;
      final detail = courtDetail(court);
      if (detail.isNotEmpty) (details[sport] ??= {})[court['name'] as String? ?? ''] = detail;
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
      amenities: _amenityNames(json),
      amenityIcons: _amenityIcons(json),
      openTime: _time(json['openTime']),
      closeTime: _time(json['closeTime']),
      phone: json['phone'] as String? ?? '',
      description: json['description'] as String? ?? '',
      courtDetails: details,
    );
  }

  /// Thông tin chủ sân khai báo cho sân con (đều tùy chọn, chuỗi tự do):
  /// "Sân 5 người · Trong nhà · Cỏ nhân tạo · Tối đa 10 người". Chưa khai báo gì → chuỗi rỗng.
  static String courtDetail(Map<String, dynamic> court) {
    final courtType = (court['courtType'] as String?)?.trim() ?? '';
    final surface = (court['surfaceType'] as String?)?.trim() ?? '';
    final indoor = court['isIndoor'] as bool?;
    final maxPlayers = (court['maxPlayers'] as num?)?.toInt() ?? 0;
    return [
      if (courtType.isNotEmpty) courtType,
      if (indoor != null) indoor ? FacilityStrings.indoor : FacilityStrings.outdoor,
      if (surface.isNotEmpty) surface,
      if (maxPlayers > 0) FacilityStrings.maxPlayers(maxPlayers),
    ].join(' · ');
  }

  /// categoryId của [sport]; chưa biết thì tải danh mục môn (một lần).
  Future<String?> categoryIdOf(Sport sport) async {
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

  static List<String> _amenityNames(Map<String, dynamic> json) => (json['amenities'] as List? ?? const [])
      .map((a) => a is Map ? a['name']?.toString() ?? '' : a.toString())
      .where((a) => a.isNotEmpty)
      .toList();

  /// Tên tiện ích → iconCode của BE.
  static Map<String, String> _amenityIcons(Map<String, dynamic> json) => {
        for (final a in (json['amenities'] as List? ?? const []).whereType<Map>())
          if (a['name'] != null && a['iconCode'] != null) a['name'].toString(): a['iconCode'].toString(),
      };

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
