import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/court_session.dart';
import '../../theme/app_colors.dart';
import '../facility/sport_icon.dart';

/// Nhãn + màu trạng thái lượt sân. Đang chơi mà đã hết giờ thì hiện "Chờ check-out".
({String label, Color fg, Color bg}) sessionStatusStyle(CourtSession s, DateTime now) {
  switch (s.status(now)) {
    case SessionStatus.upcoming:
      return (label: OwnerStrings.statusUpcoming, fg: AppColors.textSecondary, bg: AppColors.divider);
    case SessionStatus.waitingCheckIn:
      return (label: OwnerStrings.statusWaiting, fg: AppColors.tagOrangeText, bg: AppColors.tagOrangeBg);
    case SessionStatus.playing:
      return s.isOverdueCheckOut(now)
          ? (label: OwnerStrings.statusOverdue, fg: AppColors.tagPurpleText, bg: AppColors.tagPurpleBg)
          : (label: OwnerStrings.statusPlaying, fg: AppColors.tagGreenText, bg: AppColors.tagGreenBg);
    case SessionStatus.noShow:
      return (label: OwnerStrings.statusNoShow, fg: Colors.red.shade700, bg: Colors.red.shade50);
    case SessionStatus.completed:
      return (label: OwnerStrings.statusCompleted, fg: AppColors.primaryGreen, bg: AppColors.lightGreen);
    case SessionStatus.cancelled:
      return (label: OwnerStrings.statusCancelled, fg: AppColors.textSecondary, bg: AppColors.divider);
  }
}

class SessionStatusChip extends StatelessWidget {
  final CourtSession session;
  final DateTime now;

  const SessionStatusChip({super.key, required this.session, required this.now});

  @override
  Widget build(BuildContext context) {
    final style = sessionStatusStyle(session, now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        style.label,
        style: TextStyle(color: style.fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Thẻ một lượt sân trong Tổng quan / Lịch đặt.
class SessionCard extends StatelessWidget {
  final CourtSession session;
  final DateTime now;
  final bool showFacility;
  final VoidCallback onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.now,
    required this.onTap,
    this.showFacility = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final isLfg = s.kind == SessionKind.lfg;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: AppColors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Text(
                      Formatters.time(s.start),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGreen, fontSize: 15),
                    ),
                    Text(Formatters.time(s.end), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(sportIcon(s.sport), size: 16, color: AppColors.primaryGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.sportLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SessionStatusChip(session: s, now: now),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLfg
                          ? '${OwnerStrings.kindLfg} • ${s.leader.name}'
                          : '${OwnerStrings.kindBooking} • ${s.leader.name}',
                      style: const TextStyle(color: AppColors.textMain, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showFacility) ...[
                      const SizedBox(height: 2),
                      Text(
                        s.facilityName,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.how_to_reg_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          OwnerStrings.checkedInCount(s.checkedInCount, s.players.length),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.grid_view, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          s.assignedCourt ?? OwnerStrings.noCourtYet,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
