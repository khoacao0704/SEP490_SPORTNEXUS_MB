import '../core/constants/lfg_rules.dart';
import 'court_type.dart';
import 'geo_point.dart';
import 'sport.dart';

enum LfgFormat {
  singles('Singles', 'Ghép 2 (1 vs 1)', 2),
  doubles('Doubles', 'Ghép 4 (2 vs 2)', 4),
  teamVsTeam('TeamVsTeam', 'Team vs Team', 2);

  const LfgFormat(this.apiValue, this.label, this.totalSlots);

  final String apiValue;
  final String label;

  /// Số chỗ trong kèo (kể cả host). Team vs Team: mỗi chỗ là một đội.
  final int totalSlots;

  bool get isTeam => this == LfgFormat.teamVsTeam;

  /// Bóng đá / bóng rổ chơi theo đội; các môn vợt ghép 2 hoặc 4.
  static List<LfgFormat> forSport(Sport sport) => sport == Sport.football || sport == Sport.basketball
      ? const [LfgFormat.teamVsTeam]
      : const [LfgFormat.singles, LfgFormat.doubles];

  static LfgFormat fromApi(String value) => values.firstWhere((f) => f.apiValue == value);
}

enum LfgStatus {
  /// Chưa đủ người, nhận Flash Claim tới T−48h. Ai rời cũng được hoàn 100%.
  open,

  /// Đã chốt (đủ người): không rời được, chỉ hủy được khi tất cả cùng đồng ý trước T−24h.
  confirmed,
  cancelled,
  completed,
}

enum LfgCancelReason {
  /// Tới T−48h vẫn chưa đủ người: hoàn 100% cho tất cả.
  notEnoughPlayers('NotEnoughPlayers'),

  /// Kèo đã chốt, tất cả thành viên đồng ý hủy trước T−24h: hoàn 100%, không trừ Fair Play.
  mutualAgreement('MutualAgreement'),

  /// Người cuối cùng (host) rời kèo chưa đủ người.
  everyoneLeft('EveryoneLeft'),

  /// Đã hủy (BE không cho biết lý do cụ thể, vd. chủ kèo hủy).
  cancelled('Cancelled');

  const LfgCancelReason(this.apiValue);

  final String apiValue;

  static LfgCancelReason fromApi(String value) => values.firstWhere((r) => r.apiValue == value);
}

/// Yêu cầu hủy một kèo đã chốt. Người gửi tự tính là đồng ý; một người từ chối là bác ngay.
/// Hết hạn ở T−24h nếu chưa đủ tất cả đồng ý (kèo vẫn diễn ra).
class LfgCancelRequest {
  final String requestedBy;
  final String requestedByName;
  final DateTime createdAt;

  /// userId các thành viên đã đồng ý (gồm người gửi).
  final List<String> approvals;

  const LfgCancelRequest({
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    required this.approvals,
  });

  bool hasApproved(String userId) => approvals.contains(userId);

  LfgCancelRequest approve(String userId) => LfgCancelRequest(
        requestedBy: requestedBy,
        requestedByName: requestedByName,
        createdAt: createdAt,
        approvals: [...approvals, if (!approvals.contains(userId)) userId],
      );

  factory LfgCancelRequest.fromJson(Map<String, dynamic> json) => LfgCancelRequest(
        requestedBy: json['requestedBy'] as String,
        requestedByName: json['requestedByName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        approvals: (json['approvals'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'createdAt': createdAt.toIso8601String(),
        'approvals': approvals,
      };
}

/// Trạng thái của người dùng hiện tại với một kèo mà họ CHƯA vào hẳn.
enum LfgMyStatus {
  /// Đã xin vào kèo cần chủ kèo duyệt (chưa trừ tiền).
  pendingApproval,

  /// Được mời vào kèo (đang giữ chỗ), cần chấp nhận và trả phần của mình.
  invited,
}

class LfgMember {
  final String userId;

  /// Tên người chơi, hoặc tên đội với Team vs Team.
  final String name;
  final int fairPlayScore;
  final bool isHost;
  final DateTime joinedAt;

  const LfgMember({
    required this.userId,
    required this.name,
    required this.fairPlayScore,
    required this.joinedAt,
    this.isHost = false,
  });

  factory LfgMember.fromJson(Map<String, dynamic> json) => LfgMember(
        userId: json['userId'] as String,
        name: json['name'] as String,
        fairPlayScore: (json['fairPlayScore'] as num).toInt(),
        isHost: json['isHost'] as bool? ?? false,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'fairPlayScore': fairPlayScore,
        'isHost': isHost,
        'joinedAt': joinedAt.toIso8601String(),
      };
}

/// Một kèo ghép trận. Sân đã được host đặt sẵn; mỗi người (đội) trả phần cọc của mình.
class LfgMatch {
  final String id;
  final String facilityId;
  final String facilityName;
  final String city;
  final String district;
  final GeoPoint location;
  final Sport sport;
  final LfgFormat format;

  /// Loại sân của khung giờ; Team vs Team quyết định số người mỗi đội (vd. sân 7 → 7 vs 7).
  final CourtType courtType;

  /// Sân con host đã đặt, vd. "Sân 2"; mọi người trong kèo chơi chung sân này.
  final String? courtName;
  final DateTime start;
  final DateTime end;

  /// Tiền sân của khung giờ; chia đều cho các chỗ.
  final int courtPrice;

  /// Thành viên đã thanh toán, host đứng đầu.
  final List<LfgMember> members;

  /// Số chỗ đang có người khác giữ để thanh toán (10 phút).
  final int heldSlots;
  final String note;
  final DateTime createdAt;

  final LfgCancelReason? cancelReason;

  /// Yêu cầu hủy đang chờ mọi người đồng ý (chỉ có ở kèo đã chốt).
  final LfgCancelRequest? cancelRequest;

  // ---- Dữ liệu BE (kèo có số người / giá / định dạng tùy chủ kèo); bản giả lập để trống ----

  /// Tổng số người trong kèo (kể cả chủ kèo) khi khác [LfgFormat.totalSlots].
  final int? totalSlotsOverride;

  /// Số chỗ còn trống do BE tính.
  final int? slotsLeftOverride;

  /// Tiền mỗi người vào kèo trả (chủ kèo tự đặt hoặc BE tính).
  final int? pricePerPersonOverride;

  /// Nhãn định dạng của BE, vd. "5v5" / "Ghép 3 người".
  final String? formatLabelOverride;

  /// Người dùng hiện tại đang chờ duyệt / được mời (chưa vào hẳn).
  final LfgMyStatus? myStatus;

  /// Đơn đặt sân của chủ kèo (vé QR của chủ kèo là vé đặt sân).
  final String? bookingId;

  const LfgMatch({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.city,
    required this.district,
    required this.location,
    required this.sport,
    required this.format,
    this.courtType = CourtType.standard,
    this.courtName,
    required this.start,
    required this.end,
    required this.courtPrice,
    required this.members,
    required this.createdAt,
    this.heldSlots = 0,
    this.note = '',
    this.cancelReason,
    this.cancelRequest,
    this.totalSlotsOverride,
    this.slotsLeftOverride,
    this.pricePerPersonOverride,
    this.formatLabelOverride,
    this.myStatus,
    this.bookingId,
  });

  LfgMember get host => members.firstWhere((m) => m.isHost, orElse: () => members.first);

  /// "Sân Cầu Lông Thiên Triều • Sân 2" (chưa có sân con thì chỉ có tên cơ sở).
  String get facilityCourtLabel => courtName == null ? facilityName : '$facilityName • $courtName';

  int get totalSlots => totalSlotsOverride ?? format.totalSlots;

  /// "Ghép 4 (2 vs 2)" hoặc "Team vs Team • 7 vs 7".
  String get formatLabel =>
      formatLabelOverride ?? (courtType.isStandard ? format.label : '${format.label} • ${courtType.matchup}');

  /// Chỗ còn có thể Flash Claim (đã trừ chỗ đang được giữ).
  int get slotsLeft => slotsLeftOverride ?? (totalSlots - members.length - heldSlots).clamp(0, totalSlots);

  bool get isFull => slotsLeftOverride != null ? slotsLeftOverride! <= 0 : members.length >= totalSlots;

  int get depositPerSlot => pricePerPersonOverride ?? LfgRules.depositPerSlot(courtPrice, totalSlots);

  /// Hạn tự rời kèo (hoàn 100%); từ mốc này tới T−24h muốn hủy phải tất cả đồng ý.
  DateTime get leaveDeadline => start.subtract(LfgRules.fillDeadlineBeforeStart);

  DateTime get fillDeadline => start.subtract(LfgRules.fillDeadlineBeforeStart);

  bool isMember(String userId) => members.any((m) => m.userId == userId);

  bool isHostedBy(String userId) => host.userId == userId;

  LfgStatus status(DateTime now) {
    if (cancelReason != null) return LfgStatus.cancelled;
    if (!end.isAfter(now)) return LfgStatus.completed;
    return isFull ? LfgStatus.confirmed : LfgStatus.open;
  }

  /// Hạn chót gửi / đồng ý yêu cầu hủy kèo đã chốt.
  DateTime get cancelRequestDeadline => start.subtract(LfgRules.mutualCancelBeforeStart);

  /// Yêu cầu hủy còn hiệu lực (chưa tới T−24h).
  LfgCancelRequest? activeCancelRequest(DateTime now) => now.isBefore(cancelRequestDeadline) ? cancelRequest : null;

  /// Còn nhận người: chưa hủy/chốt, chưa tới T−48h, còn chỗ trống.
  bool isClaimable(DateTime now) => status(now) == LfgStatus.open && now.isBefore(fillDeadline) && slotsLeft > 0;

  /// Mã QR check-in riêng của từng người, dùng tới khi chủ sân check-out.
  String ticketCode(String userId) => 'SPN-LFG-$id-$userId';

  LfgMatch copyWith({
    List<LfgMember>? members,
    int? heldSlots,
    LfgCancelReason? cancelReason,
    LfgCancelRequest? cancelRequest,
    bool clearCancelRequest = false,
  }) =>
      LfgMatch(
        id: id,
        facilityId: facilityId,
        facilityName: facilityName,
        city: city,
        district: district,
        location: location,
        sport: sport,
        format: format,
        courtType: courtType,
        courtName: courtName,
        start: start,
        end: end,
        courtPrice: courtPrice,
        members: members ?? this.members,
        createdAt: createdAt,
        heldSlots: heldSlots ?? this.heldSlots,
        note: note,
        cancelReason: cancelReason ?? this.cancelReason,
        cancelRequest: clearCancelRequest ? null : (cancelRequest ?? this.cancelRequest),
        totalSlotsOverride: totalSlotsOverride,
        slotsLeftOverride: slotsLeftOverride,
        pricePerPersonOverride: pricePerPersonOverride,
        formatLabelOverride: formatLabelOverride,
        myStatus: myStatus,
        bookingId: bookingId,
      );

  factory LfgMatch.fromJson(Map<String, dynamic> json) => LfgMatch(
        id: json['id'] as String,
        facilityId: json['facilityId'] as String,
        facilityName: json['facilityName'] as String,
        city: json['city'] as String,
        district: json['district'] as String,
        location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
        sport: Sport.fromApi(json['sport'] as String),
        format: LfgFormat.fromApi(json['format'] as String),
        courtType: CourtType.fromApi(json['courtType'] as String?),
        courtName: json['courtName'] as String?,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        courtPrice: (json['courtPrice'] as num).toInt(),
        members: (json['members'] as List).map((e) => LfgMember.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        heldSlots: (json['heldSlots'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
        cancelReason: json['cancelReason'] == null ? null : LfgCancelReason.fromApi(json['cancelReason'] as String),
        cancelRequest: json['cancelRequest'] == null
            ? null
            : LfgCancelRequest.fromJson(json['cancelRequest'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'city': city,
        'district': district,
        'location': location.toJson(),
        'sport': sport.apiValue,
        'format': format.apiValue,
        'courtType': courtType.apiValue,
        'courtName': courtName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'courtPrice': courtPrice,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'heldSlots': heldSlots,
        'note': note,
        if (cancelReason != null) 'cancelReason': cancelReason!.apiValue,
        if (cancelRequest != null) 'cancelRequest': cancelRequest!.toJson(),
      };
}

/// Chỗ đang giữ 10 phút trong lúc người chơi thanh toán cọc Flash Claim.
class LfgClaim {
  final String claimId;
  final LfgMatch match;
  final int amount;
  final DateTime expiresAt;

  const LfgClaim({required this.claimId, required this.match, required this.amount, required this.expiresAt});
}

class LfgFeedQuery {
  final String city;
  final String? district;
  final Sport? sport;
  final LfgFormat? format;

  /// Lọc theo loại sân (số người mỗi đội) với bóng đá / bóng rổ.
  final CourtType? courtType;

  /// Vị trí GPS để tính khoảng cách; `null` thì không tính.
  final GeoPoint? userLocation;

  const LfgFeedQuery({required this.city, this.district, this.sport, this.format, this.courtType, this.userLocation});
}

class LfgFeedItem {
  final LfgMatch match;
  final double? distanceKm;

  const LfgFeedItem({required this.match, this.distanceKm});
}
