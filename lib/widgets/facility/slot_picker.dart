import 'package:flutter/material.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';

/// Khung báo cơ sở đang tạm ngưng (hệ thống tự bật khi chủ sân quá hạn phản hồi khiếu nại), đặt trên lưới ca.
class SuspendedNotice extends StatelessWidget {
  const SuspendedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tagOrangeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pause_circle_outline, size: 18, color: AppColors.tagOrangeText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              FacilityStrings.suspendedNotice,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tagOrangeText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mô tả lịch của nhiều khung giờ, gom theo ngày, mỗi ngày một dòng:
/// "Thứ 4, 15/10: Sân 2 18:00 - 19:00, Sân 1 20:00 - 21:00\nThứ 6, 17/10: Sân 3 07:00 - 08:00"
String describeSlotSchedule(Iterable<TimeSlot> slots) {
  final sorted = slots.toList()..sort((a, b) => a.start.compareTo(b.start));
  final byDay = <String, List<String>>{};
  for (final s in sorted) {
    byDay
        .putIfAbsent(Formatters.weekdayDayMonth(s.start), () => [])
        .add('${s.courtName} ${Formatters.timeRange(s.start, s.end)}');
  }
  return byDay.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n');
}

/// Chọn sân con (Sân 1, Sân 2, ...) trước khi chọn giờ; mỗi sân hiện số khung còn trống trong ngày.
class CourtSelector extends StatelessWidget {
  final List<String> courts;
  final String? selected;

  /// Chọn nhiều sân cùng lúc: mọi sân trong tập này cùng sáng (thêm vào [selected]).
  final Set<String> selectedCourts;

  /// Số khung còn đặt được của từng sân trong ngày đang xem.
  final Map<String, int> freeSlots;

  /// Số khung người chơi đã chọn trên từng sân (để thấy sân nào đang có khung chọn khi xem sân khác).
  final Map<String, int> pickedSlots;
  final ValueChanged<String> onSelected;

  const CourtSelector({
    super.key,
    required this.courts,
    required this.selected,
    this.selectedCourts = const {},
    required this.freeSlots,
    this.pickedSlots = const {},
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final court in courts)
          _CourtChip(
            name: court,
            free: freeSlots[court] ?? 0,
            picked: pickedSlots[court] ?? 0,
            selected: court == selected || selectedCourts.contains(court),
            onTap: () => onSelected(court),
          ),
      ],
    );
  }
}

class _CourtChip extends StatelessWidget {
  final String name;
  final int free;
  final int picked;
  final bool selected;
  final VoidCallback onTap;

  const _CourtChip({
    required this.name,
    required this.free,
    this.picked = 0,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryGreen : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textMain,
                ),
              ),
              Text(
                FacilityStrings.freeSlotCount(free),
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.white70
                      : free == 0
                          ? AppColors.textSecondary
                          : AppColors.primaryGreen,
                ),
              ),
              if (picked > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: selected ? Colors.white : AppColors.tagOrangeText),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        FacilityStrings.courtSelectedCount(picked),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : AppColors.tagOrangeText,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách sân con theo thứ tự xuất hiện trong [slots] (repository đã sắp theo sân).
List<String> courtsOf(Iterable<TimeSlot> slots) => slots.map((s) => s.courtName).toSet().toList();

/// Số khung còn đặt được lúc [now] của từng sân con.
Map<String, int> freeSlotsByCourt(Iterable<TimeSlot> slots, DateTime now) {
  final result = <String, int>{};
  for (final s in slots) {
    result[s.courtName] = (result[s.courtName] ?? 0) + (s.isBookable(now) ? 1 : 0);
  }
  return result;
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

/// Lưới khung giờ của một sân con: hiển thị giờ, giá, còn trống hay không; khung đã qua hoặc đã có người đặt thì khóa.
class TimeSlotGrid extends StatelessWidget {
  final List<TimeSlot> slots;
  final Set<String> selectedSlotIds;
  final DateTime now;
  final ValueChanged<TimeSlot> onSelected;

  /// Có giá trị khi cơ sở đang tạm ngưng: mọi ca trống bị xám, bấm vào thì gọi hàm này (báo lý do) thay vì chọn.
  final VoidCallback? onSuspendedTap;

  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedSlotIds,
    required this.now,
    required this.onSelected,
    this.onSuspendedTap,
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
      // Ô cao 76 ở cỡ chữ gốc, tăng theo chữ phóng to (tối đa ×1.6) để 2 dòng chữ không tràn.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 46 + 30 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final suspended = onSuspendedTap;
        return _TimeSlotTile(
          slot: slot,
          isSelected: suspended == null && selectedSlotIds.contains(slot.id),
          isPassed: slot.hasStarted(now),
          isSuspended: suspended != null,
          onTap: suspended ?? () => onSelected(slot),
        );
      },
    );
  }
}

class _TimeSlotTile extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final bool isPassed;

  /// Cơ sở tạm ngưng: ca còn trống cũng xám nhưng vẫn bấm được để báo lý do.
  final bool isSuspended;
  final VoidCallback onTap;

  const _TimeSlotTile({
    required this.slot,
    required this.isSelected,
    required this.isPassed,
    required this.onTap,
    this.isSuspended = false,
  });

  @override
  Widget build(BuildContext context) {
    final taken = isPassed || slot.isFull;
    final suspendedFree = isSuspended && !taken;
    final disabled = taken || suspendedFree;

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
            : suspendedFree
                ? FacilityStrings.suspendedSlot
                : FacilityStrings.available;

    final Color statusColor = isSelected
        ? Colors.white
        : disabled
            ? AppColors.textSecondary
            : AppColors.primaryGreen;

    return GestureDetector(
      onTap: taken ? null : onTap,
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
                  decoration: taken ? TextDecoration.lineThrough : null,
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
