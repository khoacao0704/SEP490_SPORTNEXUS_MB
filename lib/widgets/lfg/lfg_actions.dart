import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
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
          facilityName: m.facilityName,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(LfgStrings.joinSuccess), backgroundColor: AppColors.primaryGreen),
    );
  }
  return joined;
}

void showLfgError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
