import 'package:flutter/material.dart';
import '../../core/strings/player_tournament_strings.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';
import '../facility/sport_icon.dart';

/// Màu nhãn trạng thái giải.
({Color bg, Color fg}) tournamentPhaseColors(TournamentPhase phase) {
  switch (phase) {
    case TournamentPhase.open:
      return (bg: AppColors.lightGreen, fg: AppColors.primaryGreen);
    case TournamentPhase.inProgress:
      return (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText);
    case TournamentPhase.finished:
      return (bg: AppColors.background, fg: AppColors.textSecondary);
    case TournamentPhase.cancelled:
      return (bg: const Color(0xFFFFEBEE), fg: Colors.red);
  }
}

class TournamentPhaseChip extends StatelessWidget {
  final TournamentPhase phase;
  final String? label;

  const TournamentPhaseChip({super.key, required this.phase, this.label});

  @override
  Widget build(BuildContext context) {
    final colors = tournamentPhaseColors(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label ?? phase.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.fg),
      ),
    );
  }
}

/// Thẻ một giải trong danh sách khám phá.
class TournamentListCard extends StatelessWidget {
  final TournamentListItem item;
  final VoidCallback onTap;

  const TournamentListCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.isPromoted ? Colors.amber : AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      t.imageUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (t.phase == TournamentPhase.open && !t.isRegistrationOpen)
                            const TournamentPhaseChip(
                              phase: TournamentPhase.finished,
                              label: PlayerTournamentStrings.registrationClosed,
                            )
                          else
                            TournamentPhaseChip(phase: t.phase),
                          if (t.isPromoted)
                            const TournamentPhaseChip(
                              phase: TournamentPhase.inProgress,
                              label: PlayerTournamentStrings.promoted,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(t.sport == null ? Icons.sports : sportIcon(t.sport!), size: 16, color: AppColors.primaryGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [t.sportLabel, t.facilityName].where((s) => s.isNotEmpty).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            PlayerTournamentStrings.dateRange(t.startDate, t.endDate),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (t.divisionCount > 1) ...[
                            const Text('  •  ', style: TextStyle(color: AppColors.textSecondary)),
                            Text(
                              PlayerTournamentStrings.divisionCount(t.divisionCount),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                      if (t.isRegistrationOpen && t.registrationDeadline != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          PlayerTournamentStrings.deadline(t.registrationDeadline!),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tagOrangeText),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
