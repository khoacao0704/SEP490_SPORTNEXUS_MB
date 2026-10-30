import 'package:flutter/material.dart';

import '../../core/strings/player_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_tournament_repository.dart';
import '../../models/team.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';
import '../profile/top_up_wallet_screen.dart';
import '../team/team_form_screen.dart';

/// Đăng ký một nội dung: cá nhân (đơn / ghép đôi ngẫu nhiên) hoặc bằng một đội (đội / đôi cố định).
/// Lệ phí tạm giữ trong ví người đăng ký. Pop về `true` khi đăng ký thành công.
class TournamentRegisterScreen extends StatefulWidget {
  final TournamentDetails details;
  final TournamentDivision division;

  const TournamentRegisterScreen({super.key, required this.details, required this.division});

  @override
  State<TournamentRegisterScreen> createState() => _TournamentRegisterScreenState();
}

class _TournamentRegisterScreenState extends State<TournamentRegisterScreen> {
  int? _balance;
  List<Team>? _teams;
  String? _teamId;
  bool _submitting = false;

  TournamentDivision get _division => widget.division;

  bool _teamFits(Team t) =>
      !t.isLocked && t.memberCount >= _division.minTeamSize && t.memberCount <= _division.maxTeamSize;

  bool get _enoughMoney => _balance == null || _balance! >= _division.entryFee;

  bool get _canSubmit => !_submitting && _enoughMoney && (!_division.type.needsTeam || _teamId != null);

  @override
  void initState() {
    super.initState();
    _loadBalance();
    if (_division.type.needsTeam) _loadTeams();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await AppRepositories.wallet.getBalance();
      if (mounted) setState(() => _balance = balance);
    } catch (_) {
      // Không biết số dư thì để BE kiểm tra khi đăng ký.
    }
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await AppRepositories.team.getMyTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        if (_teamId != null && !teams.any((t) => t.id == _teamId && _teamFits(t))) _teamId = null;
        _teamId ??= teams.where(_teamFits).firstOrNull?.id;
      });
    } catch (_) {
      if (mounted) setState(() => _teams = const []);
    }
  }

  Future<void> _createTeam() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamFormScreen()));
    _loadTeams();
  }

  Future<void> _topUp() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpWalletScreen()));
    _loadBalance();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await AppRepositories.playerTournament.join(_division.id, teamId: _division.type.needsTeam ? _teamId : null);
      if (mounted) Navigator.pop(context, true);
    } on TournamentException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      _loadBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _division;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          PlayerTournamentStrings.registerTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.details.info.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    d.name,
                    d.typeLabel,
                    if (d.type.needsTeam) PlayerTournamentStrings.teamSize(d.minTeamSize, d.maxTeamSize),
                  ].join(' • '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (d.guide.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(d.guide, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                if (d.type == DivisionType.randomDoubles) ...[
                  const SizedBox(height: 6),
                  const Text(PlayerTournamentStrings.randomDoublesNote, style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          if (d.type.needsTeam) ...[const SizedBox(height: 16), _buildTeamPicker()],
          const SizedBox(height: 16),
          _card(
            Column(
              children: [
                _row(PlayerTournamentStrings.entryFee, PlayerTournamentStrings.fee(d.entryFee), bold: true),
                if (_balance != null) _row(PlayerTournamentStrings.walletBalance, Formatters.vnd(_balance!)),
                if (!_enoughMoney) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          PlayerTournamentStrings.notEnoughBalance,
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(onPressed: _topUp, child: const Text(PlayerTournamentStrings.topUp)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                const Text(
                  PlayerTournamentStrings.feeNote,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.authPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                  : const Text(PlayerTournamentStrings.confirmRegister, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamPicker() {
    final teams = _teams;
    final d = _division;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(PlayerTournamentStrings.chooseTeam, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            PlayerTournamentStrings.teamSizeRequired(d.minTeamSize, d.maxTeamSize),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (teams == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2)),
            )
          else ...[
            if (!teams.any(_teamFits))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(PlayerTournamentStrings.noEligibleTeam, style: TextStyle(color: AppColors.textSecondary)),
              ),
            RadioGroup<String>(
              groupValue: _teamId,
              onChanged: (id) => setState(() => _teamId = id),
              child: Column(
                children: [
                  for (final t in teams)
                    RadioListTile<String>(
                      value: t.id,
                      enabled: _teamFits(t),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primaryGreen,
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _teamFits(t)
                            ? '${t.memberCount} thành viên'
                            : PlayerTournamentStrings.teamSizeInvalid(t.memberCount),
                      ),
                    ),
                ],
              ),
            ),
          ],
          TextButton.icon(
            onPressed: _createTeam,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text(PlayerTournamentStrings.createTeam),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Material(
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    ),
  );
}
