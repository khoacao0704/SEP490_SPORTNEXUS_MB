import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/booking_rules.dart';
import '../../core/strings/owner_facility_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';

/// Ô nhập % giảm cho gói cố định hằng tuần (0–50, 0 = không giảm) + nút Lưu.
/// Cơ sở chưa giảm thì gợi ý sẵn 10%. Cơ sở đang bị từ chối: hỏi lại vì lưu xong BE chuyển về chờ duyệt.
class RecurringDiscountEditor extends StatefulWidget {
  final OwnerFacility facility;
  final ValueChanged<OwnerFacility> onSaved;

  const RecurringDiscountEditor({super.key, required this.facility, required this.onSaved});

  @override
  State<RecurringDiscountEditor> createState() => _RecurringDiscountEditorState();
}

class _RecurringDiscountEditorState extends State<RecurringDiscountEditor> {
  late final TextEditingController _controller = TextEditingController(text: _initialText);
  bool _saving = false;

  int get _current => widget.facility.recurringDiscountPercent;

  String get _initialText => '${_current > 0 ? _current : RecurringBookingRules.suggestedDiscountPercent}';

  /// Số đang nhập nếu hợp lệ (0–50), ngược lại `null`.
  int? get _value {
    final v = int.tryParse(_controller.text.trim());
    return v != null && v >= 0 && v <= RecurringBookingRules.maxDiscountPercent ? v : null;
  }

  @override
  void didUpdateWidget(RecurringDiscountEditor old) {
    super.didUpdateWidget(old);
    if (old.facility.recurringDiscountPercent != _current) _controller.text = _initialText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _value;
    if (value == null || _saving) return;
    FocusScope.of(context).unfocus();
    if (widget.facility.status == ApprovalStatus.rejected && !await _confirmRejected()) return;
    setState(() => _saving = true);
    try {
      final updated = await AppRepositories.owner.updateRecurringDiscount(widget.facility.id, value);
      if (!mounted) return;
      widget.onSaved(updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(OwnerFacilityStrings.discountSaved(value))));
    } on OwnerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmRejected() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(OwnerFacilityStrings.discountRejectedTitle),
          content: const Text(OwnerFacilityStrings.discountRejectedWarning),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(OwnerFacilityStrings.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(OwnerFacilityStrings.discountRejectedConfirm),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final invalid = _controller.text.trim().isNotEmpty && value == null;
    final canSave = !_saving && value != null && value != _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          OwnerFacilityStrings.discountCurrent(_current),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        if (widget.facility.status == ApprovalStatus.rejected) ...[
          const SizedBox(height: 4),
          Text(
            OwnerFacilityStrings.discountRejectedWarning,
            style: TextStyle(fontSize: 12, color: Colors.red.shade700, height: 1.4),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: OwnerFacilityStrings.discountLabel,
                  suffixText: '%',
                  isDense: true,
                  errorText: invalid ? OwnerFacilityStrings.discountInvalid : null,
                  errorMaxLines: 2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ElevatedButton(
                onPressed: canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(OwnerFacilityStrings.discountSave),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
