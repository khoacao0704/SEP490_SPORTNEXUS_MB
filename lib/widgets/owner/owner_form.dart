import 'package:flutter/material.dart';

import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';

/// Kiểu ô nhập dùng chung cho các form Chủ sân.
InputDecoration ownerInputDecoration(String label, {String? hint, String? suffix}) => InputDecoration(
  labelText: label,
  hintText: hint,
  suffixText: suffix,
  isDense: true,
  filled: true,
  fillColor: AppColors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.cardBorder),
  ),
);

/// Số điện thoại cơ sở: cho phép cả số bàn, bỏ qua khoảng trắng / dấu chấm.
bool isFacilityPhone(String value) => RegExp(r'^0\d{9,10}$').hasMatch(value.replaceAll(RegExp(r'[\s.]'), ''));

/// Khối có tiêu đề trong form.
class FormSection extends StatelessWidget {
  final String title;
  final String? hint;
  final List<Widget> children;
  final Widget? trailing;

  const FormSection({super.key, required this.title, required this.children, this.hint, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                ),
              ),
              ?trailing,
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Ô chọn giờ (phút tính từ 0 giờ), bấm mở bộ chọn giờ.
class TimeField extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const TimeField({super.key, required this.label, required this.minutes, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: ownerInputDecoration(label),
        child: Row(
          children: [
            Expanded(
              child: Text(formatMinutes(minutes), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Nút tăng / giảm số nguyên (vd. số sân con).
class CountStepper extends StatelessWidget {
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const CountStepper({super.key, required this.value, required this.onChanged, this.min = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.primaryGreen,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primaryGreen,
        ),
      ],
    );
  }
}

/// Nút chính cuối màn form.
class SubmitBar extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const SubmitBar({super.key, required this.label, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ElevatedButton(
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// Hộp thoại nhập một dòng chữ; trả về nội dung (đã bỏ khoảng trắng) hoặc `null` nếu hủy / để trống.
/// Ô nhập do chính hộp thoại giữ để không bị hủy khi hiệu ứng đóng còn đang chạy.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(title: title, confirmLabel: confirmLabel, cancelLabel: cancelLabel),
  );
  final text = result?.trim() ?? '';
  return text.isEmpty ? null : text;
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String cancelLabel;

  const _TextPromptDialog({required this.title, required this.confirmLabel, required this.cancelLabel});

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: _controller, autofocus: true, maxLines: null),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancelLabel)),
      TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(widget.confirmLabel)),
    ],
  );
}
