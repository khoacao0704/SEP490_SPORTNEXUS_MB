import 'court_type.dart';
import 'facility.dart';
import 'geo_point.dart';
import 'sport.dart';

/// Trạng thái duyệt hồ sơ cơ sở (hoặc yêu cầu đổi thông tin) bởi Admin trên Web.
enum ApprovalStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ApprovalStatus(this.apiValue);

  final String apiValue;

  static ApprovalStatus fromApi(String value) => values.firstWhere((s) => s.apiValue == value);
}

/// "18:30" từ số phút tính từ 0 giờ.
String formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// "18:30" -> 1110.
int parseMinutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Phần thông tin cần Admin duyệt: tên, địa chỉ (kèm vị trí) và giấy phép kinh doanh.
class FacilityProfile {
  final String name;
  final String city;

  /// Phường / xã.
  final String ward;
  final String address;
  final GeoPoint location;
  final String licenseNumber;

  /// Ảnh giấy phép kinh doanh (đường dẫn ảnh trong máy trước khi tải lên, hoặc URL do BE trả).
  final List<String> licenseImages;

  const FacilityProfile({
    required this.name,
    required this.city,
    required this.ward,
    required this.address,
    required this.location,
    required this.licenseNumber,
    required this.licenseImages,
  });

  String get fullAddress => '$address, $ward, $city';

  factory FacilityProfile.fromJson(Map<String, dynamic> json) => FacilityProfile(
        name: json['name'] as String,
        city: json['city'] as String,
        ward: json['ward'] as String,
        address: json['address'] as String,
        location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
        licenseNumber: json['licenseNumber'] as String,
        licenseImages: List<String>.from(json['licenseImages'] as List),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'city': city,
        'ward': ward,
        'address': address,
        'location': location.toJson(),
        'licenseNumber': licenseNumber,
        'licenseImages': licenseImages,
      };
}

/// Yêu cầu đổi tên / địa chỉ / giấy phép của cơ sở đã duyệt. Trong lúc chờ, cơ sở chạy bằng thông tin cũ.
class ProfileChange {
  final FacilityProfile profile;
  final ApprovalStatus status;
  final String? rejectReason;
  final DateTime submittedAt;

  const ProfileChange({
    required this.profile,
    required this.status,
    required this.submittedAt,
    this.rejectReason,
  });
}

/// Bảng giá một loại sân: khung giờ cố định độ dài [slotMinutes] trong giờ mở cửa,
/// giá thường / cao điểm, ngày thường / cuối tuần.
class CourtPricing {
  static const List<int> slotOptions = [60, 90, 120];

  final int slotMinutes;
  final int peakStart;
  final int peakEnd;
  final int weekdayPrice;
  final int weekdayPeakPrice;
  final int weekendPrice;
  final int weekendPeakPrice;

  const CourtPricing({
    required this.slotMinutes,
    required this.peakStart,
    required this.peakEnd,
    required this.weekdayPrice,
    required this.weekdayPeakPrice,
    required this.weekendPrice,
    required this.weekendPeakPrice,
  });

  static bool isWeekend(DateTime day) => day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  /// Khung bắt đầu trong giờ cao điểm thì tính giá cao điểm.
  bool isPeak(int startMinute) => startMinute >= peakStart && startMinute < peakEnd;

  int priceAt(DateTime day, int startMinute) {
    final peak = isPeak(startMinute);
    if (isWeekend(day)) return peak ? weekendPeakPrice : weekendPrice;
    return peak ? weekdayPeakPrice : weekdayPrice;
  }

  int get lowestPrice => [weekdayPrice, weekdayPeakPrice, weekendPrice, weekendPeakPrice].reduce((a, b) => a < b ? a : b);
}

/// Một loại sân của cơ sở. [pricing] `null` = chưa cấu hình giá/khung giờ, người chơi chưa đặt được.
/// Không xóa loại sân: sân bỏ hoặc chuyển mục đích thì khóa ([lockedAt]) — như tạm đóng nhưng chưa biết ngày mở;
/// mở khóa lại được bất cứ lúc nào.
class CourtConfig {
  final Sport sport;
  final CourtType courtType;
  final int courtCount;
  final CourtPricing? pricing;
  final DateTime? lockedAt;

  const CourtConfig({
    required this.sport,
    this.courtType = CourtType.standard,
    required this.courtCount,
    this.pricing,
    this.lockedAt,
  });

  bool get isLocked => lockedAt != null;

  /// Còn hoạt động nhưng chưa cài giá.
  bool get needsPricing => !isLocked && pricing == null;

  String get label => courtType.isStandard ? sport.label : '${sport.label} • ${courtType.label}';

  bool sameKind(Sport s, CourtType t) => sport == s && courtType == t;

  /// Giờ bắt đầu các khung trong ngày (phút), khung cuối kết thúc trước giờ đóng cửa.
  List<int> slotStarts(int openMinutes, int closeMinutes) {
    final p = pricing;
    if (p == null) return const [];
    return [for (var m = openMinutes; m + p.slotMinutes <= closeMinutes; m += p.slotMinutes) m];
  }

  CourtConfig copyWith({int? courtCount, CourtPricing? pricing, DateTime? lockedAt, bool unlock = false}) => CourtConfig(
        sport: sport,
        courtType: courtType,
        courtCount: courtCount ?? this.courtCount,
        pricing: pricing ?? this.pricing,
        lockedAt: unlock ? null : lockedAt ?? this.lockedAt,
      );
}

/// Tạm đóng cả cơ sở ([sport] `null`) hoặc một loại sân trong khoảng ngày (tính cả hai đầu).
class FacilityClosure {
  final String id;
  final Sport? sport;
  final CourtType? courtType;
  final DateTime from;
  final DateTime to;
  final String reason;

  const FacilityClosure({
    required this.id,
    this.sport,
    this.courtType,
    required this.from,
    required this.to,
    required this.reason,
  });

  bool get isWholeFacility => sport == null;

  /// Khoảng đóng chạm vào khoảng thời gian [start, end) của loại sân [s]/[t].
  bool blocks(Sport s, CourtType t, DateTime start, DateTime end) {
    if (!isWholeFacility && (sport != s || courtType != t)) return false;
    final closeStart = DateTime(from.year, from.month, from.day);
    final closeEnd = DateTime(to.year, to.month, to.day + 1);
    return start.isBefore(closeEnd) && end.isAfter(closeStart);
  }

  bool isActiveOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(DateTime(from.year, from.month, from.day)) && !d.isAfter(DateTime(to.year, to.month, to.day));
  }

  bool isOver(DateTime now) => DateTime(to.year, to.month, to.day + 1).isBefore(now);
}

/// Thông tin vận hành chủ sân sửa tự do sau khi được duyệt (không cần Admin duyệt lại).
class FacilityOperations {
  final String phone;
  final int openMinutes;
  final int closeMinutes;
  final String description;
  final List<String> amenities;
  final List<String> rules;

  /// Ảnh sân (đường dẫn trong máy hoặc URL).
  final List<String> images;

  const FacilityOperations({
    required this.phone,
    required this.openMinutes,
    required this.closeMinutes,
    this.description = '',
    this.amenities = const [],
    this.rules = const [],
    this.images = const [],
  });
}

/// Hồ sơ đăng cơ sở mới (hoặc nộp lại sau khi bị từ chối). Giá & khung giờ cấu hình sau khi được duyệt.
class FacilitySubmission {
  final FacilityProfile profile;
  final FacilityOperations operations;

  /// Môn, loại sân, số sân con (chưa có giá).
  final List<CourtConfig> courts;

  const FacilitySubmission({required this.profile, required this.operations, required this.courts});
}

/// Cơ sở nhìn từ phía Chủ sân, gồm trạng thái duyệt.
class OwnerFacility {
  final String id;
  final ApprovalStatus status;
  final FacilityProfile profile;
  final FacilityOperations operations;
  final List<CourtConfig> courts;
  final List<FacilityClosure> closures;
  final DateTime submittedAt;

  /// Lý do Admin từ chối hồ sơ đăng mới.
  final String? rejectReason;

  /// Yêu cầu đổi tên / địa chỉ / giấy phép đang chờ hoặc vừa bị từ chối (chỉ khi đã duyệt).
  final ProfileChange? change;
  final double rating;
  final int reviewCount;

  const OwnerFacility({
    required this.id,
    required this.status,
    required this.profile,
    required this.operations,
    required this.courts,
    required this.submittedAt,
    this.closures = const [],
    this.rejectReason,
    this.change,
    this.rating = 0,
    this.reviewCount = 0,
  });

  bool get isApproved => status == ApprovalStatus.approved;

  bool get hasPendingChange => change?.status == ApprovalStatus.pending;

  /// Loại sân đã có giá và khung giờ, chưa khóa: người chơi đặt được.
  List<CourtConfig> get bookableCourts => courts.where((c) => c.pricing != null && !c.isLocked).toList();

  List<CourtConfig> get activeCourts => courts.where((c) => !c.isLocked).toList();

  CourtConfig? courtFor(Sport sport, CourtType type) => courts.where((c) => c.sameKind(sport, type)).firstOrNull;

  List<FacilityClosure> activeClosures(DateTime now) => closures.where((c) => !c.isOver(now)).toList();

  /// Bản hiển thị cho người chơi / bộ chọn cơ sở (chỉ dùng khi đã duyệt).
  Facility toFacility() => Facility(
        id: id,
        name: profile.name,
        address: profile.address,
        city: profile.city,
        district: profile.ward,
        location: profile.location,
        offerings: [
          for (final c in activeCourts)
            SportOffering(
              sport: c.sport,
              courtType: c.courtType,
              courtCount: c.courtCount,
              priceFrom: c.pricing?.lowestPrice ?? 0,
            ),
        ],
        rating: rating,
        reviewCount: reviewCount,
        imageUrls: operations.images,
        amenities: operations.amenities,
        rules: operations.rules,
        openTime: formatMinutes(operations.openMinutes),
        closeTime: formatMinutes(operations.closeMinutes),
        phone: operations.phone,
        description: operations.description,
      );

  OwnerFacility copyWith({
    ApprovalStatus? status,
    FacilityProfile? profile,
    FacilityOperations? operations,
    List<CourtConfig>? courts,
    List<FacilityClosure>? closures,
    DateTime? submittedAt,
    String? rejectReason,
    ProfileChange? change,
    bool clearRejectReason = false,
    bool clearChange = false,
  }) =>
      OwnerFacility(
        id: id,
        status: status ?? this.status,
        profile: profile ?? this.profile,
        operations: operations ?? this.operations,
        courts: courts ?? this.courts,
        closures: closures ?? this.closures,
        submittedAt: submittedAt ?? this.submittedAt,
        rejectReason: clearRejectReason ? null : rejectReason ?? this.rejectReason,
        change: clearChange ? null : change ?? this.change,
        rating: rating,
        reviewCount: reviewCount,
      );
}
