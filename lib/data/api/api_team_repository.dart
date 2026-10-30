import '../../models/team.dart';
import '../repositories/team_repository.dart';
import 'api_client.dart';

/// Đội qua BE. Đội trưởng là `createdById`; BE không trả vai trò của từng người.
class ApiTeamRepository implements TeamRepository {
  static const String teamsPath = '/api/v1/teams';
  static const String myTeamsPath = '/api/v1/teams/my-teams';
  static const String myInvitationsPath = '/api/v1/teams/invitations/me';
  static String teamPath(String id) => '/api/v1/teams/$id';
  static String membersPath(String id) => '/api/v1/teams/$id/members';
  static String memberPath(String id, String accountId) => '/api/v1/teams/$id/members/$accountId';
  static String captainPath(String id) => '/api/v1/teams/$id/captain';
  static String leavePath(String id) => '/api/v1/teams/$id/leave';
  static String logoPath(String id) => '/api/v1/teams/$id/logo';
  static String invitationsPath(String id) => '/api/v1/teams/$id/invitations';
  static String invitationPath(String invitationId) => '/api/v1/teams/invitations/$invitationId';
  static String acceptPath(String invitationId) => '/api/v1/teams/invitations/$invitationId/accept';
  static String declinePath(String invitationId) => '/api/v1/teams/invitations/$invitationId/decline';

  final ApiClient _api;

  ApiTeamRepository({required this._api});

  @override
  Future<List<Team>> getMyTeams() async {
    final data = await _call(() => _api.get(myTeamsPath));
    return _maps(data).map(teamFromApi).toList();
  }

  @override
  Future<Team> getTeam(String teamId) async {
    final data = await _call(() => _api.get(teamPath(teamId)));
    final json = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (json['members'] is! List) {
      json['members'] = await _call(() => _api.get(membersPath(teamId)));
    }
    return teamFromApi(json);
  }

  @override
  Future<Team> createTeam({required String name, String description = '', List<String> invitePhones = const []}) async {
    final data = await _call(
      () => _api.post(
        teamsPath,
        body: {
          'name': name.trim(),
          if (description.trim().isNotEmpty) 'description': description.trim(),
          if (invitePhones.isNotEmpty) 'memberPhones': invitePhones,
        },
      ),
    );
    return teamFromApi(data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  @override
  Future<Team> updateTeam(String teamId, {required String name, String description = ''}) async {
    await _call(() => _api.put(teamPath(teamId), body: {'name': name.trim(), 'description': description.trim()}));
    return getTeam(teamId);
  }

  @override
  Future<Team> uploadLogo(String teamId, String filePath) async {
    await _call(() => _api.upload(logoPath(teamId), filePath: filePath, field: 'file'));
    return getTeam(teamId);
  }

  @override
  Future<void> invite(String teamId, String phone, {String message = ''}) async {
    await _call(
      () => _api.post(
        invitationsPath(teamId),
        body: {'phone': phone.trim(), if (message.trim().isNotEmpty) 'message': message.trim()},
      ),
    );
  }

  @override
  Future<List<TeamInvitation>> getTeamInvitations(String teamId) async {
    final data = await _call(() => _api.get(invitationsPath(teamId), query: {'status': 'PENDING'}));
    return _maps(data).map(invitationFromApi).toList();
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    await _call(() => _api.delete(invitationPath(invitationId)));
  }

  @override
  Future<List<TeamInvitation>> getMyInvitations() async {
    final data = await _call(() => _api.get(myInvitationsPath, query: {'status': 'PENDING'}));
    return _maps(data).map(invitationFromApi).where((i) => i.status == InvitationStatus.pending).toList();
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    await _call(() => _api.post(acceptPath(invitationId)));
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _call(() => _api.post(declinePath(invitationId)));
  }

  @override
  Future<void> removeMember(String teamId, String accountId) async {
    await _call(() => _api.delete(memberPath(teamId, accountId)));
  }

  @override
  Future<void> transferCaptain(String teamId, String accountId) async {
    await _call(() => _api.put(captainPath(teamId), body: {'newCaptainId': accountId}));
  }

  @override
  Future<void> leave(String teamId) async {
    await _call(() => _api.post(leavePath(teamId)));
  }

  @override
  Future<void> disband(String teamId) async {
    await _call(() => _api.delete(teamPath(teamId)));
  }

  // ---------------- Chuyển đổi ----------------

  static Team teamFromApi(Map<String, dynamic> m) {
    final captainId = _str(m['createdById'] ?? m['captainId']);
    final captainName = _str(m['createdByName'] ?? m['captainName']);
    final members = _maps(m['members'])
        .map(
          (e) => TeamMember(
            accountId: _str(e['accountId'] ?? e['userId']),
            fullName: _str(e['fullName']),
            phone: _opt(e['phone']),
            avatarUrl: _opt(e['avatarUrl']),
            joinedAt: _date(e['joinedAt']),
          ),
        )
        .toList();
    // Đề phòng danh sách thành viên không gồm đội trưởng.
    if (captainId.isNotEmpty && members.isNotEmpty && members.every((e) => e.accountId != captainId)) {
      members.insert(0, TeamMember(accountId: captainId, fullName: captainName));
    }
    return Team(
      id: _str(m['id']),
      name: _str(m['name']),
      description: _str(m['description']),
      logoUrl: _opt(m['logoUrl']),
      captainId: captainId,
      captainName: captainName,
      createdAt: _date(m['createAt'] ?? m['createdAt']),
      isLocked: m['isLocked'] == true,
      lockedReason: _opt(m['lockedReason']),
      members: members,
    );
  }

  static TeamInvitation invitationFromApi(Map<String, dynamic> m) => TeamInvitation(
    id: _str(m['id']),
    teamId: _str(m['teamId']),
    teamName: _str(m['teamName']),
    teamLogoUrl: _opt(m['teamLogoUrl']),
    inviteeId: _str(m['inviteeId']),
    inviteeName: _str(m['inviteeName']),
    inviteeAvatarUrl: _opt(m['inviteeAvatarUrl']),
    invitedByName: _str(m['invitedByName']),
    message: _str(m['message']),
    status: InvitationStatus.fromApi(_opt(m['status'])),
    createdAt: _date(m['createdAt']),
    expiresAt: _date(m['expiresAt']),
  );

  static Iterable<Map<String, dynamic>> _maps(Object? raw) =>
      (raw is List ? raw : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));

  static String _str(Object? v) => v?.toString() ?? '';

  static String? _opt(Object? v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  static DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw TeamException(e.message);
    }
  }
}
