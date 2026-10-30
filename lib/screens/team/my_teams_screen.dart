import 'package:flutter/material.dart';

import '../../core/strings/team_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/team_repository.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../theme/app_colors.dart';
import 'team_detail_screen.dart';
import 'team_form_screen.dart';

/// Lời mời vào đội đang chờ + các đội của tôi.
class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  List<Team>? _teams;
  List<TeamInvitation> _invitations = [];
  String? _myId;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait<Object?>([
        AppRepositories.team.getMyTeams(),
        AppRepositories.team.getMyInvitations().catchError((_) => <TeamInvitation>[]),
        AppRepositories.auth.getCurrentUser(),
      ]);
      if (!mounted) return;
      setState(() {
        _teams = results[0] as List<Team>;
        _invitations = results[1] as List<TeamInvitation>;
        _myId = (results[2] as AppUser?)?.id;
      });
    } catch (_) {
      if (mounted) setState(() => _error = TeamStrings.loadError);
    }
  }

  Future<void> _respond(TeamInvitation invitation, bool accept) async {
    setState(() => _busy.add(invitation.id));
    try {
      if (accept) {
        await AppRepositories.team.acceptInvitation(invitation.id);
      } else {
        await AppRepositories.team.declineInvitation(invitation.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(accept ? TeamStrings.accepted : TeamStrings.declined)));
      await _load();
    } on TeamException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(invitation.id));
    }
  }

  Future<void> _create() async {
    final team = await Navigator.push<Team>(context, MaterialPageRoute(builder: (_) => const TeamFormScreen()));
    await _load();
    if (team != null && mounted) await _open(team);
  }

  Future<void> _open(Team team) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: team.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final teams = _teams;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          TeamStrings.myTeams,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text(TeamStrings.createTeam),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text(TeamStrings.retry)),
                ],
              ),
            )
          : teams == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (_invitations.isNotEmpty) ...[
                    const Text(
                      TeamStrings.invitationsTitle,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final i in _invitations) _buildInvitation(i),
                    const SizedBox(height: 12),
                  ],
                  if (teams.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                      child: Column(
                        children: [
                          Icon(Icons.groups_outlined, size: 64, color: AppColors.cardBorder),
                          SizedBox(height: 12),
                          Text(TeamStrings.noTeams, style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            TeamStrings.noTeamsHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final t in teams) _buildTeam(t),
                ],
              ),
            ),
    );
  }

  Widget _buildInvitation(TeamInvitation i) {
    final busy = _busy.contains(i.id);
    final expires = i.expiresAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tagOrangeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tagOrangeText.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i.teamName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            [
              if (i.invitedByName.isNotEmpty) TeamStrings.invitedBy(i.invitedByName),
              if (expires != null) TeamStrings.expiresOn('${Formatters.dayMonth(expires)}/${expires.year}'),
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (i.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('“${i.message}”', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : () => _respond(i, false),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text(TeamStrings.decline),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: busy ? null : () => _respond(i, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                child: const Text(TeamStrings.accept),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeam(Team t) {
    final captain = t.isCaptain(_myId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          onTap: () => _open(t),
          leading: TeamLogo(team: t),
          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            [
              TeamStrings.memberCount(t.memberCount),
              if (captain) TeamStrings.captain,
              if (t.isLocked) TeamStrings.locked,
            ].join(' • '),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
