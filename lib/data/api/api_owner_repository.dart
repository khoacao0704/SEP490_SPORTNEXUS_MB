import '../../core/strings/auth_strings.dart';          // for featureInDevelopment
import '../../core/strings/owner_strings.dart';
import '../../models/court_session.dart';               // ← CourtSession + TicketLookup
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';             // ← ReportReason is here
import '../../models/geo_point.dart';
import '../../models/owner_facility.dart';
import '../../models/owner_finance.dart';
import '../../models/sport.dart';
import '../repositories/owner_repository.dart';
import 'api_client.dart';

/// OwnerRepository gọi Backend thật.
/// Hiện chỉ nối phần danh sách cơ sở (getOwnerFacilities / getMyFacilities / getOwnerFacility).
/// Các hàm còn lại tạm báo "đang phát triển" — nối dần sau.
class ApiOwnerRepository implements OwnerRepository {
  final ApiClient _api;

  ApiOwnerRepository({required ApiClient api}) : _api = api;

  // ==================== A. Facilities list ====================

  @override
  Future<List<OwnerFacility>> getOwnerFacilities() async {
    try {
      final data = await _api.get('/api/v1/facilities/my-facilities');
      return _parseList(data);
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

  @override
  Future<List<Facility>> getMyFacilities() async {
    final all = await getOwnerFacilities();
    return all.where((f) => f.isApproved).map((f) => f.toFacility()).toList();
  }

  @override
  Future<OwnerFacility> getOwnerFacility(String facilityId) async {
    try {
      final data = await _api.get('/api/v1/facilities/$facilityId');
      if (data is! Map<String, dynamic>) {
        throw const OwnerException(OwnerStrings.loadError);
      }
      return _mapOwnerFacility(data);
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

  // ---------------- Mapping helpers ----------------

  List<OwnerFacility> _parseList(dynamic data) {
    if (data == null) return [];
    final list = data is List ? data : (data is Map && data['items'] is List ? data['items'] as List : null);
    if (list == null) return [];
    return list
        .whereType<Map>()
        .map((e) => _mapOwnerFacility(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Map JSON từ BE → OwnerFacility của app.
  /// BE hiện đơn giản hơn model FE, nên các field thiếu được gán giá trị mặc định an toàn.
  OwnerFacility _mapOwnerFacility(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['facilityId'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    final address = (json['address'] ?? '').toString();
    final city = (json['city'] ?? json['province'] ?? '').toString();
    final ward = (json['ward'] ?? json['district'] ?? '').toString();

    final lat = (json['latitude'] as num?)?.toDouble() ??
        (json['location'] is Map ? (json['location']['latitude'] as num?)?.toDouble() : null) ??
        0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (json['location'] is Map ? (json['location']['longitude'] as num?)?.toDouble() : null) ??
        0.0;

    final statusStr = (json['status'] ?? json['approvalStatus'] ?? 'Approved').toString();
    final status = _mapStatus(statusStr);

    final openTime = (json['openTime'] ?? '06:00').toString();
    final closeTime = (json['closeTime'] ?? '22:00').toString();
    final phone = (json['phone'] ?? '').toString();
    final description = (json['description'] ?? '').toString();

    final imageUrls = _stringList(json['imageUrls'] ?? json['images']);
    final amenities = _stringList(json['amenities']);
    final rules = _stringList(json['rules']);

    final rating = (json['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (json['reviewCount'] as num?)?.toInt() ?? 0;

    final submittedAt = _parseDate(json['createdAt'] ?? json['submittedAt']) ?? DateTime.now();

    return OwnerFacility(
      id: id,
      status: status,
      profile: FacilityProfile(
        name: name,
        city: city.isEmpty ? '—' : city,
        ward: ward.isEmpty ? '—' : ward,
        address: address.isEmpty ? '—' : address,
        location: GeoPoint(lat, lng),
        licenseNumber: (json['licenseNumber'] ?? '').toString(),
        licenseImages: _stringList(json['licenseImages']),
      ),
      operations: FacilityOperations(
        phone: phone,
        openMinutes: _safeParseMinutes(openTime),
        closeMinutes: _safeParseMinutes(closeTime),
        description: description,
        amenities: amenities,
        rules: rules,
        images: imageUrls,
      ),
      courts: _mapCourts(json),
      closures: const [],
      submittedAt: submittedAt,
      rejectReason: json['rejectReason'] as String?,
      rating: rating,
      reviewCount: reviewCount,
    );
  }

  ApprovalStatus _mapStatus(String value) {
    final v = value.toLowerCase();
    if (v.contains('pend')) return ApprovalStatus.pending;
    if (v.contains('reject')) return ApprovalStatus.rejected;
    return ApprovalStatus.approved;
  }

  List<CourtConfig> _mapCourts(Map<String, dynamic> json) {
    final raw = json['courts'] ?? json['offerings'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return CourtConfig(
        sport: Sport.fromApi((m['sport'] ?? m['sportName'] ?? 'football').toString()),
        courtType: CourtType.fromApi(m['courtType'] as String?),
        courtCount: (m['courtCount'] as num?)?.toInt() ?? (m['quantity'] as num?)?.toInt() ?? 1,
        pricing: null, // giá nối sau
      );
    }).toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int _safeParseMinutes(String hhmm) {
    try {
      return parseMinutes(hhmm);
    } catch (_) {
      return 6 * 60; // fallback 06:00
    }
  }

  // ==================== Chưa nối (làm sau) ====================

  Never _todo() => throw Exception('Tính năng đang phát triển');

  @override
  Future<List<CourtSession>> getSessions({required DateTime day, String? facilityId}) async => _todo();

  @override
  Future<CourtSession> getSession(String sessionId) async => _todo();

  @override
  Future<TicketLookup> lookupTicket(String code) async => _todo();

  @override
  Future<CourtSession> checkIn({required String sessionId, required String userId}) async => _todo();

  @override
  Future<CourtSession> checkOut(String sessionId) async => _todo();

  @override
  Future<OwnerFacility> submitFacility(FacilitySubmission submission) async => _todo();

  @override
  Future<OwnerFacility> resubmitFacility(String facilityId, FacilitySubmission submission) async => _todo();

  @override
  Future<OwnerFacility> requestProfileChange(String facilityId, FacilityProfile profile) async => _todo();

  @override
  Future<OwnerFacility> updateOperations(String facilityId, FacilityOperations operations) async => _todo();

  @override
  Future<OwnerFacility> saveCourt(String facilityId, CourtConfig court) async => _todo();

  @override
  Future<OwnerFacility> lockCourt(String facilityId, Sport sport, CourtType courtType) async => _todo();

  @override
  Future<OwnerFacility> unlockCourt(String facilityId, Sport sport, CourtType courtType) async => _todo();

  @override
  Future<OwnerFacility> addClosure(
      String facilityId, {
        Sport? sport,
        CourtType? courtType,
        required DateTime from,
        required DateTime to,
        required String reason,
      }) async =>
      _todo();

  @override
  Future<OwnerFacility> removeClosure(String facilityId, String closureId) async => _todo();

  @override
  Future<MonthlyRevenue> getMonthlyRevenue(DateTime month, {String? facilityId}) async => _todo();

  @override
  Future<List<ListingFeeBill>> getListingFees() async => _todo();

  @override
  Future<ListingFeeBill> payListingFee(String billId) async => _todo();

  @override
  Future<List<FacilityReview>> getFacilityReviews({String? facilityId}) async => _todo();

  @override
  Future<FacilityReview> replyToReview(String reviewId, String text) async => _todo();

  @override
  Future<FacilityReview> reportReview(String reviewId, ReportReason reason, {String note = ''}) async => _todo();
}