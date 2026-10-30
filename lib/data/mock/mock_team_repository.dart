import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/team_strings.dart';
import '../../models/team.dart';
import '../repositories/team_repository.dart';
import 'mock_auth_repository.dart';

/// Bản giả lập [TeamRepository], dữ liệu trong bộ nhớ (mất khi tắt app).
///
/// Người chơi demo (u-player-001) là đội trưởng "Pickleball Q7" và có một lời mời từ đội "Cầu Lông Gò Vấp".
/// Mời được các SĐT trong [knownPhones].
class MockTeamRepository implements TeamRepository {
  static const Map<String, ({String id, String name})> knownPhones = {
    '0911111111': (id: 'u-lananh', name: 'Lan Anh'),
    '0908888888': (id: MockAuthRepository.restrictedPlayerId, name: 'Trần Văn Bình'),
  };

  /// Đội đang đăng ký giải chưa kết thúc: không giải tán / xoá / rời được (đặt từ bản giả lập giải đấu).
  final Set<String> lockedByTournament = {};

  final Duration latency;
  final DateTime Function() _now;
  final List<Team> _teams = [];
  final List<TeamInvitation> _invitations = [];
  bool _seeded = false;
  int _seq = 0;

  MockTeamRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<List<Team>> getMyTeams() async {
    final me = await _me();
    return _teams.where((t) => t.members.any((m) => m.accountId == me.id)).toList();
  }

  @override
  Future<Team> getTeam(String teamId) async {
    await _me();
    return _find(teamId);
  }

  @override
  Future<Team> createTeam({required String name, String description = '', List<String> invitePhones = const []}) async {
    final me = await _me();
    if (name.trim().isEmpty) throw const TeamException(TeamStrings.nameRequired);
    final team = Team(
      id: 'team-${++_seq}-${_now().microsecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      captainId: me.id,
      captainName: me.name,
      createdAt: _now(),
      members: [TeamMember(accountId: me.id, fullName: me.name, joinedAt: _now())],
    );
    _teams.add(team);
    for (final phone in invitePhones) {
      final account = knownPhones[phone.trim()];
      if (account != null) _addInvitation(team, account.id, account.name, me.name);
    }
    return team;
  }

  @override
  Future<Team> updateTeam(String teamId, {required String name, String description = ''}) async {
    final me = await _me();
    final team = _captainTeam(teamId, me.id);
    return _replace(_copy(team, name: name.trim(), description: description.trim()));
  }

  @override
  Future<Team> uploadLogo(String teamId, String filePath) async {
    final me = await _me();
    final team = _captainTeam(teamId, me.id);
    return _replace(_copy(team, logoUrl: 'file://$filePath'));
  }

  @override
  Future<void> invite(String teamId, String phone, {String message = ''}) async {
    final me = await _me();
    final team = _captainTeam(teamId, me.id);
    final account = knownPhones[phone.trim()];
    if (account == null) throw TeamException(TeamStrings.phoneNotFound(phone.trim()));
    if (team.members.any((m) => m.accountId == account.id)) throw const TeamException(TeamStrings.alreadyMember);
    if (team.memberCount >= Team.maxMembers) throw const TeamException(TeamStrings.teamFull);
    _addInvitation(team, account.id, account.name, me.name, message: message);
  }

  @override
  Future<List<TeamInvitation>> getTeamInvitations(String teamId) async {
    await _me();
    return _invitations.where((i) => i.teamId == teamId && i.status == InvitationStatus.pending).toList();
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    await _me();
    _setStatus(invitationId, InvitationStatus.cancelled);
  }

  @override
  Future<List<TeamInvitation>> getMyInvitations() async {
    final me = await _me();
    return _invitations.where((i) => i.inviteeId == me.id && i.status == InvitationStatus.pending).toList();
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    final me = await _me();
    final invitation = _setStatus(invitationId, InvitationStatus.accepted);
    final team = _find(invitation.teamId);
    _replace(_copy(team, members: [...team.members, TeamMember(accountId: me.id, fullName: me.name, joinedAt: _now())]));
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _me();
    _setStatus(invitationId, InvitationStatus.declined);
  }

  @override
  Future<void> removeMember(String teamId, String accountId) async {
    final me = await _me();
    final team = _captainTeam(teamId, me.id);
    if (accountId == team.captainId) throw const TeamException(TeamStrings.captainCannotLeave);
    _ensureNotInTournament(teamId);
    _replace(_copy(team, members: team.members.where((m) => m.accountId != accountId).toList()));
  }

  @override
  Future<void> transferCaptain(String teamId, String accountId) async {
    final me = await _me();
    final team = _captainTeam(teamId, me.id);
    final next = team.members.where((m) => m.accountId == accountId).firstOrNull;
    if (next == null) throw const TeamException(TeamStrings.notMember);
    _replace(_copy(team, captainId: next.accountId, captainName: next.fullName));
  }

  @override
  Future<void> leave(String teamId) async {
    final me = await _me();
    final team = _find(teamId);
    if (team.isCaptain(me.id)) throw const TeamException(TeamStrings.captainCannotLeave);
    _ensureNotInTournament(teamId);
    _replace(_copy(team, members: team.members.where((m) => m.accountId != me.id).toList()));
  }

  @override
  Future<void> disband(String teamId) async {
    final me = await _me();
    _captainTeam(teamId, me.id);
    _ensureNotInTournament(teamId);
    _teams.removeWhere((t) => t.id == teamId);
    for (final i in _invitations.where((i) => i.teamId == teamId && i.status == InvitationStatus.pending).toList()) {
      _setStatus(i.id, InvitationStatus.cancelled);
    }
  }

  // ---------------- Nội bộ ----------------

  Future<({String id, String name})> _me() async {
    if (latency > Duration.zero) await Future.delayed(latency);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    final json = raw == null ? const <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    final me = (id: json['id'] as String? ?? 'guest', name: json['fullName'] as String? ?? '');
    _seed();
    return me;
  }

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final t = _now();
    _teams.addAll([
      Team(
        id: 'team-pickle-q7',
        name: 'Pickleball Q7',
        description: 'Chơi tối thứ 3, 5 ở Eco Sport.',
        captainId: 'u-player-001',
        captainName: 'Khoa Cao',
        createdAt: t.subtract(const Duration(days: 30)),
        members: [
          TeamMember(accountId: 'u-player-001', fullName: 'Khoa Cao', phone: '0901234567', joinedAt: t.subtract(const Duration(days: 30))),
          TeamMember(accountId: 'u-hoangnam', fullName: 'Hoàng Nam', phone: '0933333333', joinedAt: t.subtract(const Duration(days: 20))),
        ],
      ),
      Team(
        id: 'team-cl-govap',
        name: 'Cầu Lông Gò Vấp',
        captainId: 'u-minhtuan',
        captainName: 'Minh Tuấn',
        createdAt: t.subtract(const Duration(days: 10)),
        members: [TeamMember(accountId: 'u-minhtuan', fullName: 'Minh Tuấn', joinedAt: t.subtract(const Duration(days: 10)))],
      ),
    ]);
    _invitations.add(
      TeamInvitation(
        id: 'inv-govap-1',
        teamId: 'team-cl-govap',
        teamName: 'Cầu Lông Gò Vấp',
        inviteeId: 'u-player-001',
        inviteeName: 'Khoa Cao',
        invitedByName: 'Minh Tuấn',
        message: 'Vào đội đánh giải đôi nhé!',
        status: InvitationStatus.pending,
        createdAt: t.subtract(const Duration(days: 1)),
        expiresAt: t.add(const Duration(days: 6)),
      ),
    );
  }

  Team _find(String teamId) =>
      _teams.where((t) => t.id == teamId).firstOrNull ?? (throw const TeamException(TeamStrings.notFound));

  Team _captainTeam(String teamId, String myId) {
    final team = _find(teamId);
    if (!team.isCaptain(myId)) throw const TeamException(TeamStrings.captainOnly);
    return team;
  }

  void _ensureNotInTournament(String teamId) {
    if (lockedByTournament.contains(teamId)) throw const TeamException(TeamStrings.inTournament);
  }

  void _addInvitation(Team team, String inviteeId, String inviteeName, String byName, {String message = ''}) {
    _invitations.add(
      TeamInvitation(
        id: 'inv-${++_seq}',
        teamId: team.id,
        teamName: team.name,
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        invitedByName: byName,
        message: message,
        status: InvitationStatus.pending,
        createdAt: _now(),
        expiresAt: _now().add(const Duration(days: 7)),
      ),
    );
  }

  TeamInvitation _setStatus(String invitationId, InvitationStatus status) {
    final index = _invitations.indexWhere((i) => i.id == invitationId);
    if (index < 0) throw const TeamException(TeamStrings.invitationNotFound);
    final i = _invitations[index];
    if (i.status != InvitationStatus.pending) throw const TeamException(TeamStrings.invitationNotFound);
    return _invitations[index] = TeamInvitation(
      id: i.id,
      teamId: i.teamId,
      teamName: i.teamName,
      inviteeId: i.inviteeId,
      inviteeName: i.inviteeName,
      invitedByName: i.invitedByName,
      message: i.message,
      status: status,
      createdAt: i.createdAt,
      expiresAt: i.expiresAt,
    );
  }

  Team _replace(Team team) {
    _teams[_teams.indexWhere((t) => t.id == team.id)] = team;
    return team;
  }

  static Team _copy(
    Team t, {
    String? name,
    String? description,
    String? logoUrl,
    String? captainId,
    String? captainName,
    List<TeamMember>? members,
  }) => Team(
    id: t.id,
    name: name ?? t.name,
    description: description ?? t.description,
    logoUrl: logoUrl ?? t.logoUrl,
    captainId: captainId ?? t.captainId,
    captainName: captainName ?? t.captainName,
    createdAt: t.createdAt,
    isLocked: t.isLocked,
    lockedReason: t.lockedReason,
    members: members ?? t.members,
  );
}
