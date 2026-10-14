import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../models/lfg_match.dart';
import '../../theme/app_colors.dart';
import '../facility/sport_icon.dart';

String lfgStatusLabel(LfgMatch match, DateTime now) {
  switch (match.status(now)) {
    case LfgStatus.open:
      return LfgStrings.statusOpen;
    case LfgStatus.confirmed:
      return LfgStrings.statusConfirmed;
    case LfgStatus.cancelled:
      switch (match.cancelReason!) {
        case LfgCancelReason.notEnoughPlayers:
          return LfgStrings.statusCancelledNotEnough;
        case LfgCancelReason.mutualAgreement:
          return LfgStrings.statusCancelledMutual;
        case LfgCancelReason.everyoneLeft:
          return LfgStrings.statusCancelledEveryoneLeft;
      }
    case LfgStatus.completed:
      return LfgStrings.statusCompleted;
  }
}

({Color bg, Color fg}) lfgStatusColors(LfgStatus status) {
  switch (status) {
    case LfgStatus.open:
      return (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText);
    case LfgStatus.confirmed:
      return (bg: AppColors.tagGreenBg, fg: AppColors.tagGreenText);
    case LfgStatus.cancelled:
      return (bg: const Color(0xFFFFEBEE), fg: const Color(0xFFC62828));
    case LfgStatus.completed:
      return (bg: AppColors.divider, fg: AppColors.textSecondary);
  }
}

class LfgStatusChip extends StatelessWidget {
  final LfgMatch match;
  final DateTime now;

  const LfgStatusChip({super.key, required this.match, required this.now});

  @override
  Widget build(BuildContext context) {
    final colors = lfgStatusColors(match.status(now));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        lfgStatusLabel(match, now),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.fg),
      ),
    );
  }
}

/// Dãy chấm thể hiện số chỗ: đã có người / đang giữ / trống.
class LfgSlotDots extends StatelessWidget {
  final LfgMatch match;

  const LfgSlotDots({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final filled = match.members.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < match.totalSlots; i++)
          Container(
            margin: const EdgeInsets.only(right: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? AppColors.primaryGreen
                  : i < filled + match.heldSlots
                      ? AppColors.tagOrangeText
                      : Colors.transparent,
              border: Border.all(color: i < filled ? AppColors.primaryGreen : AppColors.cardBorder, width: 1.5),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          LfgStrings.slotsFilled(filled, match.totalSlots, match.format.isTeam),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
      ],
    );
  }
}

class LfgMatchCard extends StatelessWidget {
  final LfgMatch match;
  final DateTime now;

  /// Người dùng hiện tại (để hiện "Kèo của bạn" / "Đã tham gia").
  final String? myUserId;
  final double? distanceKm;
  final VoidCallback onTap;

  /// `null` thì không hiện nút Flash Claim (vd. ở "Kèo của tôi").
  final VoidCallback? onClaim;

  const LfgMatchCard({
    super.key,
    required this.match,
    required this.now,
    required this.onTap,
    this.myUserId,
    this.distanceKm,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final host = match.host;
    final isMine = myUserId != null && match.isHostedBy(myUserId!);
    final joined = myUserId != null && match.isMember(myUserId!);
    final status = match.status(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
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
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryGreen,
                      child: Text(
                        host.name.characters.first.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            host.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                          ),
                          Text(
                            '${LfgStrings.host} • ${LfgStrings.fairPlay(host.fairPlayScore)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sportIcon(match.sport), size: 13, color: AppColors.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            match.sport.label,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.divider),
                Text(
                  match.formatLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                ),
                const SizedBox(height: 6),
                _infoRow(
                  Icons.location_on_outlined,
                  '${match.facilityName} • ${match.district}',
                  trailing: distanceKm == null ? null : GeoUtils.formatDistance(distanceKm!),
                ),
                const SizedBox(height: 4),
                _infoRow(Icons.access_time, Formatters.slotLabel(match.start, match.end), highlight: true),
                const SizedBox(height: 10),
                Row(
                  children: [
                    LfgSlotDots(match: match),
                    const Spacer(),
                    if (status == LfgStatus.open && now.isBefore(match.fillDeadline))
                      Flexible(
                        child: Text(
                          LfgStrings.fillDeadlineIn(LfgStrings.duration(match.fillDeadline.difference(now))),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          LfgStrings.depositPerSlot,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        Text(
                          Formatters.vnd(match.depositPerSlot),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (isMine || joined)
                      _badge(isMine ? LfgStrings.yourMatch : LfgStrings.joined)
                    else if (onClaim != null && match.isClaimable(now))
                      ElevatedButton.icon(
                        onPressed: onClaim,
                        icon: const Icon(Icons.flash_on, size: 16, color: Colors.white),
                        label: const Text(LfgStrings.flashClaim, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.authPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    else
                      LfgStatusChip(match: match, now: now),
                  ],
                ),
                if ((isMine || joined) && status != LfgStatus.open) ...[
                  const SizedBox(height: 8),
                  LfgStatusChip(match: match, now: now),
                ],
                if ((isMine || joined) && match.activeCancelRequest(now) != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.how_to_vote_outlined, size: 16, color: AppColors.tagOrangeText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          LfgStrings.cancelRequestBy(match.cancelRequest!.requestedByName),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryGreen),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: AppColors.primaryGreen),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
          ],
        ),
      );

  static Widget _infoRow(IconData icon, String text, {String? trailing, bool highlight = false}) {
    final color = highlight ? AppColors.tagOrangeText : AppColors.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: highlight ? FontWeight.bold : FontWeight.normal),
          ),
        ),
        if (trailing != null)
          Text(trailing, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      ],
    );
  }
}
