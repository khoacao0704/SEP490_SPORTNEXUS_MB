import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/session_store.dart';
import '../../models/sport.dart';
import '../../models/team.dart';
import '../../screens/team/my_teams_screen.dart';
import '../../theme/app_colors.dart';

/// Lý do đội không chọn được cho kèo Đội vs Đội (`null` = chọn được).
/// App chỉ chặn sớm; BE kiểm tra lại (đếm thành viên đang hoạt động, có thể lệch với số ở đây).
String? teamIneligibleReason(Team team, Sport sport, int sideSize) {
  if (team.isLocked) return LfgStrings.teamLocked;
  if (team.sport != null && team.sport != sport) return LfgStrings.teamWrongSport;
  if (team.memberCount != sideSize) return LfgStrings.teamWrongSize(sideSize, team.memberCount);
  return null;
}

/// Đội người dùng đang làm đội trưởng.
Future<List<Team>> loadCaptainTeams() async {
  final me = await SessionStore.readUser();
  final teams = await AppRepositories.team.getMyTeams();
  return teams.where((t) => t.isCaptain(me?.id)).toList();
}

/// Dropdown "Chọn Đội đại diện thi đấu": đội mình làm đội trưởng; đội không hợp (sai môn / khác số người / bị khóa)
/// vẫn hiện nhưng mờ kèm lý do. Không có đội nào chọn được thì báo và mở "Đội của tôi".
class CaptainTeamDropdown extends StatelessWidget {
  final List<Team> teams;
  final Sport sport;
  final int sideSize;
  final String? selectedId;
  final ValueChanged<Team?> onChanged;

  const CaptainTeamDropdown({
    super.key,
    required this.teams,
    required this.sport,
    required this.sideSize,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasEligible = teams.any((t) => teamIneligibleReason(t, sport, sideSize) == null);
    final valid = teams.any((t) => t.id == selectedId && teamIneligibleReason(t, sport, sideSize) == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          // Đổi môn / số người làm đội đang chọn không hợp nữa thì bỏ chọn.
          key: ValueKey('$sport-$sideSize'),
          initialValue: valid ? selectedId : null,
          isExpanded: true,
          hint: const Text(LfgStrings.pickTeamHint),
          decoration: InputDecoration(
            labelText: LfgStrings.pickTeamTitle,
            filled: true,
            fillColor: AppColors.white,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: [
            for (final t in teams)
              DropdownMenuItem<String>(
                value: t.id,
                enabled: teamIneligibleReason(t, sport, sideSize) == null,
                child: _TeamItem(team: t, reason: teamIneligibleReason(t, sport, sideSize)),
              ),
          ],
          selectedItemBuilder: (_) => [
            for (final t in teams) Text(t.name, overflow: TextOverflow.ellipsis),
          ],
          onChanged: (id) => onChanged(teams.where((t) => t.id == id).firstOrNull),
        ),
        if (!hasEligible) ...[
          const SizedBox(height: 6),
          const Text(LfgStrings.noCaptainTeam, style: TextStyle(fontSize: 12, color: Colors.red)),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamsScreen())),
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: const Text(LfgStrings.openMyTeams),
          ),
        ],
      ],
    );
  }
}

class _TeamItem extends StatelessWidget {
  final Team team;
  final String? reason;

  const _TeamItem({required this.team, required this.reason});

  @override
  Widget build(BuildContext context) {
    final enabled = reason == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          team.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? AppColors.textMain : AppColors.textSecondary),
        ),
        Text(
          reason ?? LfgStrings.teamMembers(team.memberCount),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: enabled ? AppColors.textSecondary : Colors.red),
        ),
      ],
    );
  }
}

/// Hộp chọn đội khi nhận kèo Đội vs Đội. Trả đội đã chọn, `null` nếu hủy.
Future<Team?> pickTeamForClaim(BuildContext context, {required Sport sport, required int sideSize}) async {
  List<Team>? teams;
  String? error;
  try {
    teams = await loadCaptainTeams();
  } catch (_) {
    error = LfgStrings.teamsLoadError;
  }
  if (!context.mounted) return null;
  Team? picked;
  return showDialog<Team>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text(LfgStrings.claimTeamTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LfgStrings.teamMatchNote(sideSize), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              if (error != null)
                Text(error, style: const TextStyle(color: Colors.red))
              else
                CaptainTeamDropdown(
                  teams: teams!,
                  sport: sport,
                  sideSize: sideSize,
                  selectedId: picked?.id,
                  onChanged: (t) => setDialogState(() => picked = t),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(LfgStrings.cancel)),
          ElevatedButton(
            onPressed: picked == null ? null : () => Navigator.pop(dialogContext, picked),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text(LfgStrings.claimTeamAction),
          ),
        ],
      ),
    ),
  );
}
