import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/court_session.dart';
import '../../theme/app_colors.dart';

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}

/// Check-in một người chơi vào sân con đã đặt.
/// Trả về lượt sân sau khi check-in, hoặc `null` nếu bỏ qua / lỗi.
Future<CourtSession?> checkInPlayer(BuildContext context, CourtSession session, SessionPlayer player) async {
  final result = await showModalBottomSheet<CourtSession>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _CheckInSheet(session: session, player: player),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(OwnerStrings.checkInSuccess(player.name, result.assignedCourt))));
  }
  return result;
}

/// Check-out cả lượt sân sau khi chủ sân xác nhận đã nhận đủ tiền.
Future<CourtSession?> checkOutSession(BuildContext context, CourtSession session) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(OwnerStrings.confirmCheckOutTitle),
      content: Text(
        OwnerStrings.confirmCheckOut(
          escrow: session.paidViaApp,
          remaining: session.remainingToCollect,
          isLfg: session.kind == SessionKind.lfg,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(OwnerStrings.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
          child: const Text(OwnerStrings.checkOut),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;
  try {
    final updated = await AppRepositories.owner.checkOut(session.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(OwnerStrings.checkOutSuccess(updated.paidViaApp))));
    }
    return updated;
  } on OwnerException catch (e) {
    if (context.mounted) _showError(context, e.message);
    return null;
  }
}

class _CheckInSheet extends StatefulWidget {
  final CourtSession session;
  final SessionPlayer player;

  const _CheckInSheet({required this.session, required this.player});

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await AppRepositories.owner.checkIn(
        sessionId: widget.session.id,
        userId: widget.player.userId,
      );
      if (mounted) Navigator.pop(context, updated);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.player.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 4),
            Text(
              '${s.facilityName}\n${s.sportLabel} • ${Formatters.slotLabel(s.start, s.end)}',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Sân con người chơi đã chọn lúc đặt; chủ sân chỉ cần xếp vào đúng sân này.
            Row(
              children: [
                const Icon(Icons.grid_view, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  OwnerStrings.bookedCourt(s.assignedCourt),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(OwnerStrings.confirmCheckIn, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
