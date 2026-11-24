import '../core/constants/lfg_rules.dart';
import 'court_type.dart';
import 'geo_point.dart';
import 'player_survey.dart' show SkillLevel;
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

  /// Đội vs Đội dùng được cho mọi môn có Đội (môn vợt: đội 2 người đánh đôi).
  static List<LfgFormat> forSportWithTeams(Sport sport) {
    final formats = forSport(sport);
    return formats.contains(teamVsTeam) ? formats : [...formats, teamVsTeam];
  }

  /// Số người mỗi đội chọn được cho kèo Đội vs Đội: theo loại sân của môn (bóng đá 5/7/11, bóng rổ 3/5),
  /// môn vợt là 2 (đánh đôi). BE kiểm tra lại theo thể thức của môn / sân.
  static List<int> teamSideSizes(Sport sport) {
    final sizes = CourtType.forSport(sport).where((t) => !t.isStandard).map((t) => t.playersPerTeam).toList();
    return sizes.isEmpty ? const [2] : sizes;
  }

  static LfgFormat fromApi(String value) => values.firstWhere((f) => f.apiValue == value);
}

enum LfgStatus {
  /// Chưa đủ người, nhận Flash Claim tới T−48h. Ai rời cũng được hoàn 100%.
  open,

  /// Đã chốt (đủ người): người vào kèo rời thì không được hoàn; chủ kèo hủy dưới 48h thì bị phạt giá sân.
  confirmed,
  cancelled,
  completed,
}

enum LfgCancelReason {
  /// Tới T−48h vẫn chưa đủ người: hoàn 100% cho tất cả.
  notEnoughPlayers('NotEnoughPlayers'),

  /// Dữ liệu cũ: cả kèo bỏ phiếu đồng ý hủy (BE đã bỏ vote hủy kèo 20/11/2026; giữ để đọc kèo cũ).
  mutualAgreement('MutualAgreement'),

  /// Người cuối cùng (host) rời kèo chưa đủ người.
  everyoneLeft('EveryoneLeft'),

  /// Đã hủy (BE không cho biết lý do cụ thể, vd. chủ kèo hủy).
  cancelled('Cancelled');

  const LfgCancelReason(this.apiValue);

  final String apiValue;

  static LfgCancelReason fromApi(String value) => values.firstWhere((r) => r.apiValue == value);
}

/// Trạng thái của người dùng hiện tại với một kèo mà họ CHƯA vào hẳn.
enum LfgMyStatus {
  /// Đã xin vào kèo cần chủ kèo duyệt (chưa trừ Điểm).
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

  /// Phe trong kèo Đội vs Đội: 'A' = đội chủ kèo, 'B' = đội nhận kèo; `null` với kèo thường.
  final String? side;

  const LfgMember({
    required this.userId,
    required this.name,
    required this.fairPlayScore,
    required this.joinedAt,
    this.isHost = false,
    this.side,
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

/// Đội gắn với kèo Đội vs Đội (BE chỉ trả id + tên).
class LfgTeamRef {
  final String id;
  final String name;

  const LfgTeamRef({required this.id, required this.name});
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

  /// Giá sân của khung giờ; chia đều cho các chỗ.
  final int courtPrice;

  /// Thành viên đã thanh toán, host đứng đầu.
  final List<LfgMember> members;

  /// Số chỗ đang có người khác giữ để thanh toán (10 phút).
  final int heldSlots;
  final String note;
  final DateTime createdAt;

  final LfgCancelReason? cancelReason;

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

  /// Trình độ kèo (thẻ trình độ của BE); `null` = mọi trình độ.
  final SkillLevel? skillLevel;

  /// Mốc chủ kèo hủy không bị phạt tiền do BE trả (`hostCancelUntil`, theo cấu hình Lfg:LockMinutes);
  /// trống → T−48h.
  final DateTime? hostCancelUntilOverride;

  /// Kèo Đội vs Đội: đội của chủ kèo (phe A) và đội đã nhận kèo (phe B, `null` khi chưa có).
  final LfgTeamRef? hostTeam;
  final LfgTeamRef? challengerTeam;

  /// Số người mỗi đội (kèo Đội vs Đội), vd. 5 với 5v5.
  final int? sideSize;

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
    this.totalSlotsOverride,
    this.slotsLeftOverride,
    this.pricePerPersonOverride,
    this.formatLabelOverride,
    this.myStatus,
    this.bookingId,
    this.skillLevel,
    this.hostCancelUntilOverride,
    this.hostTeam,
    this.challengerTeam,
    this.sideSize,
  });

  /// Kèo Đội vs Đội: chỉ đội trưởng nhận kèo thay cả đội (người lẻ không vào được).
  bool get isTeamMatch => hostTeam != null;

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

  /// Hạn tự rời kèo (hoàn 100%).
  DateTime get leaveDeadline => start.subtract(LfgRules.fillDeadlineBeforeStart);

  /// Mốc chủ kèo hủy kèo không bị phạt tiền (mặc định T−48h). Từ mốc này hủy là hủy đơn phương:
  /// mất [hostLateCancelLoss] (chia đều bồi thường cho người đã vào kèo) và bị trừ nặng Fair Play.
  DateTime get hostCancelDeadline => hostCancelUntilOverride ?? start.subtract(LfgRules.hostCancelBeforeStart);

  /// Rời lúc [now] là rời sát giờ (từ T−48h): không hoàn, cọc chuyển cho chủ kèo, bị trừ Fair Play.
  bool isLateLeave(DateTime now) => !now.isBefore(leaveDeadline);

  /// Chủ kèo hủy được tới giờ chơi (BE còn chặn khi đã check-in).
  bool canHostCancel(DateTime now) => now.isBefore(start);

  /// Hủy lúc [now] là hủy đơn phương (từ [hostCancelDeadline] trở đi) → bị phạt giá sân.
  bool isLateHostCancel(DateTime now) => !now.isBefore(hostCancelDeadline);

  /// Số người (đội) đã vào kèo, không tính chủ kèo — những người được bồi thường khi chủ kèo hủy đơn phương.
  int get joinerCount => members.where((m) => !m.isHost).length;

  /// Giá sân chủ kèo mất khi hủy đơn phương; chưa có ai vào kèo thì được hoàn đủ (0).
  int get hostLateCancelLoss =>
      joinerCount == 0 ? 0 : (courtPrice * LfgRules.hostLateCancelLossPercent / 100).round();

  /// Mỗi người đã vào kèo nhận thêm chừng này bồi thường (ngoài Điểm của họ được hoàn 100%).
  int get lateCancelCompensationPerJoiner => joinerCount == 0 ? 0 : (hostLateCancelLoss / joinerCount).round();

  DateTime get fillDeadline => start.subtract(LfgRules.fillDeadlineBeforeStart);

  bool isMember(String userId) => members.any((m) => m.userId == userId);

  bool isHostedBy(String userId) => host.userId == userId;

  LfgStatus status(DateTime now) {
    if (cancelReason != null) return LfgStatus.cancelled;
    if (!end.isAfter(now)) return LfgStatus.completed;
    return isFull ? LfgStatus.confirmed : LfgStatus.open;
  }

  /// Còn nhận người: chưa hủy/chốt, chưa tới T−48h, còn chỗ trống.
  bool isClaimable(DateTime now) => status(now) == LfgStatus.open && now.isBefore(fillDeadline) && slotsLeft > 0;

  /// Mã QR check-in riêng của từng người, dùng tới khi chủ sân check-out.
  String ticketCode(String userId) => 'SPN-LFG-$id-$userId';

  LfgMatch copyWith({
    List<LfgMember>? members,
    int? heldSlots,
    LfgCancelReason? cancelReason,
    int? slotsLeftOverride,
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
        totalSlotsOverride: totalSlotsOverride,
        slotsLeftOverride: slotsLeftOverride ?? this.slotsLeftOverride,
        pricePerPersonOverride: pricePerPersonOverride,
        formatLabelOverride: formatLabelOverride,
        myStatus: myStatus,
        bookingId: bookingId,
        skillLevel: skillLevel,
        hostCancelUntilOverride: hostCancelUntilOverride,
        hostTeam: hostTeam,
        challengerTeam: challengerTeam,
        sideSize: sideSize,
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
        skillLevel: SkillLevel.fromApi(json['skillLevel']),
        slotsLeftOverride: (json['slotsLeftOverride'] as num?)?.toInt(),
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
        if (skillLevel != null) 'skillLevel': skillLevel!.apiValue,
        if (slotsLeftOverride != null) 'slotsLeftOverride': slotsLeftOverride,
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

  /// Chỉ kèo đúng trình độ này; `null` = mọi trình độ.
  final SkillLevel? skillLevel;

  /// Giá mỗi người tối đa; `null` = không giới hạn.
  final int? maxPricePerPerson;

  const LfgFeedQuery({
    required this.city,
    this.district,
    this.sport,
    this.format,
    this.courtType,
    this.userLocation,
    this.skillLevel,
    this.maxPricePerPerson,
  });

  bool get hasExtraFilters => skillLevel != null || maxPricePerPerson != null;
}

/// Kèo gợi ý theo hồ sơ thể thao: điểm phù hợp 0–100 và lý do (do BE tính).
class LfgRecommendation {
  final LfgMatch match;
  final int score;
  final List<String> reasons;
  final double? distanceKm;

  const LfgRecommendation({required this.match, required this.score, this.reasons = const [], this.distanceKm});
}

class LfgFeedItem {
  final LfgMatch match;
  final double? distanceKm;

  const LfgFeedItem({required this.match, this.distanceKm});
}
