import '../../models/match_scoring.dart';
import '../../models/organized_tournament.dart';
import '../../models/owner_court.dart';
import '../../models/tournament_listing.dart';
import '../../models/tournament_management.dart';
import 'api_player_tournament_repository.dart';
import '../repositories/host_tournament_repository.dart';
import '../repositories/tournament_repository.dart';
import 'api_client.dart';

/// Tổ chức giải, dữ liệu thật (như CreateTournament.jsx / api/owner/tournamentApi.js của Web):
/// - GET /tournaments/my-tournaments[?scope=facility], GET/PUT/DELETE /tournaments/{id}
/// - POST /tournaments → {tournamentId, approvalStatus}
/// - PATCH /tournaments/{id}/cancel-tournament {reason}
/// - POST /uploads/documents (PDF, field `file`), POST /uploads/images?purpose=tournament
/// - GET /facilities (cơ sở công khai đã duyệt), GET /master-data/sports
class ApiHostTournamentRepository implements HostTournamentRepository {
  final ApiClient _api;

  ApiHostTournamentRepository({required this._api});

  static const String basePath = '/api/v1/tournaments';
  static const String minePath = '/api/v1/tournaments/my-tournaments';
  static String detailPath(String id) => '$basePath/$id';
  static String cancelPath(String id) => '$basePath/$id/cancel-tournament';
  static const String documentPath = '/api/v1/uploads/documents';
  static const String imagePath = '/api/v1/uploads/images';
  static const String facilitiesPath = '/api/v1/facilities';
  static const String sportsPath = '/api/v1/master-data/sports';
  static String participantsPath(String id) => '$basePath/$id/participants';
  static String participantPath(String id, String pid) => '$basePath/$id/participants/$pid';
  static String checkInPath(String id) => '$basePath/$id/check-in';
  static String invitationsPath(String id) => '$basePath/$id/invitations';
  static String invitationPath(String invitationId) => '$basePath/invitations/$invitationId';
  static const String teamsPath = '/api/v1/teams';
  static String decisionPath(String id) => '$basePath/$id/registration-decision';
  static String staffPath(String id) => '$basePath/$id/staff';
  static String staffMemberPath(String id, String staffId) => '$basePath/$id/staff/$staffId';
  static const String lookupPath = '/api/accounts/lookup';
  static String pairingPath(String id) => '$basePath/$id/execute-random-pairing';
  static String generatePath(String id) => '$basePath/$id/generate-bracket';
  static String bracketPath(String id) => '$basePath/$id/bracket';
  static String matchPath(String id) => '/api/v1/matches/$id';
  static String scorePath(String id) => '/api/v1/matches/$id/score';
  static String assignCourtPath(String id) => '/api/v1/matches/$id/assign-court';
  static String officialsPath(String id) => '/api/v1/matches/$id/officials';
  static String courtSchedulePath(String id) => '$basePath/$id/court-schedule';
  static String autoSchedulePath(String id) => '$basePath/$id/auto-schedule';
  static String facilitySlotsPath(String facilityId) => '/api/v1/facilities/$facilityId/slots';
  static String complaintsPath(String id) => '$basePath/$id/match-complaints';
  static String decideComplaintPath(String id) => '/api/v1/match-complaints/$id/decide';
  static String resolveComplaintPath(String id) => '/api/v1/match-complaints/$id/resolve';
  static const String staffMatchesPath = '/api/v1/tournaments/my-staff-matches';
  static String courtBlocksPath(String id) => '$basePath/$id/court-blocks';
  static String releaseBlocksPath(String id) => '$basePath/$id/court-blocks/release';

  static List _list(Object? data) => data is List
      ? data
      : (data is Map ? (data['items'] ?? data['data'] ?? data['results']) as List? : null) ?? const [];

  static String _url(Object? data) {
    final url = data is String ? data : (data is Map ? (data['url'] ?? data['fileUrl']) : null)?.toString() ?? '';
    if (url.isEmpty) throw const TournamentException('Không nhận được đường dẫn file từ máy chủ.');
    return url;
  }

  @override
  Future<List<OrganizedTournament>> getMine({bool facilityScope = false}) async {
    final data = await _call(() => _api.get(minePath, query: facilityScope ? {'scope': 'facility'} : null));
    return [for (final e in _list(data).whereType<Map>()) OrganizedTournament.fromApi(Map<String, dynamic>.from(e))];
  }

  @override
  Future<OrganizedTournament> getDetail(String tournamentId) async {
    final data = await _call(() => _api.get(detailPath(tournamentId)));
    if (data is! Map) throw const TournamentException('Không tải được thông tin giải.');
    return OrganizedTournament.fromApi(Map<String, dynamic>.from(data));
  }

  @override
  Future<ApprovalStatus> create(NewTournament draft) async {
    final data = await _call(() => _api.post(basePath, body: draft.toJson()));
    return data is Map ? OrganizedTournament.approvalFromApi(data['approvalStatus']) : ApprovalStatus.unknown;
  }

  @override
  Future<void> updateInfo(String tournamentId, TournamentInfoUpdate update) =>
      _call(() => _api.put(detailPath(tournamentId), body: update.toJson()));

  @override
  Future<void> cancel(String tournamentId, String reason) =>
      _call(() => _api.patch(cancelPath(tournamentId), body: {'reason': reason.trim()}));

  @override
  Future<void> delete(String tournamentId) => _call(() => _api.delete(detailPath(tournamentId)));

  @override
  Future<String> uploadDocument(String filePath) async =>
      _url(await _call(() => _api.upload(documentPath, filePath: filePath)));

  @override
  Future<String> uploadImage(String filePath) async =>
      _url(await _call(() => _api.upload(imagePath, filePath: filePath, query: {'purpose': 'tournament'})));

  @override
  Future<List<FacilityOption>> getFacilities() async {
    final data = await _call(() => _api.get(facilitiesPath, auth: false));
    final out = <FacilityOption>[];
    for (final e in _list(data).whereType<Map>()) {
      final approval = '${e['approvalStatus'] ?? ''}'.toUpperCase();
      if (approval.isNotEmpty && approval != 'APPROVED') continue;
      final id = '${e['id'] ?? e['facilityId'] ?? ''}';
      if (id.isEmpty) continue;
      final address = [
        e['streetAddress'] ?? e['address'],
        e['wardName'],
        e['provinceName'] ?? e['city'],
      ].where((p) => p != null && '$p'.trim().isNotEmpty).join(', ');
      out.add(FacilityOption(id: id, name: '${e['name'] ?? '—'}', address: address));
    }
    return out;
  }

  @override
  Future<List<SportCategory>> getSports() async => [
    for (final e in _list(await _call(() => _api.get(sportsPath))).whereType<Map>())
      SportCategory.fromJson(Map<String, dynamic>.from(e)),
  ];

  static List<Map<String, dynamic>> _maps(Object? data) => [
    for (final e in _list(data).whereType<Map>()) Map<String, dynamic>.from(e),
  ];

  @override
  Future<List<OrganizerParticipant>> getParticipants(String tournamentId) async =>
      _maps(await _call(() => _api.get(participantsPath(tournamentId)))).map(OrganizerParticipant.fromApi).toList();

  @override
  Future<void> removeParticipant(String tournamentId, String participantId) =>
      _call(() => _api.delete(participantPath(tournamentId, participantId)));

  @override
  Future<void> checkIn(String tournamentId, String participantId) =>
      _call(() => _api.post(checkInPath(tournamentId), body: {'participantId': participantId, 'qrCode': null}));

  @override
  Future<List<OrganizerInvitation>> getInvitations(String tournamentId) async =>
      _maps(await _call(() => _api.get(invitationsPath(tournamentId)))).map(OrganizerInvitation.fromApi).toList();

  @override
  Future<void> invite(String tournamentId, {String? phone, String? teamId}) => _call(
    () => _api.post(
      invitationsPath(tournamentId),
      body: {'userId': null, 'phone': phone?.trim(), 'teamId': teamId, 'message': null},
    ),
  );

  @override
  Future<void> cancelInvitation(String invitationId) => _call(() => _api.delete(invitationPath(invitationId)));

  @override
  Future<List<TeamOption>> searchTeams(String keyword, {String? categoryId}) async {
    final data = await _call(
      () => _api.get(
        teamsPath,
        query: {
          'keyword': keyword.trim(),
          'pageSize': 20,
          'excludeLocked': true,
          if (categoryId != null && categoryId.isNotEmpty) 'sportCategoryId': categoryId,
        },
      ),
    );
    return _maps(data).map(TeamOption.fromApi).where((t) => t.id.isNotEmpty).toList();
  }

  @override
  Future<void> decideRegistration(String tournamentId, {required bool proceed, String reason = ''}) => _call(
    () => _api.post(
      decisionPath(tournamentId),
      body: {
        'decision': proceed ? 'CONTINUE' : 'CANCEL',
        'newDeadline': null,
        'reason': reason.trim().isEmpty ? null : reason.trim(),
      },
    ),
  );

  @override
  Future<List<TournamentStaffMember>> getStaff(String tournamentId) async =>
      _maps(await _call(() => _api.get(staffPath(tournamentId)))).map(TournamentStaffMember.fromApi).toList();

  @override
  Future<void> addStaff(String tournamentId, StaffDraft draft) =>
      _call(() => _api.post(staffPath(tournamentId), body: draft.toJson()));

  @override
  Future<void> updateStaff(String tournamentId, String staffId, StaffDraft draft) =>
      _call(() => _api.put(staffMemberPath(tournamentId, staffId), body: draft.toJson()));

  @override
  Future<void> removeStaff(String tournamentId, String staffId) =>
      _call(() => _api.delete(staffMemberPath(tournamentId, staffId)));

  @override
  Future<AccountMatch?> lookupAccount(String phone) async {
    final Object? data;
    try {
      data = await _api.get(lookupPath, query: {'phone': phone.trim()});
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      throw TournamentException.fromApi(e);
    }
    if (data is! Map) return null;
    final id = '${data['id'] ?? data['accountId'] ?? data['userId'] ?? ''}';
    if (id.isEmpty) return null;
    return AccountMatch(id: id, fullName: '${data['fullName'] ?? data['username'] ?? ''}');
  }

  @override
  Future<void> randomPairing(String tournamentId) => _call(() => _api.post(pairingPath(tournamentId)));

  @override
  Future<void> generateBracket(String tournamentId, BracketFormat? format) =>
      _call(() => _api.post(generatePath(tournamentId), query: format == null ? null : {'format': format.apiValue}));

  @override
  Future<List<BracketMatch>> getBracket(String tournamentId) async =>
      _maps(await _call(() => _api.get(bracketPath(tournamentId))))
          .map(ApiPlayerTournamentRepository.matchFromApi)
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  @override
  Future<MatchDetail> getMatch(String matchId) async {
    var data = await _call(() => _api.get(matchPath(matchId)));
    if (data is List && data.isNotEmpty) data = data.first;
    if (data is! Map) throw const TournamentException('Không tải được thông tin trận.');
    return MatchDetail.fromApi(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> updateScore(String matchId, Map<String, dynamic> payload) =>
      _call(() => _api.put(scorePath(matchId), body: payload));

  @override
  Future<CourtSchedule> getCourtSchedule(String tournamentId) async =>
      CourtSchedule.fromApi(await _call(() => _api.get(courtSchedulePath(tournamentId))));

  @override
  Future<void> autoSchedule(String tournamentId) => _call(() => _api.post(autoSchedulePath(tournamentId)));

  @override
  Future<List<AssignableSlot>> getAssignableSlots(String facilityId, String tournamentId, DateTime date) async {
    final data = await _call(() => _api.get(facilitySlotsPath(facilityId), query: {'date': dateParam(date)}));
    return AssignableSlot.fromFacilitySlots(data, tournamentId);
  }

  @override
  Future<void> assignCourt(String matchId, String courtSlotId) =>
      _call(() => _api.put(assignCourtPath(matchId), body: {'courtSlotId': courtSlotId}));

  @override
  Future<void> assignOfficials(String matchId, List<String> staffIds) =>
      _call(() => _api.put(officialsPath(matchId), body: {'staffIds': staffIds}));

  @override
  Future<List<MatchComplaintItem>> getMatchComplaints(String tournamentId, {bool openOnly = true}) async => _maps(
    await _call(() => _api.get(complaintsPath(tournamentId), query: {'status': openOnly ? 'OPEN' : 'ALL'})),
  ).map(MatchComplaintItem.fromApi).toList();

  @override
  Future<void> decideComplaint(String complaintId, {required bool accept, required String note}) => _call(
    () => _api.post(decideComplaintPath(complaintId), body: {'decision': accept ? 'ACCEPT' : 'REJECT', 'note': note.trim()}),
  );

  @override
  Future<void> resolveComplaintWithScore(String complaintId, Map<String, dynamic> score, String note) => _call(
    () => _api.post(
      resolveComplaintPath(complaintId),
      body: {'action': 'UPDATE_SCORE', 'score': score, 'note': note.trim().isEmpty ? null : note.trim()},
    ),
  );

  @override
  Future<List<StaffMatch>> getMyStaffMatches() async =>
      _maps(await _call(() => _api.get(staffMatchesPath))).map(StaffMatch.fromApi).toList();

  @override
  Future<CourtBlockResult> blockCourts(String tournamentId, CourtBlockRequest request) async =>
      CourtBlockResult.fromApi(await _call(() => _api.post(courtBlocksPath(tournamentId), body: request.toJson())));

  @override
  Future<CourtBlockResult> releaseCourts(String tournamentId, CourtBlockRequest request) async =>
      CourtBlockResult.fromApi(await _call(() => _api.post(releaseBlocksPath(tournamentId), body: request.toJson())));

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw TournamentException.fromApi(e);
    }
  }
}
