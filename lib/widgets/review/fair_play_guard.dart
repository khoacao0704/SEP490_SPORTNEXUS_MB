import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/review.dart';
import '../../screens/fair_play/fair_play_screen.dart';
import '../../theme/app_colors.dart';

/// Kiểm tra Fair Play trước khi tạo kèo / Flash Claim LFG.
/// Trả về true nếu được phép; nếu không, hiện hộp thoại giải thích và trả về false.
/// (BE vẫn phải kiểm tra lại — đây chỉ là chặn sớm trên app.)
Future<bool> ensureCanJoinLfg(BuildContext context) async {
  FairPlaySummary summary;
  try {
    summary = await AppRepositories.review.getFairPlay();
  } catch (_) {
    // Không lấy được điểm thì để BE quyết định ở bước thanh toán.
    return true;
  }
  if (summary.canJoinLfg) return true;
  final until = summary.bannedUntil;
  final message = summary.isBanned
      ? ReviewStrings.bannedMessage(
          summary.banReason,
          until == null
              ? ReviewStrings.banForever
              : ReviewStrings.banUntil('${Formatters.time(until)} ${Formatters.dayMonth(until)}/${until.year}'),
        )
      : ReviewStrings.blockedMessage(summary.score, summary.minScoreForLfg);
  if (!context.mounted) return false;

  final openFairPlay = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.block, color: Colors.red, size: 40),
      title: const Text(ReviewStrings.blockedTitle),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(ReviewStrings.close)),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
          child: const Text(ReviewStrings.viewFairPlay),
        ),
      ],
    ),
  );
  if (openFairPlay == true && context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FairPlayScreen()));
  }
  return false;
}
