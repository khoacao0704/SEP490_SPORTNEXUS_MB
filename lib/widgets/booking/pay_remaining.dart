import 'package:flutter/material.dart';

import '../../core/strings/split_payment_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/booking.dart';
import '../../theme/app_colors.dart';

/// Người đặt trả bù phần của những người chưa góp (POST /bookings/{id}/pay-remaining).
/// [booking] phải là đơn tải chi tiết (có participants). Hỏi xác nhận (ghi rõ số tiền) rồi gọi BE;
/// trả về đơn mới khi thành công, `null` khi bỏ qua hoặc lỗi (lỗi đã báo bằng SnackBar).
Future<Booking?> confirmPayRemaining(BuildContext context, Booking booking) async {
  final messenger = ScaffoldMessenger.of(context);
  final amount = booking.remainingUnpaid;
  if (amount <= 0) {
    messenger.showSnackBar(const SnackBar(content: Text(SplitPaymentStrings.nothingRemaining)));
    return null;
  }
  final people = booking.unpaidParticipants.length;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(SplitPaymentStrings.payRemainingTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(SplitPaymentStrings.remainingLabel, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    Formatters.vnd(amount),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.darkGreen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(SplitPaymentStrings.payRemainingConfirm(people)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(SplitPaymentStrings.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
          child: const Text(SplitPaymentStrings.confirm),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  try {
    final updated = await AppRepositories.booking.payRemaining(booking.id);
    messenger.showSnackBar(
      const SnackBar(content: Text(SplitPaymentStrings.payRemainingDone), backgroundColor: AppColors.primaryGreen),
    );
    return updated;
  } on BookingException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    return null;
  }
}
