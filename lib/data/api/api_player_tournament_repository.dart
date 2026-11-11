import '../../models/tournament_listing.dart';
import '../repositories/player_tournament_repository.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// Giải đấu phía người chơi qua BE.
///
/// - Đăng ký / rút / vé / sơ đồ dùng id bảng con; chi tiết và người tham gia dùng id giải mẹ.
/// - Môn lọc theo categoryId, lấy qua [ApiFacilityRepository.categoryIdOf].
class ApiPlayerTournamentRepository implements PlayerTournamentRepository {
  static const String searchPath = '/api/v1/tournaments/search';
  static const String myRegistrationsPath = '/api/v1/tournaments/my-registrations';
  static const String myMatchesPath = '/api/v1/tournaments/my-matches';
  static String detailPath(String id) => '/api/v1/tournaments/$id';
  static String participantsPath(String id) => '/api/v1/tournaments/$id/participants';
  static String bracketPath(String id) => '/api/v1/tournaments/$id/bracket';
  static String joinPath(String id) => '/api/v1/tournaments/$id/join';
  static String withdrawPath(String id) => '/api/v1/tournaments/$id/cancel';
  static String ticketPath(String id) => '/api/v1/tournaments/$id/qr-ticket';
  static String standingsPath(String id) => '/api/v1/tournaments/$id/standings';
  static const String myInvitationsPath = '/api/v1/tournaments/my-invitations';
  static String matchDetailPath(String id) => '/api/v1/matches/$id';
  static String respondPath(String id) => '/api/v1/tournaments/invitations/$id/respond';

  final ApiClient _api;
  final ApiFacilityRepository _facility;

  ApiPlayerTournamentRepository({required this._api, required this._facility});

  @override
  Future<TournamentPage> search(TournamentSearchQuery query, {int page = 1}) async {
    final sport = query.sport;
    String? categoryId;
    if (sport != null) {
      try {
        categoryId = await _facility.categoryIdOf(sport);
      } catch (_) {
        categoryId = null;
      }
      // Server chưa có môn này thì không có giải nào.
      if (categoryId == null) return const TournamentPage(items: [], hasMore: false);
    }
    const size = PlayerTournamentRepository.pageSize;
    final keyword = query.keyword.trim();
    final data = await _call(
      () => _api.get(
        searchPath,
        query: {
          if (keyword.isNotEmpty) 'Keyword': keyword,
          'CategoryId': ?categoryId,
          if (query.phase != null) 'Status': query.phase!.apiValue,
          if (query.registrationOpenOnly) 'RegistrationOpen': true,
          'SortBy': query.sort.apiValue,
          'Page': page,
          'PageSize': size,
        },
      ),
    );
    final map = data is Map ? data : const {};
    final items = _maps(map['items']).map(listItemFromApi).toList();
    final totalPages = (map['totalPages'] as num?)?.toInt();
    final totalItems = (map['totalItems'] as num?)?.toInt();
    return TournamentPage(
      items: items,
      hasMore: totalPages != null
          ? page < totalPages
          : totalItems != null
          ? page * size < totalItems
          : items.length >= size,
    );
  }

  @override
  Future<TournamentDetails> getDetails(String tournamentId) async {
    final data = await _call(() => _api.get(detailPath(tournamentId), auth: false));
    return detailsFromApi(data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  @override
  Future<List<TournamentParticipant>> getParticipants(String tournamentId) async {
    final data = await _call(() => _api.get(participantsPath(tournamentId)));
    return _maps(data).map(participantFromApi).toList();
  }

  @override
  Future<List<BracketMatch>> getBracket(String divisionId) async {
    final data = await _call(() => _api.get(bracketPath(divisionId), auth: false));
    return _maps(data).map(matchFromApi).toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  @override
  Future<List<TournamentRegistrationItem>> getMyRegistrations() async {
    final data = await _call(() => _api.get(myRegistrationsPath));
    return _maps(data).map(registrationFromApi).toList();
  }

  @override
  Future<List<MyTournamentMatch>> getMyMatches() async {
    final data = await _call(() => _api.get(myMatchesPath));
    final list = _maps(data).map(myMatchFromApi).toList();
    final far = DateTime(9999);
    return list..sort((a, b) => (a.start ?? far).compareTo(b.start ?? far));
  }

  @override
  Future<void> join(String divisionId, {String? teamId}) async {
    await _call(() => _api.post(joinPath(divisionId), query: {'teamId': ?teamId}));
  }

  @override
  Future<void> withdraw(String divisionId) async {
    await _call(() => _api.post(withdrawPath(divisionId)));
  }

  @override
  Future<TournamentTicket> getTicket(String divisionId) async {
    final data = await _call(() => _api.get(ticketPath(divisionId)));
    final m = data is Map ? data : const {};
    return TournamentTicket(
      tournamentName: _str(m['tournamentName']),
      facilityName: _str(m['facilityName']),
      fullName: _str(m['fullName']),
      teamName: _opt(m['teamName']),
      qrCode: _str(m['qrCode']),
    );
  }

  /// GET /tournaments/{id}/standings → [{group: "A", rows: [{rank, name, played, won, drawn, lost, points, scored, diff}]}]
  /// (rows đã sắp xếp; giải không có vòng bảng thì []). `diff` là hiệu số bàn / điểm hoặc hiệu số set tuỳ môn.
  @override
  Future<List<StandingGroup>> getStandings(String divisionId) async {
    final data = await _call(() => _api.get(standingsPath(divisionId), auth: false));
    return [
      for (final g in _maps(data))
        StandingGroup(
          name: _str(g['group']),
          rows: [
            for (final (i, r) in _maps(g['rows']).indexed)
              StandingRow(
                position: r['rank'] is num ? (r['rank'] as num).toInt() : i + 1,
                name: _str(r['name']),
                played: _int(r['played']),
                won: _int(r['won']),
                drawn: _int(r['drawn']),
                lost: _int(r['lost']),
                scored: _int(r['scored']),
                difference: _int(r['diff']),
                points: _int(r['points']),
              ),
          ],
        ),
    ];
  }

  /// GET /matches/{id} chỉ có id đăng ký (participant1Id / participant2Id) → nối với
  /// GET /tournaments/{bảng con}/participants theo participantId để lấy id tài khoản:
  /// đấu cá nhân = userId, đấu đội = teamMembers[].accountId (userId của dòng đội chỉ là người bấm đăng ký).
  @override
  Future<List<MatchPlayer>> getMatchPlayers(String matchId) async {
    final match = await _call(() => _api.get(matchDetailPath(matchId)));
    final m = match is Map ? Map<String, dynamic>.from(match) : const <String, dynamic>{};
    final divisionId = _str(m['tournamentId']);
    if (divisionId.isEmpty) return const [];
    final rows = _maps(await _call(() => _api.get(participantsPath(divisionId)))).toList();
    final myId = (await SessionStore.readUser())?.id;

    List<({String id, String name})> membersOf(String participantId) {
      final row = rows.where((r) => _str(r['participantId']) == participantId).firstOrNull;
      if (row == null) return const [];
      final team = _maps(row['teamMembers']).toList();
      if (team.isNotEmpty) {
        return [for (final t in team) (id: _str(t['accountId'] ?? t['userId']), name: _str(t['fullName']))];
      }
      final name = _str(row['fullName']).isNotEmpty ? _str(row['fullName']) : _str(row['username']);
      return [(id: _str(row['userId']), name: name)];
    }

    final sides = [
      (name: _str(m['participant1Name']), members: membersOf(_str(m['participant1Id']))),
      (name: _str(m['participant2Name']), members: membersOf(_str(m['participant2Id']))),
    ];
    final mySide = sides.indexWhere((s) => s.members.any((p) => p.id == myId));
    return [
      for (final (i, side) in sides.indexed)
        for (final p in side.members)
          if (p.id.isNotEmpty && p.id != myId)
            MatchPlayer(userId: p.id, name: p.name, sideName: side.name, isTeammate: i == mySide),
    ];
  }

  @override
  Future<List<TournamentInvitation>> getMyInvitations({bool pendingOnly = true}) async {
    final data = await _call(() => _api.get(myInvitationsPath, query: {if (pendingOnly) 'status': 'PENDING'}));
    return _maps(data is Map ? data['items'] : data).map(invitationFromApi).toList();
  }

  @override
  Future<void> respondInvitation(String invitationId, {required bool accept}) async {
    await _call(() => _api.post(respondPath(invitationId), body: {'accept': accept}));
  }

  // ---------------- Chuyển đổi ----------------

  static TournamentInvitation invitationFromApi(Map<String, dynamic> m) => TournamentInvitation(
    id: _str(m['id']),
    divisionId: _str(m['tournamentId']),
    divisionName: _str(m['tournamentName']),
    tournamentId: _opt(m['parentTournamentId']),
    tournamentName: _opt(m['parentTournamentName']),
    type: DivisionType.fromApi(_opt(m['categoryType'])),
    entryFee: _int(m['entryFee']),
    startDate: _date(m['startDate']),
    registrationDeadline: _date(m['registrationDeadline']),
    teamId: _opt(m['teamId']),
    teamName: _opt(m['teamName']),
    invitedByName: _str(m['invitedByName']),
    message: _str(m['message']),
    status: TournamentInvitationStatus.fromApi(m['status']),
    createdAt: _date(m['createdAt']),
  );

  static TournamentListItem listItemFromApi(Map<String, dynamic> m) {
    final sportName = _str(m['categoryName'] ?? m['sportName']);
    return TournamentListItem(
      id: _str(m['id']),
      name: _str(m['name']),
      imageUrl: _opt(m['imageUrl']),
      phase: TournamentPhase.fromApi(_opt(m['status'])),
      tier: TournamentTier.fromApi(m['tier']),
      purpose: TournamentPurpose.fromApi(m['purpose']),
      isPromoted: m['isPromoted'] == true,
      facilityId: _str(m['facilityId']),
      facilityName: _str(m['facilityName']),
      facilityAddress: _str(m['facilityAddress']),
      sport: ApiFacilityRepository.sportFromName(sportName),
      sportName: sportName,
      divisionCount: (m['totalSubTournaments'] as num?)?.toInt() ?? (m['children'] as List?)?.length ?? 0,
      startDate: _date(m['startDate']),
      endDate: _date(m['endDate']),
      registrationDeadline: _date(m['registrationDeadline']),
      isRegistrationOpen: m['isRegistrationOpen'] == true,
    );
  }

  static List<TournamentPrizeItem> _prizes(Object? raw) => _maps(raw)
      .map((p) => TournamentPrizeItem(position: _int(p['position']), amount: _int(p['rewardAmount'])))
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  static TournamentDivision divisionFromApi(Map<String, dynamic> m) => TournamentDivision(
    id: _str(m['id']),
    name: _str(m['name']),
    type: DivisionType.fromApi(_opt(m['categoryType'])),
    typeName: _str(m['categoryTypeName']),
    guide: _str(m['registrationGuide']),
    maxEntries: _int(m['maxParticipants']),
    minTeamSize: (m['minTeamSize'] as num?)?.toInt() ?? 1,
    maxTeamSize: (m['maxTeamSize'] as num?)?.toInt() ?? 1,
    entryFee: _int(m['entryFee']),
    phase: TournamentPhase.fromApi(_opt(m['status'])),
    isRegistrationOpen: m['isRegistrationOpen'] == true,
    prizes: _prizes(m['prizes']),
  );

  static TournamentDetails detailsFromApi(Map<String, dynamic> m) {
    var divisions = _maps(m['children']).map(divisionFromApi).toList();
    // Giải không chia bảng con: bản thân giải là nơi đăng ký.
    if (divisions.isEmpty && m['categoryType'] != null) divisions = [divisionFromApi(m)];
    return TournamentDetails(
      info: listItemFromApi(m),
      rules: _str(m['rules']),
      sportRules: _str(m['sportRulesDescription']),
      prizes: _prizes(m['prizes']),
      divisions: divisions,
    );
  }

  static TournamentParticipant participantFromApi(Map<String, dynamic> m) => TournamentParticipant(
    participantId: _str(m['participantId']),
    divisionId: _str(m['tournamentId']),
    userId: _str(m['userId']),
    name: _str(m['fullName']).isNotEmpty ? _str(m['fullName']) : _str(m['username']),
    avatarUrl: _opt(m['avatarUrl']),
    teamId: _opt(m['teamId']),
    teamName: _opt(m['teamName']),
    isCheckedIn: m['isCheckedIn'] == true,
  );

  static BracketMatch matchFromApi(Map<String, dynamic> m) => BracketMatch(
    id: _str(m['id']),
    index: _int(m['matchIndex']),
    roundName: _str(m['roundName']),
    status: _str(m['status']).isEmpty ? 'SCHEDULED' : _str(m['status']),
    start: _date(m['startTime']),
    end: _date(m['endTime']),
    courtName: _str(m['courtName']),
    stage: MatchStage.fromApi(m['stage']),
    groupName: _str(m['groupName']),
    resultType: MatchResultType.fromApi(m['resultType']),
    sideA: _str(m['p1']).isEmpty ? BracketMatch.unknownSide : _str(m['p1']),
    sideB: _str(m['p2']).isEmpty ? BracketMatch.unknownSide : _str(m['p2']),
    winner: _opt(m['winner']),
    scores: _maps(m['scores'])
        .map(
          (s) => SetScore(
            set: _int(s['setNumber']),
            a: _int(s['scoreP1']),
            b: _int(s['scoreP2']),
            isTiebreak: s['isTiebreak'] == true,
          ),
        )
        .toList(),
  );

  static TournamentRegistrationItem registrationFromApi(Map<String, dynamic> m) {
    final divisionId = _str(m['tournamentId']);
    final parentId = _opt(m['parentTournamentId']);
    return TournamentRegistrationItem(
      participantId: _str(m['participantId']),
      divisionId: divisionId,
      divisionName: _str(m['tournamentName']),
      tournamentId: parentId ?? divisionId,
      tournamentName: _opt(m['parentTournamentName']) ?? _str(m['tournamentName']),
      type: DivisionType.fromApi(_opt(m['categoryType'])),
      facilityName: _str(m['facilityName']),
      entryFee: _int(m['entryFee']),
      paymentStatus: _str(m['paymentStatus']),
      phase: TournamentPhase.fromApi(_opt(m['tournamentStatus'])),
      qrCode: _opt(m['qrCode']),
      teamId: _opt(m['teamId']),
      teamName: _opt(m['teamName']),
      startDate: _date(m['startDate']),
      endDate: _date(m['endDate']),
      registrationDeadline: _date(m['registrationDeadline']),
      isRegistrationOpen: m['isRegistrationOpen'] == true,
      imageUrl: _opt(m['imageUrl']),
    );
  }

  static MyTournamentMatch myMatchFromApi(Map<String, dynamic> m) => MyTournamentMatch(
    matchId: _str(m['matchId']),
    tournamentName: _opt(m['parentTournamentName']) ?? _str(m['tournamentName']),
    divisionName: _opt(m['parentTournamentName']) == null ? '' : _str(m['tournamentName']),
    roundName: _str(m['roundName']),
    status: _str(m['status']),
    start: _date(m['startTime']),
    end: _date(m['endTime']),
    courtName: _str(m['courtName']),
    facilityName: _str(m['facilityName']),
    facilityAddress: _str(m['facilityAddress']),
    mySide: _str(m['mySideName']),
    opponent: _str(m['opponentName']).isEmpty ? BracketMatch.unknownSide : _str(m['opponentName']),
    winner: _opt(m['winnerName']),
  );

  static Iterable<Map<String, dynamic>> _maps(Object? raw) =>
      (raw is List ? raw : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));

  static String _str(Object? v) => v?.toString() ?? '';

  static String? _opt(Object? v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  static int _int(Object? v) => v is num ? v.round() : num.tryParse('$v')?.round() ?? 0;

  static DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw TournamentException.fromApi(e);
    }
  }
}
