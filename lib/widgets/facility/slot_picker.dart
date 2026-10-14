import 'package:flutter/material.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';

/// Mô tả lịch của nhiều khung giờ, gom theo ngày, mỗi ngày một dòng:
/// "Thứ 4, 15/10: 18:00 - 19:00, 20:00 - 21:00\nThứ 6, 17/10: 07:00 - 08:00"
String describeSlotSchedule(Iterable<TimeSlot> slots) {
  final sorted = slots.toList()..sort((a, b) => a.start.compareTo(b.start));
  final byDay = <String, List<String>>{};
  for (final s in sorted) {
    byDay.putIfAbsent(Formatters.weekdayDayMonth(s.start), () => []).add(Formatters.timeRange(s.start, s.end));
  }
  return byDay.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n');
}

/// Thanh chọn ngày ngang (mặc định 7 ngày kể từ hôm nay).
class DateSelectorBar extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selected;

  /// Các ngày đang có khung giờ được chọn: hiện chấm nhỏ dưới ngày.
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onSelected;

  const DateSelectorBar({
    super.key,
    required this.dates,
    required this.selected,
    required this.onSelected,
    this.markedDates = const {},
  });

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _sameDay(date, selected);
          return GestureDetector(
            onTap: () => onSelected(date),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                // FittedBox thu nhỏ chữ khi người dùng đặt cỡ chữ hệ thống lớn, tránh tràn ô.
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _sameDay(date, today) ? FacilityStrings.today : Formatters.weekday(date),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Formatters.dayMonth(date),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !markedDates.any((d) => _sameDay(d, date))
                          ? Colors.transparent
                          : isSelected
                              ? Colors.white
                              : AppColors.tagOrangeText,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lưới khung giờ: hiển thị giờ, giá, số sân còn trống; khung đã qua hoặc hết sân thì khóa.
class TimeSlotGrid extends StatelessWidget {
  final List<TimeSlot> slots;
  final Set<String> selectedSlotIds;
  final DateTime now;
  final ValueChanged<TimeSlot> onSelected;

  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedSlotIds,
    required this.now,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(FacilityStrings.noSlots, style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 76,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        return _TimeSlotTile(
          slot: slot,
          isSelected: selectedSlotIds.contains(slot.id),
          isPassed: slot.hasStarted(now),
          onTap: () => onSelected(slot),
        );
      },
    );
  }
}

class _TimeSlotTile extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final bool isPassed;
  final VoidCallback onTap;

  const _TimeSlotTile({required this.slot, required this.isSelected, required this.isPassed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = isPassed || slot.isFull;
    final fewLeft = !disabled && slot.availableCourts == 1;

    final Color bg = isSelected
        ? AppColors.primaryGreen
        : disabled
            ? AppColors.divider
            : AppColors.white;
    final Color border = isSelected
        ? AppColors.primaryGreen
        : disabled
            ? AppColors.divider
            : AppColors.cardBorder;
    final Color mainText = isSelected
        ? Colors.white
        : disabled
            ? AppColors.textSecondary
            : AppColors.textMain;

    final String status = isPassed
        ? FacilityStrings.passed
        : slot.isFull
            ? FacilityStrings.full
            : FacilityStrings.courtsLeft(slot.availableCourts, slot.totalCourts);

    final Color statusColor = isSelected
        ? Colors.white
        : disabled
            ? AppColors.textSecondary
            : fewLeft
                ? AppColors.tagOrangeText
                : AppColors.primaryGreen;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // Ô có chiều cao cố định: mọi dòng chữ giữ 1 dòng để không tràn khi cỡ chữ lớn.
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.timeRange(slot.start, slot.end),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                  decoration: disabled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
                if (!disabled)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Formatters.vnd(slot.price),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
