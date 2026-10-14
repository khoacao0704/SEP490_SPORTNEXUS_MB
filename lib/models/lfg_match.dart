import '../core/constants/lfg_rules.dart';
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
  /// Còn chỗ, nhận Flash Claim tới T−48h.
  open,

  /// Đủ người, chờ tới T−48h để chốt.
  full,

  /// Đã qua T−48h với đủ người: kèo chắc chắn diễn ra.
  confirmed,
  cancelled,
  completed,
}

enum LfgCancelReason {
  notEnoughPlayers('NotEnoughPlayers'),
  hostCancelled('HostCancelled');

  const LfgCancelReason(this.apiValue);

  final String apiValue;

  static LfgCancelReason fromApi(String value) => values.firstWhere((r) => r.apiValue == value);
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

  /// Đã qua T−48h với đủ người; sau đó có người rời thì chỗ để trống, không mở lại.
  final bool locked;
  final LfgCancelReason? cancelReason;

  const LfgMatch({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.city,
    required this.district,
    required this.location,
    required this.sport,
    required this.format,
    required this.start,
    required this.end,
    required this.courtPrice,
    required this.members,
    required this.createdAt,
    this.heldSlots = 0,
    this.note = '',
    this.locked = false,
    this.cancelReason,
  });

  LfgMember get host => members.firstWhere((m) => m.isHost, orElse: () => members.first);

  int get totalSlots => format.totalSlots;

  /// Chỗ còn có thể Flash Claim (đã trừ chỗ đang được giữ).
  int get slotsLeft => (totalSlots - members.length - heldSlots).clamp(0, totalSlots);

  bool get isFull => members.length >= totalSlots;

  int get depositPerSlot => LfgRules.depositPerSlot(courtPrice, totalSlots);

  DateTime get fillDeadline => start.subtract(LfgRules.fillDeadlineBeforeStart);

  bool isMember(String userId) => members.any((m) => m.userId == userId);

  bool isHostedBy(String userId) => host.userId == userId;

  LfgStatus status(DateTime now) {
    if (cancelReason != null) return LfgStatus.cancelled;
    if (!end.isAfter(now)) return LfgStatus.completed;
    if (locked) return LfgStatus.confirmed;
    return isFull ? LfgStatus.full : LfgStatus.open;
  }

  /// Còn nhận người: chưa hủy/chốt, chưa tới T−48h, còn chỗ trống.
  bool isClaimable(DateTime now) => status(now) == LfgStatus.open && now.isBefore(fillDeadline) && slotsLeft > 0;

  /// Mã QR check-in riêng của từng người, dùng tới khi chủ sân check-out.
  String ticketCode(String userId) => 'SPN-LFG-$id-$userId';

  LfgMatch copyWith({List<LfgMember>? members, int? heldSlots, bool? locked, LfgCancelReason? cancelReason}) =>
      LfgMatch(
        id: id,
        facilityId: facilityId,
        facilityName: facilityName,
        city: city,
        district: district,
        location: location,
        sport: sport,
        format: format,
        start: start,
        end: end,
        courtPrice: courtPrice,
        members: members ?? this.members,
        createdAt: createdAt,
        heldSlots: heldSlots ?? this.heldSlots,
        note: note,
        locked: locked ?? this.locked,
        cancelReason: cancelReason ?? this.cancelReason,
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
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        courtPrice: (json['courtPrice'] as num).toInt(),
        members: (json['members'] as List).map((e) => LfgMember.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        heldSlots: (json['heldSlots'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
        locked: json['locked'] as bool? ?? false,
        cancelReason: json['cancelReason'] == null ? null : LfgCancelReason.fromApi(json['cancelReason'] as String),
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
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'courtPrice': courtPrice,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'heldSlots': heldSlots,
        'note': note,
        'locked': locked,
        if (cancelReason != null) 'cancelReason': cancelReason!.apiValue,
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

  /// Vị trí GPS để tính khoảng cách; `null` thì không tính.
  final GeoPoint? userLocation;

  const LfgFeedQuery({required this.city, this.district, this.sport, this.format, this.userLocation});
}

class LfgFeedItem {
  final LfgMatch match;
  final double? distanceKm;

  const LfgFeedItem({required this.match, this.distanceKm});
}
