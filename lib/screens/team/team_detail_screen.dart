import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings/team_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/team_repository.dart';
import '../../models/team.dart';
import '../../theme/app_colors.dart';
import 'team_form_screen.dart';

/// Logo đội, không có thì chữ cái đầu tên đội.
class TeamLogo extends StatelessWidget {
  final Team team;
  final double radius;

  const TeamLogo({super.key, required this.team, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final url = team.logoUrl;
    final network = url != null && url.startsWith('http');
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.lightGreen,
      backgroundImage: network ? NetworkImage(url) : null,
      child: network
          ? null
          : Text(
              team.name.isEmpty ? '?' : team.name.characters.first.toUpperCase(),
              style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
            ),
    );
  }
}

enum _MemberAction { makeCaptain, remove }

enum _TeamAction { edit, logo, leave, disband }

/// Chi tiết đội. Đội trưởng: sửa thông tin, đổi logo, mời / thu hồi lời mời, chuyển quyền, xoá thành viên,
/// giải tán. Thành viên: rời đội.
class TeamDetailScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  Team? _team;
  List<TeamInvitation> _pending = [];
  String? _myId;
  String? _error;
  bool _busy = false;

  bool get _isCaptain => _team?.isCaptain(_myId) ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final team = await AppRepositories.team.getTeam(widget.teamId);
      final me = await AppRepositories.auth.getCurrentUser();
      var pending = <TeamInvitation>[];
      if (team.isCaptain(me?.id)) {
        try {
          pending = await AppRepositories.team.getTeamInvitations(team.id);
        } catch (_) {
          // Chỉ ảnh hưởng mục lời mời đang chờ.
        }
      }
      if (!mounted) return;
      setState(() {
        _team = team;
        _myId = me?.id;
        _pending = pending;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is TeamException ? e.message : TeamStrings.loadError);
    }
  }

  /// Chạy một thao tác; thành công thì báo [done] rồi tải lại (hoặc thoát nếu [popAfter]).
  Future<void> _run(Future<void> Function() action, String done, {bool popAfter = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
      if (popAfter) {
        Navigator.pop(context);
        return;
      }
      await _load();
    } on TeamException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String message, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(TeamStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: danger ? TextButton.styleFrom(foregroundColor: Colors.red) : null,
            child: const Text(TeamStrings.confirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _invite() async {
    final result = await showDialog<({String phone, String message})>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (result == null || result.phone.isEmpty) return;
    await _run(
      () => AppRepositories.team.invite(widget.teamId, result.phone, message: result.message),
      TeamStrings.invited,
    );
  }

  Future<void> _onTeamAction(_TeamAction action) async {
    final team = _team!;
    switch (action) {
      case _TeamAction.edit:
        final updated = await Navigator.push<Team>(
          context,
          MaterialPageRoute(builder: (_) => TeamFormScreen(team: team)),
        );
        if (updated != null) _load();
      case _TeamAction.logo:
        final XFile? file;
        try {
          file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
        } catch (_) {
          return;
        }
        if (file == null) return;
        await _run(() => AppRepositories.team.uploadLogo(team.id, file!.path), TeamStrings.logoUpdated);
      case _TeamAction.leave:
        if (await _confirm(TeamStrings.confirmLeave, danger: true)) {
          await _run(() => AppRepositories.team.leave(team.id), TeamStrings.left, popAfter: true);
        }
      case _TeamAction.disband:
        if (await _confirm(TeamStrings.confirmDisband, danger: true)) {
          await _run(() => AppRepositories.team.disband(team.id), TeamStrings.disbanded, popAfter: true);
        }
    }
  }

  Future<void> _onMemberAction(TeamMember member, _MemberAction action) async {
    final team = _team!;
    switch (action) {
      case _MemberAction.makeCaptain:
        if (await _confirm(TeamStrings.confirmMakeCaptain(member.fullName))) {
          await _run(
            () => AppRepositories.team.transferCaptain(team.id, member.accountId),
            TeamStrings.captainTransferred,
          );
        }
      case _MemberAction.remove:
        if (await _confirm(TeamStrings.confirmRemove(member.fullName), danger: true)) {
          await _run(() => AppRepositories.team.removeMember(team.id, member.accountId), TeamStrings.memberRemoved);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          team?.name ?? '',
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (team != null)
            PopupMenuButton<_TeamAction>(
              enabled: !_busy,
              onSelected: _onTeamAction,
              itemBuilder: (_) => [
                if (_isCaptain) ...[
                  const PopupMenuItem(value: _TeamAction.edit, child: Text(TeamStrings.editTeam)),
                  if (!team.isLocked) const PopupMenuItem(value: _TeamAction.logo, child: Text(TeamStrings.changeLogo)),
                  const PopupMenuItem(
                    value: _TeamAction.disband,
                    child: Text(TeamStrings.disband, style: TextStyle(color: Colors.red)),
                  ),
                ] else
                  const PopupMenuItem(
                    value: _TeamAction.leave,
                    child: Text(TeamStrings.leave, style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: team != null && _isCaptain && team.memberCount < Team.maxMembers
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _invite,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text(TeamStrings.invite),
            )
          : null,
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(onPressed: _load, child: const Text(TeamStrings.retry)),
                ],
              ),
            )
          : team == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _buildHeader(team),
                  const SizedBox(height: 16),
                  Text(
                    '${TeamStrings.members} (${team.memberCount}/${Team.maxMembers})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _box(Column(children: [for (final m in team.members) _buildMember(team, m)])),
                  if (_isCaptain) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        TeamStrings.captainLeaveHint,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    if (_pending.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${TeamStrings.pendingInvitations} (${_pending.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _box(Column(children: [for (final i in _pending) _buildPending(i)])),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _box(Widget child) => Material(
    color: AppColors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: child,
  );

  Widget _buildHeader(Team team) {
    return _box(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamLogo(team: team, radius: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (team.captainName.isNotEmpty)
                    Text(
                      '${TeamStrings.captain}: ${team.captainName}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  if (team.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(team.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                  if (team.isLocked) ...[
                    const SizedBox(height: 6),
                    Text(
                      team.lockedReason == null ? TeamStrings.locked : TeamStrings.lockedReason(team.lockedReason!),
                      style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMember(Team team, TeamMember m) {
    final isCaptain = m.accountId == team.captainId;
    final isMe = m.accountId == _myId;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.lightGreen,
        backgroundImage: m.avatarUrl == null ? null : NetworkImage(m.avatarUrl!),
        child: m.avatarUrl != null
            ? null
            : Text(
                m.fullName.isEmpty ? '?' : m.fullName.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              ),
      ),
      title: Text(
        isMe ? '${m.fullName} ${TeamStrings.you}' : m.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text([if (isCaptain) TeamStrings.captain, if (m.phone != null) m.phone!].join(' • ')),
      trailing: _isCaptain && !isCaptain
          ? PopupMenuButton<_MemberAction>(
              enabled: !_busy,
              onSelected: (a) => _onMemberAction(m, a),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _MemberAction.makeCaptain, child: Text(TeamStrings.makeCaptain)),
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text(TeamStrings.remove, style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          : isCaptain
          ? const Icon(Icons.star_rounded, color: Colors.amber)
          : null,
    );
  }

  Widget _buildPending(TeamInvitation i) {
    final expires = i.expiresAt;
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.tagOrangeBg,
        child: Icon(Icons.hourglass_top, color: AppColors.tagOrangeText, size: 20),
      ),
      title: Text(i.inviteeName),
      subtitle: expires == null ? null : Text(TeamStrings.expiresOn('${Formatters.dayMonth(expires)}/${expires.year}')),
      trailing: TextButton(
        onPressed: _busy ? null : () => _run(() => AppRepositories.team.revokeInvitation(i.id), TeamStrings.revoked),
        child: const Text(TeamStrings.revoke),
      ),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(TeamStrings.invite),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: TeamStrings.invitePhone),
          ),
          TextField(
            controller: _message,
            maxLength: 500,
            decoration: const InputDecoration(labelText: TeamStrings.inviteMessage),
          ),
          const Text(TeamStrings.inviteNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(TeamStrings.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (phone: _phone.text.trim(), message: _message.text.trim())),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
          child: const Text(TeamStrings.send),
        ),
      ],
    );
  }
}
