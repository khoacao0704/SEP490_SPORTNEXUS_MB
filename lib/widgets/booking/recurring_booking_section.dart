import 'package:flutter/material.dart';

import '../../core/constants/booking_rules.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/recurring_plan.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';

/// "Sân 1, Sân 2 • 08:00 - 10:00" khi mọi sân cùng giờ; khác giờ thì "Sân 1 08:00 - 10:00; Sân 2 08:00 - 09:00".
/// Các khung liền nhau trên cùng sân gộp thành một khoảng giờ.
String describeCourtTimes(List<TimeSlot> slots) {
  final byCourt = <String, List<TimeSlot>>{};
  for (final s in slots) {
    (byCourt[s.courtName] ??= []).add(s);
  }
  final ranges = <String, String>{};
  for (final e in byCourt.entries) {
    final sorted = [...e.value]..sort((a, b) => a.start.compareTo(b.start));
    final parts = <(DateTime, DateTime)>[];
    for (final s in sorted) {
      if (parts.isNotEmpty && parts.last.$2 == s.start) {
        parts[parts.length - 1] = (parts.last.$1, s.end);
      } else {
        parts.add((s.start, s.end));
      }
    }
    ranges[e.key] = parts.map((r) => Formatters.timeRange(r.$1, r.$2)).join(', ');
  }
  final courts = ranges.keys.toList()..sort();
  if (ranges.values.toSet().length == 1) return '${courts.join(', ')} • ${ranges.values.first}';
  return courts.map((c) => '$c ${ranges[c]}').join('; ');
}

/// Banner "Cơ sở này giảm X% khi bạn đặt cố định hằng tuần..." ở trang sân (chỉ hiện khi cơ sở có giảm).
class RecurringDiscountBanner extends StatelessWidget {
  final int percent;

  const RecurringDiscountBanner({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department, size: 20, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              BookingStrings.discountBanner(percent),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bật "Đặt lặp lại hằng tuần": chọn thứ trong tuần (T2–CN), số tuần tính từ ngày bắt đầu,
/// rồi xem từng ngày còn trống hay bị kẹt.
class RecurringBookingSection extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;

  /// false: đang chọn khung trên nhiều sân con → khóa công tắc, hiện lý do.
  final bool available;
  final int discountPercent;

  /// Các khung đang chọn làm được mẫu (cùng 1 ngày bắt đầu, 1 sân con).
  final bool patternValid;

  /// Ngày bắt đầu (ngày của các khung đang chọn); `null` khi chưa chọn.
  final DateTime? startDate;

  /// Số khung (giờ × sân) đã chọn trong ngày bắt đầu, và số sân con của chúng.
  final int slotsPerDay;
  final int courtCount;

  /// Thứ trong tuần được lặp (1 = T2 … 7 = CN).
  final Set<int> weekdays;
  final ValueChanged<int> onWeekdayToggled;
  final int weeks;
  final ValueChanged<int> onWeeksChanged;
  final RecurringPlan? plan;
  final bool planning;

  const RecurringBookingSection({
    super.key,
    required this.enabled,
    required this.onToggle,
    this.available = true,
    required this.discountPercent,
    required this.patternValid,
    this.startDate,
    this.slotsPerDay = 0,
    this.courtCount = 1,
    required this.weekdays,
    required this.onWeekdayToggled,
    required this.weeks,
    required this.onWeeksChanged,
    required this.plan,
    required this.planning,
  });

  @override
  Widget build(BuildContext context) {
    // Material (không phải Container có màu nền) để hiệu ứng bấm của CheckboxListTile hiện được.
    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: enabled ? AppColors.primaryGreen : AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô tick "Lặp lại vào giờ này mỗi tuần".
          CheckboxListTile(
            value: enabled,
            onChanged: available || enabled ? (v) => onToggle(v ?? false) : null,
            activeColor: AppColors.primaryGreen,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: const Icon(Icons.event_repeat, color: AppColors.primaryGreen),
            title: const Text(
              BookingStrings.recurringToggle,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            subtitle: Text(
              available ? BookingStrings.recurringToggleHint(discountPercent) : BookingStrings.recurringOneCourtOnly,
              style: TextStyle(fontSize: 12, color: available ? AppColors.textSecondary : AppColors.tagOrangeText),
            ),
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: patternValid ? _buildPlan() : _note(BookingStrings.recurringPatternHint, AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildPlan() {
    final plan = this.plan;
    final start = startDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (start != null) ...[
          Text(
            BookingStrings.recurringStartFrom(Formatters.weekdayDayMonth(start)),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
        _title(BookingStrings.recurringWeekdaysTitle),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              _chip(BookingStrings.weekdayShort[d - 1], weekdays.contains(d), () => onWeekdayToggled(d)),
          ],
        ),
        const SizedBox(height: 10),
        _title(BookingStrings.recurringWeeksTitle),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = RecurringBookingRules.minSessions; n <= RecurringBookingRules.maxSessions; n++)
              _chip(BookingStrings.recurringWeeks(n), n == weeks, () => onWeeksChanged(n)),
          ],
        ),
        const SizedBox(height: 10),
        if (weekdays.isEmpty)
          _note(BookingStrings.recurringNoWeekday, Colors.red)
        else if (planning || plan == null)
          const Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
              SizedBox(width: 8),
              Expanded(
                child: Text(BookingStrings.recurringChecking, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          )
        else ...[
          Text(
            BookingStrings.recurringCount(
              weekdays.length,
              slotsPerDay,
              courtCount,
              weeks,
              weekdays.length * slotsPerDay * weeks,
            ),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 4),
          for (final s in plan.sessions) _sessionRow(s),
          if (!plan.isComplete) ...[
            const SizedBox(height: 6),
            _note(BookingStrings.recurringIncomplete, Colors.red),
          ],
          const SizedBox(height: 6),
          _note(BookingStrings.recurringCancelRule, AppColors.textSecondary),
        ],
      ],
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryGreen,
        backgroundColor: AppColors.white,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMain),
        side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
      );

  Widget _sessionRow(RecurringSession s) => RecurringDayRow(session: s);

  Widget _note(String text, Color color) => Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.4));
}

/// Một ngày trong lịch lặp lại: ✔ xanh khi đặt được, ❌ đỏ kèm lý do khi kẹt.
/// [invalidReason]: ngày này đặt được nhưng thuộc gói sai luật (màn Thanh toán kiểm lại) → vẫn đánh ❌.
class RecurringDayRow extends StatelessWidget {
  final RecurringSession session;
  final String? invalidReason;

  const RecurringDayRow({super.key, required this.session, this.invalidReason});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final issue = switch (s.issue) {
          RecurringIssue.taken => BookingStrings.recurringWeekTaken,
          RecurringIssue.notOpen => BookingStrings.recurringWeekNotOpen,
          RecurringIssue.lengthMismatch => BookingStrings.recurringWeekLengthMismatch,
          null => null,
        } ??
        invalidReason;
    final ok = issue == null;
    final times = describeCourtTimes(s.slots);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 16, color: ok ? AppColors.primaryGreen : Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              times.isEmpty ? Formatters.weekdayDayMonth(s.date) : '${Formatters.weekdayDayMonth(s.date)} • $times',
              style: const TextStyle(fontSize: 12, color: AppColors.textMain),
            ),
          ),
          if (issue != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                issue,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
