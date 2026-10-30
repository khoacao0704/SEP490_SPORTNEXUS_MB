import 'package:flutter/material.dart';

import '../../core/strings/ai_chat_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/ai_chat.dart';
import '../../theme/app_colors.dart';
import '../facility/sport_icon.dart';

/// Thẻ một sân AI gợi ý: thông tin sân và các ca trống (bấm ca để đặt).
class AiFacilityCard extends StatelessWidget {
  final AiFacilitySuggestion facility;
  final void Function(AiSlot slot) onSlot;
  final VoidCallback onView;

  const AiFacilityCard({super.key, required this.facility, required this.onSlot, required this.onView});

  @override
  Widget build(BuildContext context) {
    final f = facility;
    return _CardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(f.sport == null ? Icons.sports : sportIcon(f.sport!), size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  f.facilityName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ),
              TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text(AiChatStrings.viewFacility),
              ),
            ],
          ),
          Text(
            [
              f.sportLabel,
              if (f.minPrice > 0) AiChatStrings.fromPrice(f.minPrice),
            ].where((s) => s.isNotEmpty).join(' • '),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
          ),
          if (f.address.isNotEmpty)
            Text(f.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (f.slots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in f.slots)
                  ActionChip(
                    key: ValueKey('ai-slot-${s.courtSlotId}'),
                    onPressed: () => onSlot(s),
                    backgroundColor: AppColors.lightGreen,
                    side: BorderSide.none,
                    label: Text(
                      '${Formatters.weekdayDayMonth(s.start)} ${Formatters.timeRange(s.start, s.end)}'
                      '${s.courtName.isEmpty ? '' : ' • ${s.courtName}'} • ${Formatters.vnd(s.price)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ một kèo LFG AI gợi ý (bấm để mở chi tiết kèo và nhận suất).
class AiLfgCard extends StatelessWidget {
  final AiLfgSuggestion card;
  final VoidCallback onTap;

  const AiLfgCard({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = card;
    final start = c.start;
    return _CardFrame(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.sport == null ? Icons.groups : sportIcon(c.sport!), size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [c.sportLabel, c.facilityName].where((s) => s.isNotEmpty).join(' • '),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
          if (start != null)
            Text(
              '${Formatters.weekdayDayMonth(start)} ${c.end == null ? Formatters.time(start) : Formatters.timeRange(start, c.end!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMain),
            ),
          Text(
            [
              if (c.hostName.isNotEmpty) AiChatStrings.host(c.hostName),
              if (c.skillLevel.isNotEmpty) c.skillLevel,
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${AiChatStrings.slotsLeft(c.remainingSlots)} • ${AiChatStrings.pricePerPerson(c.pricePerPerson)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}

class _CardFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _CardFrame({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    );
  }
}
