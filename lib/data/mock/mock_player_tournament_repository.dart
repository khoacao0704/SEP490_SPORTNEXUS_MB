import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/sport.dart';
import '../../models/tournament_listing.dart';
import '../repositories/player_tournament_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_team_repository.dart';

/// Bản giả lập [PlayerTournamentRepository], dữ liệu trong bộ nhớ (không trừ ví).
///
/// - "Giải Pickleball Mở Rộng Quận 7": đang mở, 3 nội dung (đơn, đôi cố định, đôi ngẫu nhiên).
/// - "Giải Cầu Lông Thiên Triều": đang diễn ra, người chơi demo đã đăng ký, có sơ đồ.
/// - "Giải Bóng Đá Hoa Lư": đã kết thúc.
class MockPlayerTournamentRepository implements PlayerTournamentRepository {
  static const String msgClosed = 'Giải đã hết hạn đăng ký hoặc không còn mở.';
  static const String msgFull = 'Nội dung này đã đủ suất.';
  static const String msgAlready = 'Bạn đã đăng ký nội dung này.';
  static const String msgNeedTeam = 'Nội dung này cần đăng ký bằng đội.';
  static const String msgNoTeam = 'Nội dung này đăng ký cá nhân, không chọn đội.';
  static const String msgTeamSize = 'Số thành viên của đội không phù hợp với nội dung này.';
  static const String msgNotRegistered = 'Bạn chưa đăng ký nội dung này.';
  static const String msgCannotWithdraw = 'Chỉ rút được khi giải còn mở đăng ký.';

  final MockTeamRepository? _teams;
  final Duration latency;
  final DateTime Function() _now;

  final List<_Parent> _parents = [];
  final List<TournamentParticipant> _participants = [];
  final Map<String, List<BracketMatch>> _brackets = {};

  /// Ai đã trả tiền cho từng suất (key = teamId hoặc participantId).
  final Map<String, String> _payers = {};
  bool _seeded = false;
  int _seq = 0;

  MockPlayerTournamentRepository({
    this._teams,
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<TournamentPage> search(TournamentSearchQuery query, {int page = 1}) async {
    await _me();
    final keyword = query.keyword.trim().toLowerCase();
    var items = _parents.map((p) => p.info).where((t) {
      if (keyword.isNotEmpty && !t.name.toLowerCase().contains(keyword)) return false;
      if (query.sport != null && t.sport != query.sport) return false;
      if (query.phase != null && t.phase != query.phase) return false;
      if (query.registrationOpenOnly && !t.isRegistrationOpen) return false;
      return true;
    }).toList();
    final far = DateTime(9999);
    switch (query.sort) {
      case TournamentSort.newest:
        break;
      case TournamentSort.upcoming:
        items.sort((a, b) => (a.startDate ?? far).compareTo(b.startDate ?? far));
      case TournamentSort.deadline:
        items.sort((a, b) => (a.registrationDeadline ?? far).compareTo(b.registrationDeadline ?? far));
    }
    items = [...items.where((t) => t.isPromoted), ...items.where((t) => !t.isPromoted)];
    const size = PlayerTournamentRepository.pageSize;
    final start = (page - 1) * size;
    return TournamentPage(items: items.skip(start).take(size).toList(), hasMore: items.length > start + size);
  }

  @override
  Future<TournamentDetails> getDetails(String tournamentId) async {
    await _me();
    return _parent(tournamentId).details;
  }

  @override
  Future<List<TournamentParticipant>> getParticipants(String tournamentId) async {
    await _me();
    final ids = _parent(tournamentId).details.divisions.map((d) => d.id).toSet();
    return _participants.where((p) => ids.contains(p.divisionId)).toList();
  }

  @override
  Future<List<BracketMatch>> getBracket(String divisionId) async {
    await _me();
    return _brackets[divisionId] ?? const [];
  }

  @override
  Future<List<TournamentRegistrationItem>> getMyRegistrations() async {
    final me = await _me();
    final result = <TournamentRegistrationItem>[];
    for (final p in _participants.where((p) => p.userId == me.id)) {
      final parent = _parentOfDivision(p.divisionId);
      final d = parent.details.divisions.firstWhere((d) => d.id == p.divisionId);
      result.add(
        TournamentRegistrationItem(
          participantId: p.participantId,
          divisionId: d.id,
          divisionName: d.name,
          tournamentId: parent.info.id,
          tournamentName: parent.info.name,
          type: d.type,
          facilityName: parent.info.facilityName,
          entryFee: d.entryFee,
          paymentStatus: 'PAID',
          phase: d.phase,
          qrCode: 'TN-${p.participantId}',
          teamId: p.teamId,
          teamName: p.teamName,
          startDate: parent.info.startDate,
          endDate: parent.info.endDate,
          registrationDeadline: parent.info.registrationDeadline,
          isRegistrationOpen: d.isRegistrationOpen,
          imageUrl: parent.info.imageUrl,
        ),
      );
    }
    return result;
  }

  @override
  Future<List<MyTournamentMatch>> getMyMatches() async {
    final me = await _me();
    final result = <MyTournamentMatch>[];
    for (final p in _participants.where((p) => p.userId == me.id)) {
      final side = p.teamName ?? p.name;
      final parent = _parentOfDivision(p.divisionId);
      for (final m in _brackets[p.divisionId] ?? const <BracketMatch>[]) {
        if (m.sideA != side && m.sideB != side) continue;
        result.add(
          MyTournamentMatch(
            matchId: m.id,
            tournamentName: parent.info.name,
            divisionName: parent.details.divisions.firstWhere((d) => d.id == p.divisionId).name,
            roundName: m.roundName,
            status: m.status,
            start: m.start,
            end: m.end,
            courtName: m.courtName,
            facilityName: parent.info.facilityName,
            facilityAddress: parent.info.facilityAddress,
            mySide: side,
            opponent: m.sideA == side ? m.sideB : m.sideA,
            winner: m.winner,
          ),
        );
      }
    }
    final far = DateTime(9999);
    return result..sort((a, b) => (a.start ?? far).compareTo(b.start ?? far));
  }

  @override
  Future<void> join(String divisionId, {String? teamId}) async {
    final me = await _me();
    final parent = _parentOfDivision(divisionId);
    final d = parent.details.divisions.firstWhere((d) => d.id == divisionId);
    final deadline = parent.info.registrationDeadline;
    if (d.phase != TournamentPhase.open || (deadline != null && !_now().isBefore(deadline))) {
      throw const TournamentException(msgClosed);
    }
    final rows = _participants.where((p) => p.divisionId == divisionId).toList();
    if (rows.any((p) => p.userId == me.id)) throw const TournamentException(msgAlready);
    if (TournamentEntryGroup.group(rows).length >= d.maxEntries) throw const TournamentException(msgFull);

    if (d.type.needsTeam) {
      if (teamId == null) throw const TournamentException(msgNeedTeam);
      final team = await _teams!.getTeam(teamId);
      if (team.memberCount < d.minTeamSize || team.memberCount > d.maxTeamSize) {
        throw const TournamentException(msgTeamSize);
      }
      if (rows.any((p) => p.teamId == teamId)) throw const TournamentException(msgAlready);
      for (final m in team.members) {
        _participants.add(
          TournamentParticipant(
            participantId: 'tp-${++_seq}',
            divisionId: divisionId,
            userId: m.accountId,
            name: m.fullName,
            teamId: team.id,
            teamName: team.name,
          ),
        );
      }
      _payers[team.id] = me.id;
      _teams.lockedByTournament.add(team.id);
    } else {
      if (teamId != null) throw const TournamentException(msgNoTeam);
      final id = 'tp-${++_seq}';
      _participants.add(TournamentParticipant(participantId: id, divisionId: divisionId, userId: me.id, name: me.name));
      _payers[id] = me.id;
    }
  }

  @override
  Future<void> withdraw(String divisionId) async {
    final me = await _me();
    final mine = _participants.where((p) => p.divisionId == divisionId && p.userId == me.id).firstOrNull;
    if (mine == null) throw const TournamentException(msgNotRegistered);
    final d = _parentOfDivision(divisionId).details.divisions.firstWhere((d) => d.id == divisionId);
    if (d.phase != TournamentPhase.open) throw const TournamentException(msgCannotWithdraw);
    final teamId = mine.teamId;
    if (teamId != null) {
      final team = await _teams!.getTeam(teamId);
      if (_payers[teamId] != me.id && !team.isCaptain(me.id)) throw const TournamentException(msgNotRegistered);
      _participants.removeWhere((p) => p.divisionId == divisionId && p.teamId == teamId);
      _teams.lockedByTournament.remove(teamId);
    } else {
      _participants.remove(mine);
    }
  }

  @override
  Future<TournamentTicket> getTicket(String divisionId) async {
    final me = await _me();
    final mine = _participants.where((p) => p.divisionId == divisionId && p.userId == me.id).firstOrNull;
    if (mine == null) throw const TournamentException(msgNotRegistered);
    final parent = _parentOfDivision(divisionId);
    return TournamentTicket(
      tournamentName: parent.info.name,
      facilityName: parent.info.facilityName,
      fullName: mine.name,
      teamName: mine.teamName,
      qrCode: 'TN-${mine.participantId}',
    );
  }

  // ---------------- Dữ liệu giả ----------------

  Future<({String id, String name})> _me() async {
    if (latency > Duration.zero) await Future.delayed(latency);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    final json = raw == null ? const <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    _seed();
    return (id: json['id'] as String? ?? 'guest', name: json['fullName'] as String? ?? '');
  }

  _Parent _parent(String id) =>
      _parents.where((p) => p.info.id == id || p.details.divisions.any((d) => d.id == id)).firstOrNull ??
      (throw const TournamentException('Không tìm thấy giải đấu.'));

  _Parent _parentOfDivision(String divisionId) => _parent(divisionId);

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final t = _now();
    final today = DateTime(t.year, t.month, t.day);

    TournamentListItem info(
      String id,
      String name,
      TournamentPhase phase,
      Sport sport,
      String facilityId,
      String facilityName, {
      required DateTime start,
      required DateTime end,
      required DateTime deadline,
      required int divisions,
      bool promoted = false,
    }) => TournamentListItem(
      id: id,
      name: name,
      phase: phase,
      isPromoted: promoted,
      facilityId: facilityId,
      facilityName: facilityName,
      facilityAddress: 'TP.HCM',
      sport: sport,
      sportName: sport.label,
      divisionCount: divisions,
      startDate: start,
      endDate: end,
      registrationDeadline: deadline,
      isRegistrationOpen: phase == TournamentPhase.open && t.isBefore(deadline),
    );

    final pickleDeadline = today.add(const Duration(days: 5, hours: 22));
    final pickleOpen = t.isBefore(pickleDeadline);
    _parents.addAll([
      _Parent(
        TournamentDetails(
          info: info(
            'pt-pickle-q7',
            'Giải Pickleball Mở Rộng Quận 7',
            TournamentPhase.open,
            Sport.pickleball,
            'f-hcm-eco-q7',
            'Eco Sport Quận 7',
            start: today.add(const Duration(days: 10, hours: 7)),
            end: today.add(const Duration(days: 11, hours: 18)),
            deadline: pickleDeadline,
            divisions: 3,
            promoted: true,
          ),
          rules: 'Thi đấu loại trực tiếp, mỗi trận 1 set 11 điểm.\nCó mặt trước giờ thi đấu 30 phút.',
          sportRules: 'Luật Pickleball quốc tế (USA Pickleball).',
          prizes: const [TournamentPrizeItem(position: 1, amount: 3000000), TournamentPrizeItem(position: 2, amount: 1500000)],
          divisions: [
            TournamentDivision(
              id: 'pd-pickle-singles',
              name: 'Đơn mở rộng',
              type: DivisionType.singles,
              maxEntries: 16,
              entryFee: 150000,
              phase: TournamentPhase.open,
              isRegistrationOpen: pickleOpen,
            ),
            TournamentDivision(
              id: 'pd-pickle-doubles',
              name: 'Đôi cố định',
              type: DivisionType.premadeTeams,
              guide: 'Đăng ký bằng đội 2 người đã nhận lời mời.',
              maxEntries: 8,
              minTeamSize: 2,
              maxTeamSize: 2,
              entryFee: 300000,
              phase: TournamentPhase.open,
              isRegistrationOpen: pickleOpen,
            ),
            TournamentDivision(
              id: 'pd-pickle-random',
              name: 'Đôi ngẫu nhiên',
              type: DivisionType.randomDoubles,
              maxEntries: 16,
              entryFee: 120000,
              phase: TournamentPhase.open,
              isRegistrationOpen: pickleOpen,
            ),
          ],
        ),
      ),
      _Parent(
        TournamentDetails(
          info: info(
            'pt-badminton-tt',
            'Giải Cầu Lông Thiên Triều',
            TournamentPhase.inProgress,
            Sport.badminton,
            'f-hcm-thientrieu',
            'Sân Cầu Lông Thiên Triều',
            start: today.subtract(const Duration(days: 1)),
            end: today.add(const Duration(days: 1, hours: 20)),
            deadline: today.subtract(const Duration(days: 3)),
            divisions: 1,
          ),
          rules: 'Đánh 3 set 21 điểm.',
          prizes: const [TournamentPrizeItem(position: 1, amount: 2000000)],
          divisions: const [
            TournamentDivision(
              id: 'pd-bm-singles',
              name: 'Đơn nam',
              type: DivisionType.singles,
              maxEntries: 4,
              entryFee: 100000,
              phase: TournamentPhase.inProgress,
              isRegistrationOpen: false,
            ),
          ],
        ),
      ),
      _Parent(
        TournamentDetails(
          info: info(
            'pt-football-hoalu',
            'Giải Bóng Đá Hoa Lư',
            TournamentPhase.finished,
            Sport.football,
            'f-hcm-hoalu',
            'Sân Bóng Hoa Lư',
            start: today.subtract(const Duration(days: 20)),
            end: today.subtract(const Duration(days: 19)),
            deadline: today.subtract(const Duration(days: 25)),
            divisions: 1,
          ),
          divisions: const [
            TournamentDivision(
              id: 'pd-fb-teams',
              name: 'Bóng đá 7 người',
              type: DivisionType.premadeTeams,
              maxEntries: 8,
              minTeamSize: 7,
              maxTeamSize: 12,
              entryFee: 700000,
              phase: TournamentPhase.finished,
              isRegistrationOpen: false,
            ),
          ],
        ),
      ),
    ]);

    TournamentParticipant p(String id, String division, String userId, String name, {String? teamId, String? teamName}) =>
        TournamentParticipant(participantId: id, divisionId: division, userId: userId, name: name, teamId: teamId, teamName: teamName);
    _participants.addAll([
      p('tp-s1', 'pd-pickle-singles', 'u-quocbao', 'Quốc Bảo'),
      p('tp-s2', 'pd-pickle-singles', 'u-thutrang', 'Thu Trang'),
      p('tp-d1', 'pd-pickle-doubles', 'u-ductri', 'Đức Trí', teamId: 'team-x', teamName: 'Song Kiếm'),
      p('tp-d2', 'pd-pickle-doubles', 'u-lananh', 'Lan Anh', teamId: 'team-x', teamName: 'Song Kiếm'),
      p('tp-b1', 'pd-bm-singles', 'u-player-001', 'Khoa Cao'),
      p('tp-b2', 'pd-bm-singles', 'u-minhtuan', 'Minh Tuấn'),
      p('tp-b3', 'pd-bm-singles', 'u-hoangnam', 'Hoàng Nam'),
      p('tp-b4', 'pd-bm-singles', 'u-quocbao', 'Quốc Bảo'),
    ]);

    _brackets['pd-bm-singles'] = [
      BracketMatch(
        id: 'm-1',
        index: 1,
        roundName: 'Bán kết',
        status: 'COMPLETED',
        start: today.subtract(const Duration(hours: 4)),
        courtName: 'Sân 1',
        sideA: 'Khoa Cao',
        sideB: 'Minh Tuấn',
        winner: 'Khoa Cao',
        scores: const [SetScore(set: 1, a: 21, b: 18), SetScore(set: 2, a: 21, b: 15)],
      ),
      BracketMatch(
        id: 'm-2',
        index: 2,
        roundName: 'Bán kết',
        status: 'COMPLETED',
        start: today.subtract(const Duration(hours: 3)),
        courtName: 'Sân 2',
        sideA: 'Hoàng Nam',
        sideB: 'Quốc Bảo',
        winner: 'Quốc Bảo',
        scores: const [SetScore(set: 1, a: 19, b: 21), SetScore(set: 2, a: 17, b: 21)],
      ),
      BracketMatch(
        id: 'm-3',
        index: 3,
        roundName: 'Chung kết',
        start: today.add(const Duration(days: 1, hours: 9)),
        courtName: 'Sân 1',
        sideA: 'Khoa Cao',
        sideB: 'Quốc Bảo',
      ),
    ];
  }
}

class _Parent {
  final TournamentDetails details;

  _Parent(this.details);

  TournamentListItem get info => details.info;
}
