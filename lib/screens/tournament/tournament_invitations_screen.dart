import 'package:flutter/material.dart';

import '../../core/strings/player_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_tournament_repository.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/onboarding_required.dart';
import '../../widgets/common/rating_required.dart';

/// Lời mời tham gia giải nội bộ: nhận lời (= đăng ký, trừ lệ phí) hoặc từ chối. Pop `true` khi có thay đổi.
class TournamentInvitationsScreen extends StatefulWidget {
  const TournamentInvitationsScreen({super.key});

  @override
  State<TournamentInvitationsScreen> createState() => _TournamentInvitationsScreenState();
}

class _TournamentInvitationsScreenState extends State<TournamentInvitationsScreen> {
  List<TournamentInvitation>? _items;
  String? _error;
  final Set<String> _busy = {};
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await AppRepositories.playerTournament.getMyInvitations();
      if (mounted) setState(() => _items = items);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
  }

  Future<void> _respond(TournamentInvitation inv, bool accept) async {
    if (accept) {
      final fee = inv.entryFee > 0 ? Formatters.vnd(inv.entryFee) : PlayerTournamentStrings.free;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(PlayerTournamentStrings.confirmAcceptTitle),
          content: Text(PlayerTournamentStrings.confirmAcceptMessage(fee)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(PlayerTournamentStrings.declineInvite),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(PlayerTournamentStrings.acceptInvite),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy.add(inv.id));
    try {
      await AppRepositories.playerTournament.respondInvitation(inv.id, accept: accept);
      _changed = true;
      if (!mounted) return;
      _snack(accept ? PlayerTournamentStrings.acceptedInvite : PlayerTournamentStrings.declinedInvite);
      await _load();
    } on TournamentException catch (e) {
      // Thiếu tiền / thiếu Elo / chưa khảo sát: lời mời vẫn chờ để thử lại.
      if (!mounted) return;
      if (await handleOnboardingRequired(context, e) || !mounted) return;
      if (await handleRatingRequired(context, e) || !mounted) return;
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(inv.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(
            PlayerTournamentStrings.invitationsTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
        ),
        body: items == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          TextButton(onPressed: _load, child: const Text(PlayerTournamentStrings.retry)),
                        ],
                      ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text(PlayerTournamentStrings.noInvitations, style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    for (final inv in items) _card(inv),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _card(TournamentInvitation inv) {
    final busy = _busy.contains(inv.id);
    const muted = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inv.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(inv.type.label, style: muted),
            if (inv.teamName != null) Text(PlayerTournamentStrings.invitedTeam(inv.teamName!), style: muted),
            if (inv.invitedByName.isNotEmpty) Text(PlayerTournamentStrings.invitedBy(inv.invitedByName), style: muted),
            Text(
              PlayerTournamentStrings.entryFeeLabel(
                inv.entryFee > 0 ? Formatters.vnd(inv.entryFee) : PlayerTournamentStrings.free,
              ),
              style: muted,
            ),
            if (inv.startDate != null) Text(PlayerTournamentStrings.dateRange(inv.startDate, null), style: muted),
            if (inv.registrationDeadline != null)
              Text(PlayerTournamentStrings.deadline(inv.registrationDeadline!), style: muted),
            if (inv.message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('“${inv.message}”', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: busy ? null : () => _respond(inv, false),
                  child: const Text(PlayerTournamentStrings.declineInvite),
                ),
                FilledButton(
                  onPressed: busy ? null : () => _respond(inv, true),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(PlayerTournamentStrings.acceptInvite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
