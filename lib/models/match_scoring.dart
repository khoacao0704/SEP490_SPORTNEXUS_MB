import 'tournament_listing.dart';

String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' || s == 'TBD' ? null : s;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

Object? _pick(Map j, List<String> keys) {
  for (final k in keys) {
    Object? cur = j;
    for (final part in k.split('.')) {
      cur = cur is Map ? cur[part] : null;
    }
    if (cur != null && '$cur'.isNotEmpty) return cur;
  }
  return null;
}

/// Một bên của trận (id người tham gia + tên).
class MatchSide {
  final String id;
  final String name;

  const MatchSide({required this.id, required this.name});
}

/// Chi tiết một trận (GET /matches/{id}): có id hai bên để chọn người thắng.
class MatchDetail {
  final String id;
  final String tournamentId;
  final String tournamentName;
  final String roundName;
  final String status;
  final MatchStage stage;
  final String sportName;
  final MatchSide? sideA;
  final MatchSide? sideB;
  final List<SetScore> sets;
  final String? winnerId;
  final MatchResultType resultType;
  final int? tiebreakA;
  final int? tiebreakB;

  const MatchDetail({
    required this.id,
    this.tournamentId = '',
    this.tournamentName = '',
    this.roundName = '',
    this.status = 'SCHEDULED',
    this.stage = MatchStage.knockout,
    this.sportName = '',
    this.sideA,
    this.sideB,
    this.sets = const [],
    this.winnerId,
    this.resultType = MatchResultType.normal,
    this.tiebreakA,
    this.tiebreakB,
  });

  bool get isFinished => const {'FINISHED', 'COMPLETED'}.contains(status.toUpperCase());

  List<MatchSide> get sides => [?sideA, ?sideB];

  /// Bóng đá: hòa ở loại trực tiếp phải có luân lưu; vòng bảng / vòng tròn được hòa.
  bool get isFootball {
    final s = sportName.toLowerCase();
    return RegExp('bóng đá|bong da|futsal|football|soccer').hasMatch(s);
  }

  static MatchSide? _side(Map j, List<String> prefixes) {
    for (final p in prefixes) {
      final id = _str(_pick(j, ['${p}Id', '$p.id', '${p}ParticipantId']));
      final raw = j[p];
      final name = _str(raw is String ? raw : null) ?? _str(_pick(j, ['${p}Name', '$p.name', '$p.fullName', '$p.teamName']));
      if (id != null || name != null) return MatchSide(id: id ?? '', name: name ?? '');
    }
    return null;
  }

  factory MatchDetail.fromApi(Map<String, dynamic> j) => MatchDetail(
    id: _str(_pick(j, ['id', 'matchId'])) ?? '',
    tournamentId: _str(j['tournamentId']) ?? '',
    tournamentName: _str(j['tournamentName']) ?? '',
    roundName: (_str(j['roundName']) ?? '').replaceAll(RegExp(r'\s*\(miễn đấu\)', caseSensitive: false), ''),
    status: _str(_pick(j, ['status', 'matchStatus'])) ?? 'SCHEDULED',
    stage: MatchStage.fromApi(j['stage']),
    sportName: _str(_pick(j, ['sportName', 'categoryName'])) ?? '',
    sideA: _side(j, ['participant1', 'player1', 'team1', 'p1']),
    sideB: _side(j, ['participant2', 'player2', 'team2', 'p2']),
    sets: [
      for (final s in (j['scores'] ?? j['sets'] ?? const []) as List)
        if (s is Map && s['isTiebreak'] != true)
          SetScore(set: _int(s['setNumber']) ?? 0, a: _int(s['scoreP1']) ?? 0, b: _int(s['scoreP2']) ?? 0),
    ],
    winnerId: _str(_pick(j, ['winnerId', 'winner.id'])),
    resultType: MatchResultType.fromApi(j['resultType']),
    tiebreakA: _int(j['tiebreakP1']),
    tiebreakB: _int(j['tiebreakP2']),
  );
}

/// Kiểu kết quả BTC / trọng tài chọn khi nhập tỉ số (hòa do BE tự nhận khi tỉ số bằng nhau).
enum ScoreKind {
  normal('NORMAL', 'Thi đấu bình thường'),
  walkover('WALKOVER', 'Xử thắng (đối thủ không ra sân)'),
  retired('RETIRED', 'Bỏ cuộc giữa trận');

  const ScoreKind(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Chặn nhập tỉ số theo điểm danh (trận chưa có kết quả).
enum CheckInGateMode { ok, walkoverOnly, blocked }

class CheckInGate {
  final CheckInGateMode mode;
  final List<MatchSide> present;
  final List<MatchSide> absent;

  const CheckInGate({required this.mode, this.present = const [], this.absent = const []});

  String get message {
    final names = absent.map((s) => s.name).join(', ');
    return switch (mode) {
      CheckInGateMode.ok => '',
      CheckInGateMode.walkoverOnly =>
        '$names chưa điểm danh: chỉ được xử thắng cho ${present.first.name}, hoặc điểm danh trước khi nhập tỉ số.',
      CheckInGateMode.blocked => '$names chưa điểm danh: cần điểm danh trước khi nhập kết quả.',
    };
  }
}

// ---------------- Lịch sân của giải ----------------

/// Khung sân đang giữ cho giải (GET /court-schedule → blocks).
class CourtBlock {
  final String courtName;
  final DateTime start;
  final DateTime end;
  final int slotCount;

  const CourtBlock({required this.courtName, required this.start, required this.end, this.slotCount = 0});
}

/// Trận đã xếp vào sân (GET /court-schedule → matches).
class ScheduledMatch {
  final String matchId;
  final String courtName;
  final DateTime start;
  final DateTime? end;
  final String status;
  final String roundName;

  const ScheduledMatch({
    required this.matchId,
    required this.courtName,
    required this.start,
    this.end,
    this.status = '',
    this.roundName = '',
  });

  bool get isFinished => const {'FINISHED', 'COMPLETED'}.contains(status.toUpperCase());
}

class CourtSchedule {
  final List<CourtBlock> blocks;
  final List<ScheduledMatch> matches;

  const CourtSchedule({this.blocks = const [], this.matches = const []});

  factory CourtSchedule.fromApi(Object? data) {
    final map = data is Map ? data : const {};
    return CourtSchedule(
      blocks: [
        for (final b in (map['blocks'] as List? ?? const []).whereType<Map>())
          if (_date(b['startTime']) != null)
            CourtBlock(
              courtName: _str(b['courtName']) ?? '',
              start: _date(b['startTime'])!,
              end: _date(b['endTime']) ?? _date(b['startTime'])!,
              slotCount: _int(b['slotCount']) ?? 0,
            ),
      ],
      matches: [
        for (final m in (map['matches'] as List? ?? const []).whereType<Map>())
          if (_date(m['startTime']) != null && _str(m['courtName']) != null)
            ScheduledMatch(
              matchId: _str(m['matchId']) ?? '',
              courtName: _str(m['courtName'])!,
              start: _date(m['startTime'])!,
              end: _date(m['endTime']),
              status: _str(m['status']) ?? '',
              roundName: _str(m['roundName']) ?? '',
            ),
      ],
    );
  }

  ScheduledMatch? of(String matchId) => matches.where((m) => m.matchId == matchId).firstOrNull;
}

/// Một ca sân xếp được cho trận: ca đã giữ cho giải này hoặc ca còn trống, chưa qua.
class AssignableSlot {
  final String id;
  final String courtName;
  final DateTime start;
  final DateTime end;
  final bool reservedForTournament;

  const AssignableSlot({
    required this.id,
    required this.courtName,
    required this.start,
    required this.end,
    this.reservedForTournament = false,
  });

  /// Lọc ca từ GET /facilities/{id}/slots?date (như AssignCourtModal của Web).
  static List<AssignableSlot> fromFacilitySlots(Object? data, String tournamentId) {
    final map = data is Map ? data : const {};
    final out = <AssignableSlot>[];
    for (final c in (map['courts'] as List? ?? const []).whereType<Map>()) {
      for (final s in (c['slots'] as List? ?? const []).whereType<Map>()) {
        final reserved = '${s['tournamentId'] ?? ''}' == tournamentId && tournamentId.isNotEmpty;
        final available = '${s['status'] ?? ''}'.toUpperCase() == 'AVAILABLE';
        if (s['isPast'] == true || _str(s['bookingId']) != null || _str(s['matchId']) != null) continue;
        if (!reserved && !available) continue;
        final start = _date(s['startTime']);
        final end = _date(s['endTime']);
        final id = _str(s['id'] ?? s['slotId']);
        if (start == null || end == null || id == null) continue;
        out.add(AssignableSlot(
          id: id,
          courtName: _str(c['courtName']) ?? '',
          start: start,
          end: end,
          reservedForTournament: reserved,
        ));
      }
    }
    return out..sort((a, b) => a.start.compareTo(b.start));
  }
}

// ---------------- Khiếu nại kết quả trận (phía BTC) ----------------

enum ComplaintStatus {
  pending('PENDING', 'Chờ BTC xử lý'),
  organizerResponded('OWNER_RESPONDED', 'BTC đã quyết định, chờ Admin'),
  rejected('REJECTED', 'Đã bác, giữ kết quả'),
  resolved('RESOLVED_NO_REFUND', 'Khiếu nại đúng'),
  other('', '');

  const ComplaintStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ComplaintStatus fromApi(Object? v) {
    final key = '${v ?? ''}'.toUpperCase();
    return values.where((s) => s != other && s.apiValue == key).firstOrNull ?? other;
  }
}

class MatchComplaintItem {
  final String id;
  final String matchId;
  final String roundName;
  final String sideA;
  final String sideB;
  final String winnerName;
  final String reporterName;
  final String reason;
  final String description;
  final List<String> evidenceUrls;
  final ComplaintStatus status;
  final String rawStatus;
  final String resolutionNote;
  final DateTime? createdAt;

  const MatchComplaintItem({
    required this.id,
    required this.matchId,
    this.roundName = '',
    this.sideA = '',
    this.sideB = '',
    this.winnerName = '',
    this.reporterName = '',
    this.reason = '',
    this.description = '',
    this.evidenceUrls = const [],
    this.status = ComplaintStatus.pending,
    this.rawStatus = '',
    this.resolutionNote = '',
    this.createdAt,
  });

  bool get canAct => status == ComplaintStatus.pending;

  String get statusLabel => status == ComplaintStatus.other ? rawStatus : status.label;

  factory MatchComplaintItem.fromApi(Map<String, dynamic> j) => MatchComplaintItem(
    id: _str(j['id']) ?? '',
    matchId: _str(j['matchId']) ?? '',
    roundName: _str(j['roundName']) ?? '',
    sideA: _str(j['participant1Name']) ?? '—',
    sideB: _str(j['participant2Name']) ?? '—',
    winnerName: _str(j['winnerName']) ?? '',
    reporterName: _str(j['reporterName']) ?? '',
    reason: _str(j['reason']) ?? '',
    description: _str(j['description']) ?? '',
    evidenceUrls: [
      for (final u in (j['evidenceImageUrls'] as List? ?? const []))
        if (_str(u) != null) _str(u)!,
    ],
    status: ComplaintStatus.fromApi(j['status']),
    rawStatus: _str(j['status']) ?? '',
    resolutionNote: _str(j['resolutionNote']) ?? '',
    createdAt: _date(j['createdAt']),
  );
}

// ---------------- Trọng tài (đợt 5) ----------------

/// Một trận tôi là nhân sự có tài khoản (GET /tournaments/my-staff-matches): trận chưa đá + trận xong trong 72 giờ.
class StaffMatch {
  final String matchId;
  final String tournamentId;
  final String tournamentName;
  final String facilityName;
  final String roundName;
  final String status;
  final DateTime? start;
  final String courtName;
  final String sideA;
  final String sideB;
  final String staffRole;
  final bool isAssignedOfficial;

  const StaffMatch({
    required this.matchId,
    required this.tournamentId,
    this.tournamentName = '',
    this.facilityName = '',
    this.roundName = '',
    this.status = '',
    this.start,
    this.courtName = '',
    this.sideA = '',
    this.sideB = '',
    this.staffRole = '',
    this.isAssignedOfficial = false,
  });

  bool get isFinished => const {'FINISHED', 'COMPLETED'}.contains(status.toUpperCase());

  /// Trận miễn đấu tự có kết quả, không có gì để nhập.
  bool get isBye => RegExp('miễn đấu', caseSensitive: false).hasMatch(roundName);

  bool get hasBothSides => sideA.isNotEmpty && sideB.isNotEmpty;

  /// Chờ nhập tỉ số: chưa xong và đủ hai bên.
  bool get isReady => !isFinished && hasBothSides;

  String get roleLabel => switch (staffRole.toUpperCase()) {
    'REFEREE' => 'Trọng tài',
    'SCORER' => 'Người nhập điểm',
    'OTHER' => 'Nhân sự',
    _ => staffRole,
  };

  factory StaffMatch.fromApi(Map<String, dynamic> j) => StaffMatch(
    matchId: _str(_pick(j, ['matchId', 'id'])) ?? '',
    tournamentId: _str(_pick(j, ['rootTournamentId', 'tournamentId'])) ?? '',
    tournamentName: _str(_pick(j, ['rootTournamentName', 'tournamentName'])) ?? '',
    facilityName: _str(j['facilityName']) ?? '',
    roundName: _str(j['roundName']) ?? '',
    status: _str(j['status']) ?? '',
    start: _date(j['startTime']),
    courtName: _str(j['courtName']) ?? '',
    sideA: _str(j['participant1Name']) ?? '',
    sideB: _str(j['participant2Name']) ?? '',
    staffRole: _str(j['staffRole']) ?? '',
    isAssignedOfficial: j['isAssignedOfficial'] == true,
  );
}

// ---------------- Giữ / trả ca sân cho giải (chủ sân, đợt 5) ----------------

/// Body POST /tournaments/{id}/court-blocks và /court-blocks/release. Trả ca: bỏ trống sân và giờ = trả mọi ca chưa tới giờ.
class CourtBlockRequest {
  final List<String> courtIds;
  final DateTime dateFrom;
  final DateTime dateTo;

  /// 'HH:mm' (trống = cả ngày).
  final String? startTime;
  final String? endTime;

  const CourtBlockRequest({
    this.courtIds = const [],
    required this.dateFrom,
    required this.dateTo,
    this.startTime,
    this.endTime,
  });

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? _span(String? t) => t == null || t.isEmpty ? null : (t.length == 5 ? '$t:00' : t);

  Map<String, dynamic> toJson() => {
    'courtIds': courtIds.isEmpty ? null : courtIds,
    'dateFrom': _day(dateFrom),
    'dateTo': _day(dateTo),
    'startTime': _span(startTime),
    'endTime': _span(endTime),
  };
}

/// Ca không giữ được (đã có khách đặt…).
class CourtBlockConflict {
  final String courtName;
  final DateTime? start;
  final String reason;

  const CourtBlockConflict({required this.courtName, this.start, this.reason = ''});
}

class CourtBlockResult {
  /// Số ca vừa giữ / vừa trả.
  final int slots;
  final int alreadyBlocked;
  final List<CourtBlockConflict> conflicts;

  const CourtBlockResult({this.slots = 0, this.alreadyBlocked = 0, this.conflicts = const []});

  factory CourtBlockResult.fromApi(Object? data) {
    final j = data is Map ? data : const {};
    return CourtBlockResult(
      slots: _int(j['blockedSlots'] ?? j['releasedSlots'] ?? j['matchedSlots']) ?? 0,
      alreadyBlocked: _int(j['alreadyBlockedSlots']) ?? 0,
      conflicts: [
        for (final c in (j['conflicts'] as List? ?? const []).whereType<Map>())
          CourtBlockConflict(
            courtName: _str(c['courtName']) ?? '',
            start: _date(c['startTime']),
            reason: _str(c['reason']) ?? '',
          ),
      ],
    );
  }
}
