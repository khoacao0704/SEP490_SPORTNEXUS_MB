import 'package:flutter/material.dart';

import '../../core/strings/owner_slot_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_court.dart';
import '../../theme/app_colors.dart';

/// Nút chọn ngày (hiện dd/MM/yyyy).
class DateButton extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateTime? firstDate;
  final ValueChanged<DateTime> onChanged;

  const DateButton({super.key, required this.label, required this.value, this.firstDate, required this.onChanged});

  @override
  Widget build(BuildContext context) => _LabeledButton(
        label: label,
        text: Formatters.date(value),
        icon: Icons.calendar_today,
        onTap: () async {
          final first = firstDate ?? DateTime(2024);
          final picked = await showDatePicker(
            context: context,
            initialDate: value.isBefore(first) ? first : value,
            firstDate: first,
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
      );
}

/// Nút chọn giờ "HH:mm" 24h; [value] null hiện "--:--", bấm giữ để xóa khi [clearable].
class TimeButton extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool clearable;

  const TimeButton({super.key, required this.label, required this.value, required this.onChanged, this.clearable = true});

  @override
  Widget build(BuildContext context) => _LabeledButton(
        label: label,
        text: value ?? OwnerSlotStrings.timeEmpty,
        icon: Icons.schedule,
        trailing: clearable && value != null
            ? IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => onChanged(null),
              )
            : null,
        onTap: () async {
          final v = value;
          final initial = v == null
              ? const TimeOfDay(hour: 17, minute: 0)
              : TimeOfDay(hour: int.parse(v.substring(0, 2)) % 24, minute: int.parse(v.substring(3, 5)));
          final picked = await showTimePicker(
            context: context,
            initialTime: initial,
            builder: (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
          );
          if (picked != null) {
            onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
          }
        },
      );
}

class _LabeledButton extends StatelessWidget {
  final String label;
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  const _LabeledButton({required this.label, required this.text, required this.icon, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 16),
                  label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                ),
              ),
              ?trailing,
            ],
          ),
        ],
      );
}

/// Chọn thứ trong tuần (WeekDaySelector của Web): "Mọi ngày", từng thứ, chọn nhanh T2–T6 / cuối tuần.
/// [value] rỗng = mọi ngày.
class WeekDayPicker extends StatelessWidget {
  final List<int> value;
  final ValueChanged<List<int>> onChanged;

  const WeekDayPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final all = value.isEmpty || value.length >= 7;
    void toggle(int d) {
      final base = all ? [...WeekDays.ordered] : [...value];
      base.contains(d) ? base.remove(d) : base.add(d);
      onChanged(base.isEmpty || base.length >= 7 ? const [] : base);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${OwnerSlotStrings.weekDays}: ${all ? OwnerSlotStrings.everyDay : OwnerSlotStrings.picking(WeekDays.summary(value))}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(label: const Text(OwnerSlotStrings.everyDay), selected: all, onSelected: (_) => onChanged(const [])),
            ActionChip(label: const Text(OwnerSlotStrings.weekdaysPreset), onPressed: () => onChanged(const [1, 2, 3, 4, 5])),
            ActionChip(label: const Text(OwnerSlotStrings.weekendPreset), onPressed: () => onChanged(const [6, 0])),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in WeekDays.ordered)
              FilterChip(
                label: Text(WeekDays.short[d]!),
                selected: all || value.contains(d),
                onSelected: (_) => toggle(d),
              ),
          ],
        ),
      ],
    );
  }
}

/// Chọn sân (CourtPicker của Web): "Tất cả sân" hoặc từng sân. [value] rỗng = tất cả.
class CourtChips extends StatelessWidget {
  final List<OwnerCourt> courts;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String allLabel;

  const CourtChips({
    super.key,
    required this.courts,
    required this.value,
    required this.onChanged,
    this.allLabel = OwnerSlotStrings.allCourts,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          FilterChip(label: Text(allLabel), selected: value.isEmpty, onSelected: (_) => onChanged(const [])),
          for (final c in courts)
            FilterChip(
              label: Text(c.name),
              selected: value.contains(c.id),
              onSelected: (_) => onChanged(value.contains(c.id) ? (value.where((x) => x != c.id).toList()) : [...value, c.id]),
            ),
        ],
      );
}

/// Ô nhập số nguyên (giá, phút) có nhãn.
class NumberField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;

  const NumberField({super.key, required this.label, required this.controller, this.hint});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );
}

/// Hộp thoại xác nhận chung (confirmDialog của Web). Trả về true khi bấm [confirmLabel].
Future<bool> confirmOwner(
  BuildContext context,
  String message, {
  String? title,
  String confirmLabel = OwnerSlotStrings.confirm,
  String cancelLabel = OwnerSlotStrings.cancel,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: title == null ? null : Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(cancelLabel)),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? Colors.red : AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showOwnerSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null));
}
