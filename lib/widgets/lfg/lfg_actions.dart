import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
import '../../models/booking.dart' show CancelReason;
import '../../models/lfg_match.dart';
import '../../screens/lfg/lfg_payment_screen.dart';
import '../../theme/app_colors.dart';
import '../review/fair_play_guard.dart';

/// Flash Claim một kèo: kiểm tra Fair Play → giữ chỗ 10 phút → thanh toán cọc.
/// Trả về kèo sau khi vào thành công, `null` nếu bị chặn / hủy / lỗi (đã báo cho người dùng).
Future<LfgMatch?> flashClaimMatch(BuildContext context, LfgMatch match) async {
  if (!await ensureCanJoinLfg(context) || !context.mounted) return null;

  final LfgClaim claim;
  try {
    claim = await AppRepositories.lfg.claimSlot(match.id);
  } on LfgException catch (e) {
    if (context.mounted) showLfgError(context, e.message);
    return null;
  } catch (_) {
    if (context.mounted) showLfgError(context, LfgStrings.loadError);
    return null;
  }
  if (!context.mounted) {
    AppRepositories.lfg.releaseClaim(claim.claimId);
    return null;
  }

  final m = claim.match;
  final joined = await Navigator.push<LfgMatch>(
    context,
    MaterialPageRoute(
      builder: (_) => LfgPaymentScreen(
        summary: LfgPaymentSummary(
          heading: LfgStrings.flashClaim,
          sport: m.sport,
          format: m.format,
          courtType: m.courtType,
          facilityName: m.facilityCourtLabel,
          district: m.district,
          start: m.start,
          end: m.end,
        ),
        amount: claim.amount,
        expiresAt: claim.expiresAt,
        onConfirm: () => AppRepositories.lfg.confirmClaim(claim.claimId),
        onRelease: () => AppRepositories.lfg.releaseClaim(claim.claimId),
      ),
    ),
  );
  if (joined != null && context.mounted) {
    // Kèo cần chủ kèo duyệt: mới gửi yêu cầu, chưa vào kèo.
    final pending = joined.myStatus == LfgMyStatus.pendingApproval;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pending ? LfgStrings.pendingApprovalNote : LfgStrings.joinSuccess),
        backgroundColor: pending ? null : AppColors.primaryGreen,
      ),
    );
  }
  return joined;
}

/// Hộp xác nhận rời / xin hủy kèo kèm chọn lý do ([LfgRepository.getLeaveReasons]).
/// Trả về lý do đã chọn ('' nếu không có danh sách lý do), `null` nếu người dùng không xác nhận.
/// Có danh sách lý do thì phải chọn một (BE bắt buộc lý do khi đã vào kèo).
Future<String?> confirmLfgWithReason(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  // Không tải được danh sách lý do thì vẫn cho xác nhận (BE báo lỗi nếu bắt buộc).
  var reasons = const <CancelReason>[];
  try {
    reasons = await AppRepositories.lfg.getLeaveReasons();
  } catch (_) {
    // bỏ qua
  }
  if (!context.mounted) return null;
  CancelReason? picked;
  final noteController = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final note = noteController.text.trim();
        final ready = reasons.isEmpty || (picked != null && (!picked!.isCustom || note.isNotEmpty));
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(LfgStrings.reasonTitle, style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioGroup<CancelReason>(
                    groupValue: picked,
                    onChanged: (r) => setDialogState(() => picked = r),
                    child: Column(
                      children: [
                        for (final r in reasons)
                          RadioListTile<CancelReason>(
                            value: r,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.label, style: const TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  if (picked?.isCustom ?? false)
                    TextField(
                      controller: noteController,
                      maxLength: 200,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(hintText: LfgStrings.reasonHint, isDense: true),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(LfgStrings.keep)),
            ElevatedButton(
              onPressed: ready ? () => Navigator.pop(dialogContext, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(action),
            ),
          ],
        );
      },
    ),
  );
  final note = noteController.text.trim();
  noteController.dispose();
  if (ok != true) return null;
  final reason = picked;
  return reason == null ? '' : (reason.isCustom ? note : reason.label);
}

void showLfgError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
