import '../../core/constants/tournament_rules.dart';
import '../../models/match_scoring.dart';
import '../../models/organized_tournament.dart';
import '../../models/owner_court.dart';
import '../../models/tournament_listing.dart';
import '../../models/tournament_management.dart';
import '../repositories/host_tournament_repository.dart';
import '../repositories/tournament_repository.dart';

/// Giả lập tổ chức giải: giữ trong bộ nhớ, giải mới luôn chờ Admin duyệt.
class MockHostTournamentRepository implements HostTournamentRepository {
  final Duration latency;
  final DateTime Function() now;

  MockHostTournamentRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now})
    : now = now ?? DateTime.now {
    final today = this.now();
    final d = DateTime(today.year, today.month, today.day);
    _items.addAll([
      OrganizedTournament(
        id: 'ht-1',
        name: 'Giải Pickleball Giao lưu Quận 7',
        approval: ApprovalStatus.approved,
        sportName: 'Pickleball',
        facilityId: 'f-sunrise',
        facilityName: 'Sân Pickleball Sunrise',
        facilityAddress: '12 Nguyễn Thị Thập, Quận 7',
        start: d.add(const Duration(days: 10)),
        end: d.add(const Duration(days: 11)),
        deadline: d.add(const Duration(days: 8)),
        tier: TournamentTier.amateur,
        purpose: TournamentPurpose.exchange,
        format: BracketFormat.knockout,
        maxParticipants: 8,
        registeredCount: 3,
        entryFee: 100000,
        prizes: const [OrganizerPrize(position: 'Vô địch', amount: 1000000)],
        description: 'Giao lưu cuối tuần, mọi trình độ.',
      ),
      OrganizedTournament(
        id: 'ht-2',
        name: 'Giải Cầu Lông Bán chuyên',
        approval: ApprovalStatus.rejected,
        approvalNote: 'Thiếu hợp đồng thuê sân.',
        sportName: 'Cầu Lông',
        facilityName: 'Nhà thi đấu Phú Thọ',
        start: d.add(const Duration(days: 20)),
        end: d.add(const Duration(days: 21)),
        deadline: d.add(const Duration(days: 18)),
        tier: TournamentTier.semiPro,
        purpose: TournamentPurpose.commercial,
        format: BracketFormat.roundRobin,
        maxParticipants: 6,
        minRating: 1200,
        maxRating: 1600,
        minRatedMatches: 3,
      ),
      // Giải nội bộ theo đội đã quá hạn đăng ký mà mới có 1 đội: BTC phải chọn vẫn thi đấu hay hủy.
      OrganizedTournament(
        id: 'ht-3',
        name: 'Giải Cầu Lông Nội bộ CLB',
        approval: ApprovalStatus.approved,
        sportName: 'Cầu Lông',
        categoryId: 'c-badminton',
        facilityName: 'Nhà thi đấu Phú Thọ',
        start: d.add(const Duration(days: 2)),
        end: d.add(const Duration(days: 2)),
        deadline: d.subtract(const Duration(hours: 2)),
        tier: TournamentTier.amateur,
        purpose: TournamentPurpose.internal,
        type: DivisionType.premadeTeams,
        format: BracketFormat.knockout,
        maxParticipants: 8,
        registeredCount: 1,
      ),
    ]);
  }

  final List<OrganizedTournament> _items = [];
  int _seq = 0;

  final Map<String, List<OrganizerParticipant>> _participants = {
    'ht-3': [
      const OrganizerParticipant(
        participantId: 'p-t1',
        name: 'Khoa Cao',
        teamName: 'Smash Q7',
        members: ['Khoa Cao', 'Lê Minh Tuấn'],
        paymentStatus: 'PAID',
      ),
    ],
    'ht-1': [
      const OrganizerParticipant(
        participantId: 'p-1',
        name: 'Khoa Cao',
        username: 'player1',
        paymentStatus: 'PAID',
        isCheckedIn: true,
      ),
      const OrganizerParticipant(participantId: 'p-2', name: 'Lê Minh Tuấn', username: 'tuanle', paymentStatus: 'PAID'),
      const OrganizerParticipant(
        participantId: 'p-3',
        name: 'Phạm Thu Hà',
        username: 'thuha',
        paymentStatus: 'PENDING',
      ),
    ],
  };
  final Map<String, List<OrganizerInvitation>> _invitations = {};
  final Map<String, List<TournamentStaffMember>> _staff = {};
  final Map<String, List<BracketMatch>> _brackets = {};

  static const List<TeamOption> teams = [
    TeamOption(id: 'team-1', name: 'Smash Q7', captainName: 'Khoa Cao', totalMembers: 2),
    TeamOption(id: 'team-2', name: 'Cầu Lông Phú Thọ', captainName: 'Nguyễn Văn Nam', totalMembers: 4),
  ];

  /// Số điện thoại → tài khoản (giả lập tra cứu).
  static const Map<String, AccountMatch> accounts = {
    '0912345678': AccountMatch(id: 'u-ref-1', fullName: 'Trọng Tài Minh'),
    '0901234567': AccountMatch(id: 'u-player-001', fullName: 'Khoa Cao'),
  };

  static const List<FacilityOption> facilities = [
    FacilityOption(id: 'f-sunrise', name: 'Sân Pickleball Sunrise', address: '12 Nguyễn Thị Thập, Quận 7, Hồ Chí Minh'),
    FacilityOption(id: 'f-phutho', name: 'Nhà thi đấu Phú Thọ', address: '1 Lữ Gia, Quận 11, Hồ Chí Minh'),
    FacilityOption(id: 'f-cau-giay', name: 'Sân cầu lông Cầu Giấy', address: '25 Trần Duy Hưng, Hà Nội'),
  ];

  static const List<SportCategory> sports = [
    SportCategory(id: 'c-badminton', name: 'Cầu Lông'),
    SportCategory(id: 'c-pickleball', name: 'Pickleball'),
    SportCategory(id: 'c-tennis', name: 'Tennis'),
    SportCategory(id: 'c-football', name: 'Bóng Đá'),
  ];

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  int _index(String id) {
    final i = _items.indexWhere((t) => t.id == id);
    if (i < 0) throw const TournamentException('Không tìm thấy giải đấu.');
    return i;
  }

  @override
  Future<List<OrganizedTournament>> getMine({bool facilityScope = false}) async {
    await _delay();
    return facilityScope ? const [] : List.unmodifiable(_items);
  }

  @override
  Future<OrganizedTournament> getDetail(String tournamentId) async {
    await _delay();
    return _items[_index(tournamentId)];
  }

  @override
  Future<ApprovalStatus> create(NewTournament draft) async {
    await _delay();
    final error = TournamentRules.validateDates(
      start: draft.start,
      end: draft.end,
      deadline: draft.deadline,
      today: now(),
    );
    if (error != null) throw TournamentException(error);
    final facility = facilities.where((f) => f.id == draft.facilityId).firstOrNull;
    final sport = sports.where((s) => s.id == draft.categoryId).firstOrNull;
    _items.insert(
      0,
      OrganizedTournament(
        id: 'ht-new-${++_seq}',
        name: draft.name.trim(),
        approval: ApprovalStatus.pending,
        sportName: sport?.name ?? '',
        facilityId: draft.facilityId,
        facilityName: facility?.name ?? '',
        facilityAddress: facility?.address ?? '',
        start: draft.start,
        end: draft.end,
        deadline: draft.deadline,
        tier: draft.tier,
        purpose: draft.purpose,
        type: draft.type,
        format: draft.format,
        maxParticipants: draft.maxParticipants,
        entryFee: draft.entryFee,
        prizes: [
          for (final p in draft.prizes)
            if (p.position.trim().isNotEmpty && p.amount > 0) p,
        ],
        description: draft.description.trim(),
        minRating: draft.minRating,
        maxRating: draft.maxRating,
        minRatedMatches: draft.minRatedMatches,
        documents: [...draft.rulesFiles, ?draft.contract],
        requestedSchedule: draft.schedule,
      ),
    );
    return ApprovalStatus.pending;
  }

  @override
  Future<void> updateInfo(String tournamentId, TournamentInfoUpdate update) async {
    await _delay();
    final i = _index(tournamentId);
    final t = _items[i];
    if (update.entryFee != null && !t.canEditFee) {
      throw const TournamentException('Chỉ sửa lệ phí khi giải còn mở và chưa có ai đăng ký.');
    }
    _items[i] = t.copyWith(
      name: update.name,
      start: update.start,
      end: update.end,
      deadline: update.deadline,
      imageUrl: update.imageUrl,
      description: update.description,
      entryFee: update.entryFee,
    );
  }

  @override
  Future<void> cancel(String tournamentId, String reason) async {
    await _delay();
    final i = _index(tournamentId);
    if (!TournamentRules.canOrganizerCancel(_items[i].deadline, now())) {
      throw const TournamentException('Ban tổ chức chỉ được hủy giải tới 24 giờ trước hạn đăng ký.');
    }
    _items[i] = _items[i].copyWith(status: 'CANCELLED', cancellationReason: reason.trim());
  }

  @override
  Future<void> delete(String tournamentId) async {
    await _delay();
    final i = _index(tournamentId);
    if (!_items[i].canDelete) throw const TournamentException('Giải đã có người đăng ký, hãy hủy giải trước.');
    _items.removeAt(i);
  }

  @override
  Future<String> uploadDocument(String filePath) async {
    await _delay();
    return 'https://files.sportnexus.vn/docs/${filePath.split(RegExp(r'[\\/]')).last}';
  }

  @override
  Future<String> uploadImage(String filePath) async {
    await _delay();
    return 'https://files.sportnexus.vn/images/${filePath.split(RegExp(r'[\\/]')).last}';
  }

  @override
  Future<List<FacilityOption>> getFacilities() async {
    await _delay();
    return facilities;
  }

  @override
  Future<List<SportCategory>> getSports() async {
    await _delay();
    return sports;
  }

  void _setCount(String id) {
    final i = _items.indexWhere((t) => t.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(registeredCount: (_participants[id] ?? const []).length);
  }

  @override
  Future<List<OrganizerParticipant>> getParticipants(String tournamentId) async {
    await _delay();
    return List.unmodifiable(_participants[tournamentId] ?? const []);
  }

  @override
  Future<void> removeParticipant(String tournamentId, String participantId) async {
    await _delay();
    if (!_items[_index(tournamentId)].isOpen) {
      throw const TournamentException('Giải đã chốt danh sách, không xóa được người tham gia.');
    }
    _participants[tournamentId]?.removeWhere((p) => p.participantId == participantId);
    _setCount(tournamentId);
  }

  @override
  Future<void> checkIn(String tournamentId, String participantId) async {
    await _delay();
    final list = _participants[tournamentId] ?? [];
    final i = list.indexWhere((p) => p.participantId == participantId);
    if (i < 0) throw const TournamentException('Không tìm thấy người tham gia.');
    final p = list[i];
    if (!p.isPaid) throw const TournamentException('Người tham gia chưa đóng lệ phí, chưa điểm danh được.');
    list[i] = OrganizerParticipant(
      participantId: p.participantId,
      name: p.name,
      username: p.username,
      teamName: p.teamName,
      members: p.members,
      paymentStatus: p.paymentStatus,
      isCheckedIn: true,
      avatarUrl: p.avatarUrl,
    );
  }

  @override
  Future<List<OrganizerInvitation>> getInvitations(String tournamentId) async {
    await _delay();
    return List.unmodifiable(_invitations[tournamentId] ?? const []);
  }

  @override
  Future<void> invite(String tournamentId, {String? phone, String? teamId}) async {
    await _delay();
    final t = _items[_index(tournamentId)];
    if (t.purpose != TournamentPurpose.internal) throw const TournamentException('Chỉ giải nội bộ mới gửi lời mời.');
    final list = _invitations.putIfAbsent(tournamentId, () => []);
    if (t.type == DivisionType.premadeTeams) {
      final team = teams.where((x) => x.id == teamId).firstOrNull;
      if (team == null) throw const TournamentException('Bảng đấu theo đội: vui lòng chọn đội (teamId) để mời.');
      list.add(
        OrganizerInvitation(
          id: 'inv-${++_seq}',
          inviteeName: team.captainName,
          teamName: team.name,
          status: TournamentInvitationStatus.pending,
        ),
      );
      return;
    }
    final account = accounts[phone?.trim()];
    if (account == null) throw const TournamentException('Không tìm thấy tài khoản với số điện thoại này.');
    list.add(
      OrganizerInvitation(
        id: 'inv-${++_seq}',
        inviteeName: account.fullName,
        status: TournamentInvitationStatus.pending,
      ),
    );
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await _delay();
    for (final list in _invitations.values) {
      final i = list.indexWhere((x) => x.id == invitationId);
      if (i >= 0) {
        final x = list[i];
        list[i] = OrganizerInvitation(
          id: x.id,
          inviteeName: x.inviteeName,
          teamName: x.teamName,
          status: TournamentInvitationStatus.cancelled,
        );
      }
    }
  }

  @override
  Future<List<TeamOption>> searchTeams(String keyword, {String? categoryId}) async {
    await _delay();
    final q = TournamentRules.fold(keyword.trim());
    return [
      for (final t in teams)
        if (q.isNotEmpty && TournamentRules.fold('${t.name} ${t.captainName}').contains(q)) t,
    ];
  }

  @override
  Future<void> decideRegistration(String tournamentId, {required bool proceed, String reason = ''}) async {
    await _delay();
    final i = _index(tournamentId);
    if (!proceed) {
      _items[i] = _items[i].copyWith(status: 'CANCELLED', cancellationReason: reason.trim());
      return;
    }
    if ((_participants[tournamentId] ?? const []).length < 2) {
      throw const TournamentException('Cần ít nhất 2 người để thi đấu.');
    }
  }

  @override
  Future<List<TournamentStaffMember>> getStaff(String tournamentId) async {
    await _delay();
    return List.unmodifiable(_staff[tournamentId] ?? const []);
  }

  TournamentStaffMember _member(String id, StaffDraft d) => TournamentStaffMember(
    id: id,
    fullName: d.fullName.trim(),
    phone: d.phone.trim(),
    role: d.role,
    accountId: d.accountId,
    note: d.note.trim(),
  );

  @override
  Future<void> addStaff(String tournamentId, StaffDraft draft) async {
    await _delay();
    if (draft.role.needsAccount && draft.accountId == null) {
      throw const TournamentException('Trọng tài / người ghi điểm phải có tài khoản.');
    }
    _staff.putIfAbsent(tournamentId, () => []).add(_member('st-${++_seq}', draft));
  }

  @override
  Future<void> updateStaff(String tournamentId, String staffId, StaffDraft draft) async {
    await _delay();
    final list = _staff[tournamentId] ?? [];
    final i = list.indexWhere((m) => m.id == staffId);
    if (i < 0) throw const TournamentException('Không tìm thấy nhân sự.');
    list[i] = _member(staffId, draft);
  }

  @override
  Future<void> removeStaff(String tournamentId, String staffId) async {
    await _delay();
    _staff[tournamentId]?.removeWhere((m) => m.id == staffId);
  }

  @override
  Future<AccountMatch?> lookupAccount(String phone) async {
    await _delay();
    return accounts[phone.trim()];
  }

  @override
  Future<void> randomPairing(String tournamentId) async {
    await _delay();
  }

  @override
  Future<void> generateBracket(String tournamentId, BracketFormat? format) async {
    await _delay();
    final i = _index(tournamentId);
    final people = _participants[tournamentId] ?? const [];
    final f = format ?? _items[i].format ?? BracketFormat.knockout;
    final error = people.length < 2
        ? 'Cần ít nhất 2 người để sinh sơ đồ.'
        : TournamentRules.formatError(f, people.length);
    if (error != null) throw TournamentException(error);
    final matches = <BracketMatch>[];
    for (var k = 0; k * 2 < people.length; k++) {
      final a = people[k * 2].displayName;
      final hasB = k * 2 + 1 < people.length;
      matches.add(
        BracketMatch(
          id: 'm-$tournamentId-$k',
          index: k,
          roundName: people.length <= 2
              ? 'Chung kết'
              : people.length <= 4
              ? 'Bán kết'
              : 'Tứ kết',
          sideA: a,
          sideB: hasB ? people[k * 2 + 1].displayName : BracketMatch.unknownSide,
          winner: hasB ? null : a,
          resultType: hasB ? MatchResultType.normal : MatchResultType.walkover,
        ),
      );
    }
    _brackets[tournamentId] = matches;
    _items[i] = _items[i].copyWith(status: 'IN_PROGRESS');
  }

  @override
  Future<List<BracketMatch>> getBracket(String tournamentId) async {
    await _delay();
    return List.unmodifiable(_brackets[tournamentId] ?? const []);
  }

  // ---------------- Thi đấu (đợt 4) ----------------

  final Map<String, ScheduledMatch> _scheduled = {};
  final Map<String, List<CourtBlock>> _blocks = {};
  final Map<String, List<String>> _officials = {};
  final Map<String, List<MatchComplaintItem>> _complaints = {};

  /// Trọng tài đã phân cho trận (để test / xem).
  List<String> officialsOf(String matchId) => List.unmodifiable(_officials[matchId] ?? const []);

  /// Thêm khiếu nại mẫu (giả lập người chơi gửi).
  void seedComplaint(String tournamentId, MatchComplaintItem complaint) =>
      _complaints.putIfAbsent(tournamentId, () => []).add(complaint);

  (String, int) _locate(String matchId) {
    for (final e in _brackets.entries) {
      final i = e.value.indexWhere((m) => m.id == matchId);
      if (i >= 0) return (e.key, i);
    }
    throw const TournamentException('Không tìm thấy trận đấu.');
  }

  @override
  Future<MatchDetail> getMatch(String matchId) async {
    await _delay();
    final (tid, i) = _locate(matchId);
    final m = _brackets[tid]![i];
    final people = _participants[tid] ?? const [];
    MatchSide? side(String name) {
      if (name == BracketMatch.unknownSide) return null;
      final p = people.where((x) => x.displayName == name).firstOrNull;
      return MatchSide(id: p?.participantId ?? '', name: name);
    }

    final t = _items[_index(tid)];
    final winner = m.winner == null ? null : people.where((x) => x.displayName == m.winner).firstOrNull;
    return MatchDetail(
      id: m.id,
      tournamentId: tid,
      tournamentName: t.name,
      roundName: m.roundName,
      status: m.status,
      stage: m.stage,
      sportName: t.sportName,
      sideA: side(m.sideA),
      sideB: side(m.sideB),
      sets: m.scores,
      winnerId: winner?.participantId,
      resultType: m.resultType,
    );
  }

  @override
  Future<void> updateScore(String matchId, Map<String, dynamic> payload) async {
    await _delay();
    final (tid, i) = _locate(matchId);
    final m = _brackets[tid]![i];
    final people = _participants[tid] ?? const [];
    final sets = [
      for (final s in (payload['sets'] as List).cast<Map<String, dynamic>>())
        SetScore(set: s['setNumber'] as int, a: s['scoreP1'] as int, b: s['scoreP2'] as int),
    ];
    String? winner;
    final winnerId = payload['winnerId'] as String?;
    if (winnerId != null) {
      winner = people.where((p) => p.participantId == winnerId).firstOrNull?.displayName;
    } else {
      final a = sets.where((s) => s.a > s.b).length;
      final b = sets.where((s) => s.b > s.a).length;
      if (a == b) throw const TournamentException('Tỉ số hòa: trận loại trực tiếp phải có người thắng.');
      winner = a > b ? m.sideA : m.sideB;
    }
    _brackets[tid]![i] = BracketMatch(
      id: m.id,
      index: m.index,
      roundName: m.roundName,
      status: 'FINISHED',
      stage: m.stage,
      groupName: m.groupName,
      resultType: MatchResultType.fromApi(payload['resultType']),
      start: m.start,
      end: m.end,
      courtName: m.courtName,
      sideA: m.sideA,
      sideB: m.sideB,
      winner: winner,
      scores: sets,
    );
    if (_brackets[tid]!.every((x) => x.isFinished) && _brackets[tid]!.length == 1) {
      final ti = _index(tid);
      _items[ti] = _items[ti].copyWith(status: 'FINISHED');
    }
  }

  @override
  Future<CourtSchedule> getCourtSchedule(String tournamentId) async {
    await _delay();
    final ids = {for (final m in _brackets[tournamentId] ?? const <BracketMatch>[]) m.id};
    return CourtSchedule(
      blocks: List.of(_blocks[tournamentId] ?? const []),
      matches: [
        for (final s in _scheduled.values)
          if (ids.contains(s.matchId)) s,
      ],
    );
  }

  DateTime _day(String tournamentId) {
    final start = _items[_index(tournamentId)].start ?? now();
    return DateTime(start.year, start.month, start.day);
  }

  @override
  Future<void> autoSchedule(String tournamentId) async {
    await _delay();
    final matches = _brackets[tournamentId] ?? const <BracketMatch>[];
    if (matches.isEmpty) throw const TournamentException('Chưa có sơ đồ để xếp lịch.');
    final day = _day(tournamentId);
    _blocks[tournamentId] = [
      CourtBlock(courtName: 'Sân 1', start: day.add(const Duration(hours: 8)), end: day.add(const Duration(hours: 12)), slotCount: 4),
    ];
    var k = 0;
    for (final m in matches) {
      if (m.isFinished || _scheduled.containsKey(m.id)) continue;
      final start = day.add(Duration(hours: 8 + k++));
      _scheduled[m.id] = ScheduledMatch(
        matchId: m.id,
        courtName: 'Sân 1',
        start: start,
        end: start.add(const Duration(hours: 1)),
        roundName: m.roundName,
      );
    }
    final referees = (_staff[tournamentId] ?? const []).where((s) => s.role == StaffRole.referee).toList();
    if (referees.isNotEmpty) {
      for (final m in matches) {
        _officials[m.id] = [referees.first.id];
      }
    }
  }

  @override
  Future<List<AssignableSlot>> getAssignableSlots(String facilityId, String tournamentId, DateTime date) async {
    await _delay();
    final day = DateTime(date.year, date.month, date.day);
    final used = {for (final s in _scheduled.values) '${s.courtName}|${s.start}'};
    return [
      for (final court in const ['Sân 1', 'Sân 2'])
        for (var h = 8; h < 12; h++)
          if (!used.contains('$court|${day.add(Duration(hours: h))}'))
            AssignableSlot(
              id: 'slot-$court-${dateParam(day)}-$h',
              courtName: court,
              start: day.add(Duration(hours: h)),
              end: day.add(Duration(hours: h + 1)),
              reservedForTournament: court == 'Sân 1',
            ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<void> assignCourt(String matchId, String courtSlotId) async {
    await _delay();
    final (tid, i) = _locate(matchId);
    final parts = courtSlotId.split('-');
    // slot-<sân>-<yyyy>-<mm>-<dd>-<giờ>
    final hour = int.parse(parts.last);
    final day = DateTime.parse('${parts[2]}-${parts[3]}-${parts[4]}');
    final start = day.add(Duration(hours: hour));
    _scheduled[matchId] = ScheduledMatch(
      matchId: matchId,
      courtName: parts[1],
      start: start,
      end: start.add(const Duration(hours: 1)),
      roundName: _brackets[tid]![i].roundName,
    );
  }

  @override
  Future<void> assignOfficials(String matchId, List<String> staffIds) async {
    await _delay();
    _locate(matchId);
    _officials[matchId] = List.of(staffIds);
  }

  @override
  Future<List<MatchComplaintItem>> getMatchComplaints(String tournamentId, {bool openOnly = true}) async {
    await _delay();
    return [
      for (final c in _complaints[tournamentId] ?? const <MatchComplaintItem>[])
        if (!openOnly || c.canAct) c,
    ];
  }

  void _setComplaint(String id, ComplaintStatus status, String note) {
    for (final list in _complaints.values) {
      final i = list.indexWhere((c) => c.id == id);
      if (i < 0) continue;
      final c = list[i];
      if (!c.canAct) throw const TournamentException('Khiếu nại đã được xử lý.');
      list[i] = MatchComplaintItem(
        id: c.id,
        matchId: c.matchId,
        roundName: c.roundName,
        sideA: c.sideA,
        sideB: c.sideB,
        winnerName: c.winnerName,
        reporterName: c.reporterName,
        reason: c.reason,
        description: c.description,
        evidenceUrls: c.evidenceUrls,
        status: status,
        rawStatus: status.apiValue,
        resolutionNote: note.trim(),
        createdAt: c.createdAt,
      );
      return;
    }
    throw const TournamentException('Không tìm thấy khiếu nại.');
  }

  @override
  Future<void> decideComplaint(String complaintId, {required bool accept, required String note}) async {
    await _delay();
    if (note.trim().isEmpty) throw const TournamentException('Nhập lý do quyết định.');
    _setComplaint(complaintId, accept ? ComplaintStatus.organizerResponded : ComplaintStatus.rejected, note);
  }

  @override
  Future<void> resolveComplaintWithScore(String complaintId, Map<String, dynamic> score, String note) async {
    final c = _complaints.values.expand((l) => l).where((x) => x.id == complaintId).firstOrNull;
    if (c == null) throw const TournamentException('Không tìm thấy khiếu nại.');
    await updateScore(c.matchId, score);
    _setComplaint(complaintId, ComplaintStatus.resolved, note);
  }

  // ---------------- Trọng tài & chủ sân (đợt 5) ----------------

  /// Trận giả lập mà tài khoản đang đăng nhập làm trọng tài (test gán).
  List<StaffMatch> staffMatches = const [];

  @override
  Future<List<StaffMatch>> getMyStaffMatches() async {
    await _delay();
    return staffMatches;
  }

  @override
  Future<CourtBlockResult> blockCourts(String tournamentId, CourtBlockRequest request) async {
    await _delay();
    if (request.courtIds.isEmpty) throw const TournamentException('Chọn ít nhất 1 sân để giữ.');
    final list = _blocks.putIfAbsent(tournamentId, () => []);
    var count = 0;
    for (var d = request.dateFrom; !d.isAfter(request.dateTo); d = d.add(const Duration(days: 1))) {
      for (final court in request.courtIds) {
        final from = int.tryParse((request.startTime ?? '08:00').split(':').first) ?? 8;
        final to = int.tryParse((request.endTime ?? '22:00').split(':').first) ?? 22;
        list.add(CourtBlock(
          courtName: court,
          start: DateTime(d.year, d.month, d.day, from),
          end: DateTime(d.year, d.month, d.day, to),
          slotCount: to - from,
        ));
        count += to - from;
      }
    }
    return CourtBlockResult(
      slots: count,
      conflicts: [CourtBlockConflict(courtName: request.courtIds.first, start: request.dateFrom, reason: 'Đã có khách đặt')],
    );
  }

  @override
  Future<CourtBlockResult> releaseCourts(String tournamentId, CourtBlockRequest request) async {
    await _delay();
    final list = _blocks[tournamentId] ?? [];
    final before = list.fold<int>(0, (s, b) => s + b.slotCount);
    list.removeWhere((b) => request.courtIds.isEmpty || request.courtIds.contains(b.courtName));
    return CourtBlockResult(slots: before - list.fold<int>(0, (s, b) => s + b.slotCount));
  }
}
