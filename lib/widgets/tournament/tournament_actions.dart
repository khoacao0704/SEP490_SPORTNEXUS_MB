import 'package:flutter/material.dart';

import '../../core/strings/player_tournament_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_tournament_repository.dart';
import '../../models/tournament_listing.dart';
import '../../screens/tournament/tournament_ticket_screen.dart';
import '../../theme/app_colors.dart';

/// Hỏi lại rồi rút đăng ký [registration]. Trả về `true` nếu đã rút.
Future<bool> withdrawRegistration(BuildContext context, TournamentRegistrationItem registration) async {
  final refundable = registration.refundableAt(DateTime.now());
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(PlayerTournamentStrings.withdrawTitle),
      content: Text(
        refundable
            ? PlayerTournamentStrings.withdrawRefund(registration.entryFee)
            : PlayerTournamentStrings.withdrawNoRefund,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(PlayerTournamentStrings.back),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text(PlayerTournamentStrings.withdrawConfirm),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await AppRepositories.playerTournament.withdraw(registration.divisionId);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(PlayerTournamentStrings.withdrawn)));
    }
    return true;
  } on TournamentException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
    return false;
  }
}

Future<void> openTournamentTicket(BuildContext context, String divisionId) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentTicketScreen(divisionId: divisionId)));

/// Một lượt đăng ký của tôi: tên giải / nội dung / đội, nút vé QR và rút.
class TournamentRegistrationCard extends StatelessWidget {
  final TournamentRegistrationItem registration;
  final VoidCallback? onTap;

  /// Gọi sau khi rút thành công.
  final VoidCallback onWithdrawn;

  /// Ẩn tên giải (khi đã ở trong màn chi tiết giải).
  final bool showTournament;

  const TournamentRegistrationCard({
    super.key,
    required this.registration,
    required this.onWithdrawn,
    this.onTap,
    this.showTournament = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = registration;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTournament)
                  Text(
                    r.tournamentName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                Text(
                  [
                    if (r.divisionName != r.tournamentName) r.divisionName,
                    r.type.label,
                    if (r.teamName != null) r.teamName!,
                  ].join(' • '),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (r.facilityName.isNotEmpty) r.facilityName,
                    PlayerTournamentStrings.dateRange(r.startDate, r.endDate),
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${PlayerTournamentStrings.entryFee}: ${PlayerTournamentStrings.fee(r.entryFee)} • ${r.phase.label}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (r.phase != TournamentPhase.cancelled)
                      OutlinedButton.icon(
                        onPressed: () => openTournamentTicket(context, r.divisionId),
                        icon: const Icon(Icons.qr_code_2, size: 18),
                        label: const Text(PlayerTournamentStrings.ticket),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                        ),
                      ),
                    const Spacer(),
                    if (r.canWithdraw)
                      TextButton(
                        onPressed: () async {
                          if (await withdrawRegistration(context, r)) onWithdrawn();
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text(PlayerTournamentStrings.withdraw),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
