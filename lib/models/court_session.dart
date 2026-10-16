import '../core/constants/owner_rules.dart';
import 'court_type.dart';
import 'sport.dart';

/// Lượt sân đến từ đặt sân thường hay kèo LFG.
enum SessionKind {
  booking('Booking'),
  lfg('Lfg');

  const SessionKind(this.apiValue);

  final String apiValue;

  static SessionKind fromApi(String value) => values.firstWhere((k) => k.apiValue == value);
}

/// Trạng thái lượt sân nhìn từ phía Chủ sân.
enum SessionStatus {
  /// Chưa tới giờ mở check-in.
  upcoming,

  /// Trong khung check-in (T−30 phút tới T+15 phút), chưa ai check-in.
  waitingCheckIn,

  /// Đã có người check-in, đang chơi hoặc chờ chủ sân check-out.
  playing,

  /// Quá T+15 phút không ai check-in: hệ thống tự đánh vắng.
  noShow,

  /// Chủ sân đã check-out, tiền đã giải ngân.
  completed,
  cancelled,
}

enum CheckInBlock { cancelled, completed, alreadyCheckedIn, notOpen, closed }

/// Một người chơi trong lượt sân. Booking thường chỉ có người đặt; kèo LFG mỗi người một vé QR.
class SessionPlayer {
  final String userId;
  final String name;
  final String ticketCode;
  final DateTime? checkedInAt;

  const SessionPlayer({
    required this.userId,
    required this.name,
    required this.ticketCode,
    this.checkedInAt,
  });

  bool get isCheckedIn => checkedInAt != null;

  SessionPlayer copyWith({DateTime? checkedInAt}) => SessionPlayer(
        userId: userId,
        name: name,
        ticketCode: ticketCode,
        checkedInAt: checkedInAt ?? this.checkedInAt,
      );

  factory SessionPlayer.fromJson(Map<String, dynamic> json) => SessionPlayer(
        userId: json['userId'] as String,
        name: json['name'] as String,
        ticketCode: json['ticketCode'] as String,
        checkedInAt: json['checkedInAt'] == null ? null : DateTime.parse(json['checkedInAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'ticketCode': ticketCode,
        'checkedInAt': checkedInAt?.toIso8601String(),
      };
}

/// Một lượt sử dụng một sân trong một khung giờ tại cơ sở của Chủ sân.
/// Check-in quét QR từng người; check-out một lần cho cả lượt sân và giải ngân escrow.
class CourtSession {
  final String id;
  final SessionKind kind;
  final String facilityId;
  final String facilityName;
  final Sport sport;
  final CourtType courtType;
  final DateTime start;
  final DateTime end;
  final int totalPrice;

  /// Tiền người chơi đã trả qua app, đang giữ ở escrow.
  final int paidViaApp;

  /// Người đặt (booking) hoặc host (LFG) đứng đầu.
  final List<SessionPlayer> players;

  /// Sân con người chơi đã chọn lúc đặt sân / tạo kèo, vd. "Sân 2".
  final String assignedCourt;
  final DateTime? checkedOutAt;
  final DateTime? cancelledAt;

  const CourtSession({
    required this.id,
    required this.kind,
    required this.facilityId,
    required this.facilityName,
    required this.sport,
    this.courtType = CourtType.standard,
    required this.start,
    required this.end,
    required this.totalPrice,
    required this.paidViaApp,
    required this.players,
    required this.assignedCourt,
    this.checkedOutAt,
    this.cancelledAt,
  });

  /// "Cầu Lông" hoặc "Bóng Đá • Sân 7 người".
  String get sportLabel => courtType.isStandard ? sport.label : '${sport.label} • ${courtType.label}';

  SessionPlayer get leader => players.first;

  /// Phần còn lại (cọc 1/4) chủ sân tự thu; bấm check-out là xác nhận đã nhận đủ tiền sân.
  int get remainingToCollect => (totalPrice - paidViaApp).clamp(0, totalPrice);

  DateTime get checkInOpensAt => start.subtract(OwnerRules.checkInOpensBefore);
  DateTime get checkInClosesAt => start.add(OwnerRules.checkInClosesAfter);

  bool isCheckInWindow(DateTime now) => !now.isBefore(checkInOpensAt) && !now.isAfter(checkInClosesAt);

  int get checkedInCount => players.where((p) => p.isCheckedIn).length;

  /// Người chưa check-in khi đã qua T+15 phút: hệ thống đánh vắng (BE trừ Fair Play), app chỉ hiển thị.
  bool isAbsent(SessionPlayer p, DateTime now) => !p.isCheckedIn && now.isAfter(checkInClosesAt);

  SessionStatus status(DateTime now) {
    if (cancelledAt != null) return SessionStatus.cancelled;
    if (checkedOutAt != null) return SessionStatus.completed;
    if (checkedInCount > 0) return SessionStatus.playing;
    if (now.isAfter(checkInClosesAt)) return SessionStatus.noShow;
    if (isCheckInWindow(now)) return SessionStatus.waitingCheckIn;
    return SessionStatus.upcoming;
  }

  /// Lý do chưa check-in được [p] lúc [now]; `null` là check-in được.
  CheckInBlock? checkInBlock(SessionPlayer p, DateTime now) {
    if (cancelledAt != null) return CheckInBlock.cancelled;
    if (checkedOutAt != null) return CheckInBlock.completed;
    if (p.isCheckedIn) return CheckInBlock.alreadyCheckedIn;
    if (now.isBefore(checkInOpensAt)) return CheckInBlock.notOpen;
    if (now.isAfter(checkInClosesAt)) return CheckInBlock.closed;
    return null;
  }

  bool canCheckIn(SessionPlayer p, DateTime now) => checkInBlock(p, now) == null;

  bool canCheckOut(DateTime now) => status(now) == SessionStatus.playing;

  /// Đã hết giờ chơi nhưng chủ sân chưa check-out.
  bool isOverdueCheckOut(DateTime now) => canCheckOut(now) && !now.isBefore(end);

  CourtSession copyWith({
    List<SessionPlayer>? players,
    DateTime? checkedOutAt,
  }) =>
      CourtSession(
        id: id,
        kind: kind,
        facilityId: facilityId,
        facilityName: facilityName,
        sport: sport,
        courtType: courtType,
        start: start,
        end: end,
        totalPrice: totalPrice,
        paidViaApp: paidViaApp,
        players: players ?? this.players,
        assignedCourt: assignedCourt,
        checkedOutAt: checkedOutAt ?? this.checkedOutAt,
        cancelledAt: cancelledAt,
      );

  factory CourtSession.fromJson(Map<String, dynamic> json) => CourtSession(
        id: json['id'] as String,
        kind: SessionKind.fromApi(json['kind'] as String),
        facilityId: json['facilityId'] as String,
        facilityName: json['facilityName'] as String,
        sport: Sport.fromApi(json['sport'] as String),
        courtType: CourtType.fromApi(json['courtType'] as String?),
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        totalPrice: (json['totalPrice'] as num).toInt(),
        paidViaApp: (json['paidViaApp'] as num).toInt(),
        players: (json['players'] as List).map((e) => SessionPlayer.fromJson(e as Map<String, dynamic>)).toList(),
        assignedCourt: json['assignedCourt'] as String,
        checkedOutAt: json['checkedOutAt'] == null ? null : DateTime.parse(json['checkedOutAt'] as String),
        cancelledAt: json['cancelledAt'] == null ? null : DateTime.parse(json['cancelledAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.apiValue,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'sport': sport.apiValue,
        'courtType': courtType.apiValue,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'totalPrice': totalPrice,
        'paidViaApp': paidViaApp,
        'players': players.map((p) => p.toJson()).toList(),
        'assignedCourt': assignedCourt,
        'checkedOutAt': checkedOutAt?.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
      };
}

/// Kết quả tra mã QR: vé của người nào, thuộc lượt sân nào.
class TicketLookup {
  final CourtSession session;
  final SessionPlayer player;

  const TicketLookup({required this.session, required this.player});
}
