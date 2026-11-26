import 'package:flutter/material.dart';

import '../../core/constants/owner_rules.dart';
import '../../core/strings/common_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/booking.dart' show CancelReason;
import '../../models/owner_booking.dart';

/// Thông tin cần để Chủ sân hủy một đơn (từ dòng danh sách, chi tiết đơn hoặc ô lưới lịch).
class OwnerCancelTarget {
  final String bookingId;
  final String courtName;
  final String? customerName;
  final DateTime start;
  final DateTime? end;
  final int totalAmount;
  final bool isWalkIn;

  const OwnerCancelTarget({
    required this.bookingId,
    required this.courtName,
    this.customerName,
    required this.start,
    this.end,
    required this.totalAmount,
    this.isWalkIn = false,
  });

  factory OwnerCancelTarget.fromBooking(OwnerBooking b) => OwnerCancelTarget(
        bookingId: b.id,
        courtName: b.courtName,
        customerName: b.customerName,
        start: b.start,
        end: b.end,
        totalAmount: b.totalAmount,
        isWalkIn: b.isWalkIn,
      );
}

/// Popup cảnh báo + xác nhận Chủ sân hủy đơn (OwnerCancelBookingModal của Web).
/// BE không có API xem trước tiền phạt: tự tính theo mốc 48h, đơn vãng lai không phạt.
/// Trả về `true` khi đã hủy xong (đã báo kết quả bằng SnackBar).
Future<bool> showOwnerCancelDialog(BuildContext context, OwnerCancelTarget target) async {
  final result = await showDialog<OwnerCancelResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OwnerCancelDialog(target: target, now: DateTime.now()),
  );
  if (result == null || !context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(OwnerStrings.cancelledMessage(result))));
  return true;
}

class _OwnerCancelDialog extends StatefulWidget {
  final OwnerCancelTarget target;
  final DateTime now;

  const _OwnerCancelDialog({required this.target, required this.now});

  @override
  State<_OwnerCancelDialog> createState() => _OwnerCancelDialogState();
}

class _OwnerCancelDialogState extends State<_OwnerCancelDialog> {
  final _reasonText = TextEditingController();
  List<CancelReason> _reasons = const [];
  int? _reasonCode;
  bool _lockSlot = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  @override
  void dispose() {
    _reasonText.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    try {
      final list = await AppRepositories.owner.getCancelReasons();
      if (!mounted) return;
      setState(() {
        _reasons = list;
        _reasonCode ??= list.firstOrNull?.code;
      });
    } catch (_) {
      // Không tải được lý do thì vẫn cho tự nhập (như Web).
    }
  }

  CancelReason? get _picked => _reasons.where((r) => r.code == _reasonCode).firstOrNull;

  bool get _needsText => _reasons.isEmpty || (_picked?.isCustom ?? false);

  Future<void> _submit() async {
    final picked = _picked;
    final text = _reasonText.text.trim();
    if ((picked?.isCustom ?? false) && text.isEmpty) {
      setState(() => _error = OwnerStrings.cancelReasonRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await AppRepositories.owner.cancelBooking(
        widget.target.bookingId,
        reasonCode: picked?.code,
        reason: (picked?.isCustom ?? false) ? text : (picked?.label ?? (text.isEmpty ? null : text)),
        lockSlot: _lockSlot,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is OwnerException ? e.message : OwnerStrings.cancelFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final late = OwnerCancelRules.isLate(t.start, widget.now);
    final percent = OwnerCancelRules.percentFor(late: late, walkIn: t.isWalkIn);
    final fairPlay = OwnerCancelRules.fairPlayFor(late: late, walkIn: t.isWalkIn);
    final hasPenalty = percent > 0 || fairPlay > 0;
    final subtitle = [
      t.courtName,
      if (t.customerName != null) t.customerName!,
      '${Formatters.dateTime(t.start)}${t.end == null ? '' : ' – ${Formatters.time(t.end!)}'}',
    ].join(' • ');

    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
      title: const Text(
        OwnerStrings.cancelBookingTitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hasPenalty ? Colors.red : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(OwnerStrings.cancelPenaltyLabel, OwnerStrings.cancelPenaltyValue(percent)),
                  const SizedBox(height: 6),
                  _row(OwnerStrings.cancelFairPlayLabel, OwnerStrings.cancelFairPlay(fairPlay)),
                  const SizedBox(height: 8),
                  Text(
                    OwnerStrings.cancelWarning(percent, fairPlay: fairPlay, walkIn: t.isWalkIn),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(OwnerStrings.cancelPolicyNote, style: TextStyle(fontSize: 12, color: Colors.black54)),
            if (_reasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(OwnerStrings.cancelReasonLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                initialValue: _reasonCode,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final r in _reasons)
                    DropdownMenuItem(value: r.code, child: Text(r.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _submitting ? null : (v) => setState(() => _reasonCode = v),
              ),
            ],
            if (_needsText) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reasonText,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: OwnerStrings.cancelReasonHint,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            CheckboxListTile(
              value: _lockSlot,
              onChanged: _submitting ? null : (v) => setState(() => _lockSlot = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text(OwnerStrings.cancelLockSlot, style: TextStyle(fontSize: 13)),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text(OwnerStrings.cancelBack),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: Text(
            _submitting
                ? OwnerStrings.cancelling
                : hasPenalty
                    ? OwnerStrings.cancelConfirmPenalty
                    : OwnerStrings.cancelConfirm,
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.red),
            ),
          ),
        ],
      );
}

/// Câu lỗi chung để các màn Owner báo khi gọi thất bại.
String ownerErrorMessage(Object e) => e is OwnerException ? e.message : CommonStrings.genericError;
