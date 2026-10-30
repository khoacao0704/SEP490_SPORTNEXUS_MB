import '../../models/tournament_listing.dart';
import '../repositories/player_tournament_repository.dart';
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

  // ---------------- Chuyển đổi ----------------

  static TournamentListItem listItemFromApi(Map<String, dynamic> m) {
    final sportName = _str(m['categoryName'] ?? m['sportName']);
    return TournamentListItem(
      id: _str(m['id']),
      name: _str(m['name']),
      imageUrl: _opt(m['imageUrl']),
      phase: TournamentPhase.fromApi(_opt(m['status'])),
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

  static int _int(Object? v) => (v as num?)?.round() ?? 0;

  static DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw TournamentException(e.message);
    }
  }
}
