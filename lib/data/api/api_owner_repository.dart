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

  ApiOwnerRepository(this._api);

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
  Future<List<Map<String, dynamic>>> getAmenities() async {
    try {
      final data = await _api.get('/api/v1/master-data/amenities');

      final List<dynamic> items;

      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is Map && data['data'] is List) {
        items = data['data'] as List;
      } else {
        return [];
      }

      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
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

    final statusStr = (json['approvalStatus'] ?? 'Pending').toString();
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

  List<CourtSession> _parseSessions(dynamic data) {
    if (data == null) return [];

    // BE may return a plain list or a paged object { items: [...], total: n }
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List;
    } else {
      return [];
    }

    return list
        .whereType<Map>()
        .map((e) => _mapSession(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  CourtSession _mapSession(Map<String, dynamic> json) {
    // Prefer CourtSession.fromJson if BE shape matches the model.
    // Fallback mapper for common BE field names.
    try {
      return CourtSession.fromJson(json);
    } catch (_) {
      // Flexible mapping when BE fields differ
      final id = (json['id'] ?? json['bookingId'] ?? '').toString();
      final facilityId = (json['facilityId'] ?? '').toString();
      final facilityName = (json['facilityName'] ?? json['facility']?['name'] ?? '').toString();

      final start = DateTime.parse(
        (json['start'] ?? json['startTime'] ?? json['slotStart'] ?? DateTime.now().toIso8601String()).toString(),
      );
      final end = DateTime.parse(
        (json['end'] ?? json['endTime'] ?? json['slotEnd'] ?? start.add(const Duration(hours: 1)).toIso8601String())
            .toString(),
      );

      final sportRaw = (json['sport'] ?? json['sportName'] ?? 'Football').toString();
      final courtTypeRaw = json['courtType'] as String?;

      final playersRaw = json['players'] ?? json['participants'] ?? [];
      final players = (playersRaw is List)
          ? playersRaw.whereType<Map>().map((p) {
        final m = Map<String, dynamic>.from(p);
        return SessionPlayer(
          userId: (m['userId'] ?? m['id'] ?? '').toString(),
          name: (m['name'] ?? m['fullName'] ?? m['username'] ?? '—').toString(),
          ticketCode: (m['ticketCode'] ?? m['qrCode'] ?? m['code'] ?? '').toString(),
          checkedInAt: m['checkedInAt'] != null ? DateTime.tryParse(m['checkedInAt'].toString()) : null,
        );
      }).toList()
          : <SessionPlayer>[];

      // If BE only returns booker info (no players array)
      if (players.isEmpty && (json['userId'] != null || json['bookerName'] != null)) {
        players.add(SessionPlayer(
          userId: (json['userId'] ?? json['bookerId'] ?? '').toString(),
          name: (json['bookerName'] ?? json['fullName'] ?? json['username'] ?? '—').toString(),
          ticketCode: (json['ticketCode'] ?? json['qrCode'] ?? '').toString(),
          checkedInAt: json['checkedInAt'] != null ? DateTime.tryParse(json['checkedInAt'].toString()) : null,
        ));
      }

      final kindRaw = (json['kind'] ?? json['type'] ?? 'Booking').toString();
      final kind = kindRaw.toLowerCase().contains('lfg') ? SessionKind.lfg : SessionKind.booking;

      return CourtSession(
        id: id,
        kind: kind,
        facilityId: facilityId,
        facilityName: facilityName.isEmpty ? '—' : facilityName,
        sport: _safeSport(sportRaw),
        courtType: CourtType.fromApi(courtTypeRaw),
        start: start,
        end: end,
        totalPrice: (json['totalPrice'] as num?)?.toInt() ?? (json['price'] as num?)?.toInt() ?? 0,
        paidViaApp: (json['paidViaApp'] as num?)?.toInt() ?? (json['paidAmount'] as num?)?.toInt() ?? 0,
        players: players,
        assignedCourt: (json['assignedCourt'] ?? json['courtName'] ?? json['court']?['name'] ?? '—').toString(),
        checkedOutAt: json['checkedOutAt'] != null ? DateTime.tryParse(json['checkedOutAt'].toString()) : null,
        cancelledAt: json['cancelledAt'] != null ? DateTime.tryParse(json['cancelledAt'].toString()) : null,
      );
    }
  }

  Sport _safeSport(String value) {
    try {
      return Sport.fromApi(value);
    } catch (_) {
      return Sport.football; // safe fallback
    }
  }
  String _minutesToTimeString(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${remainingMinutes.toString().padLeft(2, '0')}:00';
  }

  List<String> _validImageUrls(List<String> images) {
    return images.where((value) {
      final uri = Uri.tryParse(value);

      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    }).toList();
  }
  // ==================== Chưa nối (làm sau) ====================

  Never _todo() => throw Exception('Tính năng đang phát triển');

  @override
  Future<List<CourtSession>> getSessions({required DateTime day, String? facilityId}) async {
    try {
      // BE expects date-time; we send start of day
      final dateStr = DateTime(day.year, day.month, day.day).toIso8601String();

      final query = <String, dynamic>{
        'Date': dateStr,
        'PageSize': 100,
        if (facilityId != null && facilityId.isNotEmpty) 'FacilityId': facilityId,
      };

      final data = await _api.get('/api/v1/bookings/owner', query: query);
      return _parseSessions(data);
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

  @override
  Future<CourtSession> getSession(String sessionId) async {
    try {
      final data = await _api.get('/api/v1/bookings/owner/$sessionId');
      if (data is! Map<String, dynamic>) {
        throw const OwnerException(OwnerStrings.loadError);
      }
      return _mapSession(data);
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

  @override
  Future<TicketLookup> lookupTicket(String code) async {
    throw const OwnerException(
      'Tra cứu vé chưa được hỗ trợ qua API.',
    );
  }

  @override
  Future<void> scanQr({
    required String facilityId,
    required String qrCode,
  }) async {
    try {
      await _api.post(
        '/api/v1/checkin/scan',
        query: {
          'facilityId': facilityId,
          'qrCode': qrCode.trim(),
        },
      );
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }


  @override
  Future<CourtSession> checkIn({required String sessionId, required String userId}) async => _todo();

  @override
  Future<CourtSession> checkOut(String sessionId) async => _todo();

  @override
  @override
  Future<OwnerFacility> submitFacility(FacilitySubmission submission) async {
    try {
      final profile = submission.profile;
      final operations = submission.operations;

      final payload = <String, dynamic>{
        'name': profile.name,
        'address': profile.address,
        'latitude': profile.location.latitude,
        'longitude': profile.location.longitude,
        'description': operations.description,
        'phone': operations.phone,
        'openTime': _minutesToTimeString(operations.openMinutes),
        'closeTime': _minutesToTimeString(operations.closeMinutes),
        'rules': operations.rules.join('\n'),
        'autoGenerateSlots': true,

        // Do not send amenity labels as GUIDs.
        // Connect these after confirming the amenity IDs from the backend.
        'amenityIds': <String>[],

        // Only send image URLs; local file paths are not valid ImageUrls.
        'imageUrls': _validImageUrls(operations.images),
      };

      final data = await _api.post(
        '/api/v1/facilities',
        body: payload,
      );

      if (data is! Map) {
        throw const OwnerException(OwnerStrings.loadError);
      }

      final facilityJson = Map<String, dynamic>.from(data);
      final facilityId = (facilityJson['id'] ?? '').toString();

      if (facilityId.isEmpty) {
        throw const OwnerException(OwnerStrings.loadError);
      }

      final localImages = submission.operations.images
          .where((path) {
        final uri = Uri.tryParse(path);
        return uri == null ||
            (uri.scheme != 'http' && uri.scheme != 'https');
      })
          .toList();

      if (localImages.isNotEmpty) {
        await _api.uploadFiles(
          '/api/v1/facilities/$facilityId/images',
          filePaths: localImages,
          field: 'files',
        );
      }

      final updated = await _api.get(
        '/api/v1/facilities/$facilityId',
      );

      if (updated is! Map) {
        throw const OwnerException(OwnerStrings.loadError);
      }

      return _mapOwnerFacility(Map<String, dynamic>.from(updated));
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

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