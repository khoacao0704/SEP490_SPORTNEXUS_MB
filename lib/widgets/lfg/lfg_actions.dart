import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
import '../../models/booking.dart' show CancelReason;
import '../../models/lfg_match.dart';
import '../../models/team.dart';
import '../../screens/lfg/lfg_payment_screen.dart';
import '../../theme/app_colors.dart';
import '../common/onboarding_required.dart';
import '../review/fair_play_guard.dart';
import 'team_picker.dart';

/// Flash Claim một kèo: kiểm tra Fair Play → giữ chỗ 10 phút → thanh toán cọc.
/// Trả về kèo sau khi vào thành công, `null` nếu bị chặn / hủy / lỗi (đã báo cho người dùng).
Future<LfgMatch?> flashClaimMatch(BuildContext context, LfgMatch match) async {
  if (!await ensureCanJoinLfg(context) || !context.mounted) return null;

  // Kèo cần duyệt: chỉ gửi yêu cầu, chưa trừ Điểm → không qua màn thanh toán.
  if (match.requireApproval && !match.isTeamMatch) return _requestToJoin(context, match);

  // Kèo Đội vs Đội: đội trưởng chọn đội của mình để nhận kèo thay cả đội.
  Team? team;
  if (match.isTeamMatch) {
    team = await pickTeamForClaim(context, sport: match.sport, sideSize: match.sideSize ?? match.totalSlots ~/ 2);
    if (team == null || !context.mounted) return null;
  }

  final LfgClaim claim;
  try {
    claim = await AppRepositories.lfg.claimSlot(match.id);
  } on LfgException catch (e) {
    if (context.mounted && !await handleOnboardingRequired(context, e) && context.mounted) {
      showLfgError(context, e.message);
    }
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
        onConfirm: () => AppRepositories.lfg.confirmClaim(claim.claimId, teamId: team?.id),
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

/// Gửi yêu cầu vào kèo cần chủ kèo duyệt. Trả về kèo (myStatus = chờ duyệt) hoặc `null`.
Future<LfgMatch?> _requestToJoin(BuildContext context, LfgMatch match) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.verified_user_outlined, color: AppColors.tagOrangeText, size: 36),
      title: const Text(LfgStrings.requestDialogTitle, textAlign: TextAlign.center),
      content: Text(LfgStrings.requestDialogMessage(match.depositPerSlot)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(LfgStrings.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.authPrimary, foregroundColor: Colors.white),
          child: const Text(LfgStrings.sendRequestLong),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;
  try {
    final claim = await AppRepositories.lfg.claimSlot(match.id);
    final sent = await AppRepositories.lfg.confirmClaim(claim.claimId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(LfgStrings.requestSent)));
    }
    return sent;
  } on LfgException catch (e) {
    if (context.mounted && !await handleOnboardingRequired(context, e) && context.mounted) {
      showLfgError(context, e.message);
    }
  } catch (_) {
    if (context.mounted) showLfgError(context, LfgStrings.loadError);
  }
  return null;
}

/// Hộp xác nhận rời / xin hủy kèo kèm chọn lý do ([LfgRepository.getLeaveReasons]).
/// Trả về lý do đã chọn ('' nếu không có danh sách lý do), `null` nếu người dùng không xác nhận.
/// Có danh sách lý do thì phải chọn một (BE bắt buộc lý do khi đã vào kèo).
Future<String?> confirmLfgWithReason(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String? warning,
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
          title: warning == null
              ? Text(title)
              : Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cảnh báo đỏ (vd. rời kèo sát giờ: không hoàn + trừ Fair Play).
                if (warning != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      warning,
                      style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                      maxLength: 500,
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
