import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/strings/tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../facility/sport_icon.dart';

String tournamentStatusLabel(Tournament t, DateTime now) {
  switch (t.status(now)) {
    case TournamentStatus.registrationOpen:
      return t.slotsLeft > 0 ? TournamentStrings.statusOpen : TournamentStrings.full;
    case TournamentStatus.upcoming:
      return TournamentStrings.statusUpcoming;
    case TournamentStatus.ongoing:
      return TournamentStrings.statusOngoing;
    case TournamentStatus.finished:
      return TournamentStrings.statusFinished;
    case TournamentStatus.cancelled:
      return TournamentStrings.statusCancelled;
  }
}

String tournamentStatusFilterLabel(TournamentStatus status) {
  switch (status) {
    case TournamentStatus.registrationOpen:
      return TournamentStrings.statusOpen;
    case TournamentStatus.upcoming:
      return TournamentStrings.statusUpcoming;
    case TournamentStatus.ongoing:
      return TournamentStrings.statusOngoing;
    case TournamentStatus.finished:
      return TournamentStrings.statusFinished;
    case TournamentStatus.cancelled:
      return TournamentStrings.statusCancelled;
  }
}

({Color bg, Color fg}) tournamentStatusColors(TournamentStatus status) {
  switch (status) {
    case TournamentStatus.registrationOpen:
      return (bg: AppColors.tagGreenBg, fg: AppColors.tagGreenText);
    case TournamentStatus.upcoming:
      return (bg: AppColors.tagPurpleBg, fg: AppColors.tagPurpleText);
    case TournamentStatus.ongoing:
      return (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText);
    case TournamentStatus.finished:
      return (bg: AppColors.divider, fg: AppColors.textSecondary);
    case TournamentStatus.cancelled:
      return (bg: const Color(0xFFFFEBEE), fg: const Color(0xFFC62828));
  }
}

String tournamentUnit(Tournament t) =>
    TournamentStrings.unit(t.entryType == TournamentEntryType.team, t.entryType == TournamentEntryType.pair);

class TournamentStatusChip extends StatelessWidget {
  final Tournament tournament;
  final DateTime now;

  const TournamentStatusChip({super.key, required this.tournament, required this.now});

  @override
  Widget build(BuildContext context) {
    final colors = tournamentStatusColors(tournament.status(now));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        tournamentStatusLabel(tournament, now),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.fg),
      ),
    );
  }
}

class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final DateTime now;
  final String? myUserId;
  final VoidCallback onTap;

  const TournamentCard({super.key, required this.tournament, required this.now, required this.onTap, this.myUserId});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final status = t.status(now);
    final myEntry = myUserId == null ? null : t.entryOf(myUserId!);
    final champion = status == TournamentStatus.finished ? t.champion : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.emoji_events, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(sportIcon(t.sport), size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${t.sport.label} • ${t.entryType.label}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TournamentStatusChip(tournament: t, now: now),
                    if (myEntry != null) _tag(myEntry.withdrawn ? TournamentStrings.withdrawnTag : TournamentStrings.registered),
                  ],
                ),
                const SizedBox(height: 10),
                _line(Icons.location_on_outlined, '${t.facilityName} • ${t.district}'),
                _line(Icons.calendar_today_outlined, TournamentStrings.dateRange(t.startDate, t.endDate)),
                if (t.totalPrize > 0) _line(Icons.card_giftcard, TournamentStrings.totalPrize(t.totalPrize)),
                if (champion != null)
                  _line(Icons.military_tech_outlined, '${TournamentStrings.champion}: ${champion.name}', bold: true),
                const Divider(height: 20, color: AppColors.divider),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TournamentStrings.entries(t.entryCount, t.maxEntries),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                          ),
                          if (status == TournamentStatus.registrationOpen)
                            Text(
                              TournamentStrings.deadlineIn(LfgStrings.duration(t.registrationDeadline.difference(now))),
                              style: const TextStyle(fontSize: 11, color: AppColors.tagOrangeText),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          TournamentStrings.feePer(tournamentUnit(t)),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        Text(
                          Formatters.vnd(t.entryFee),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ],
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

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _line(IconData icon, String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMain,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
}
