import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings/booking_strings.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking/invite_by_phone.dart';

/// Chia tiền của MỘT đơn đặt sân (luồng mời bạn theo tài khoản): ai đã góp / chưa góp, hạn góp.
/// Người được mời: góp phần của mình. Người đặt: mời thêm (khi chưa ai góp), trả nốt phần còn lại.
class SplitBookingScreen extends StatefulWidget {
  final String bookingId;

  const SplitBookingScreen({super.key, required this.bookingId});

  @override
  State<SplitBookingScreen> createState() => _SplitBookingScreenState();
}

class _SplitBookingScreenState extends State<SplitBookingScreen> {
  Booking? _booking;
  String? _myId;
  String? _error;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_booking?.awaitingPayment ?? false)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final booking = await AppRepositories.booking.getBooking(widget.bookingId);
      final me = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _myId = me?.id;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is BookingException ? e.message : SplitPaymentStrings.loadError);
    }
  }

  /// Chạy một thao tác; thành công thì hiện [doneMessage] và cập nhật đơn.
  Future<void> _run(Future<Booking> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _booking = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(doneMessage), backgroundColor: AppColors.primaryGreen));
    } on BookingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
      _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payRemaining(int amount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(SplitPaymentStrings.payRemaining(amount)),
        content: const Text(SplitPaymentStrings.payRemainingConfirm),
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
    if (ok == true && mounted) {
      await _run(() => AppRepositories.booking.payRemaining(widget.bookingId), SplitPaymentStrings.payRemainingDone);
    }
  }

  void _inviteMore(Booking b) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(SplitPaymentStrings.inviteMore, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(SplitPaymentStrings.inviteMoreNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            InviteByPhoneField(
              excludeIds: b.participants.map((p) => p.userId).toSet(),
              onFound: (player) {
                Navigator.pop(sheetContext);
                _run(() => AppRepositories.booking.inviteMore(widget.bookingId, [player.id]),
                    SplitPaymentStrings.invitedMessage);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          SplitPaymentStrings.detailTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final b = _booking;
    if (b == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator(color: AppColors.primaryGreen)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text(SplitPaymentStrings.retry)),
                ],
              ),
      );
    }

    final now = DateTime.now();
    final isHost = b.bookerId == _myId;
    final cancelled = b.cancelledAt != null;
    final unpaid = b.participants.where((p) => !p.isPaid).toList();
    final someoneElsePaid = b.participants.any((p) => !p.isHost && p.isPaid);
    final left = b.splitDeadline.difference(now);

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.sportCourtLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                const SizedBox(height: 4),
                Text(b.facilityName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(b.location, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(b.schedule,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
                const Divider(height: 20),
                Row(
                  children: [
                    const Text(SplitPaymentStrings.total, style: TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(Formatters.vnd(b.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _statusBanner(b, cancelled, left),
          const SizedBox(height: 12),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in b.participants)
                  InviteeTile(
                    name: p.userId == _myId ? '${p.name} ${SplitPaymentStrings.you}' : p.name,
                    subtitle: p.isHost
                        ? '${SplitPaymentStrings.hostLabel} • ${Formatters.vnd(p.amount)}'
                        : Formatters.vnd(p.amount),
                    trailing: Text(
                      p.isPaid ? SplitPaymentStrings.contributed : SplitPaymentStrings.notContributed,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: p.isPaid ? AppColors.primaryGreen : AppColors.tagOrangeText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (b.awaitingPayment && !cancelled) ...[
            const SizedBox(height: 16),
            if (b.owesShare(_myId ?? ''))
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => AppRepositories.booking.joinSplit(widget.bookingId), SplitPaymentStrings.joinedMessage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(SplitPaymentStrings.payMyShare(b.myShare), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            if (isHost && unpaid.isNotEmpty) ...[
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _payRemaining(unpaid.fold(0, (sum, p) => sum + p.amount)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    SplitPaymentStrings.payRemaining(unpaid.fold(0, (sum, p) => sum + p.amount)),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                ),
              ),
              if (!someoneElsePaid)
                TextButton.icon(
                  onPressed: _busy ? null : () => _inviteMore(b),
                  icon: const Icon(Icons.person_add_alt_1, color: AppColors.primaryGreen),
                  label: const Text(SplitPaymentStrings.inviteMore, style: TextStyle(color: AppColors.primaryGreen)),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusBanner(Booking b, bool cancelled, Duration left) {
    final (text, bg, fg) = cancelled
        ? (BookingStrings.statusCancelled, const Color(0xFFFFEBEE), const Color(0xFFC62828))
        : !b.awaitingPayment
            ? (SplitPaymentStrings.fullyPaidNote, AppColors.lightGreen, AppColors.darkGreen)
            : left.isNegative
                ? (SplitPaymentStrings.deadlinePassed, AppColors.tagOrangeBg, AppColors.tagOrangeText)
                : (
                    SplitPaymentStrings.deadlineIn(
                        '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}'),
                    AppColors.tagOrangeBg,
                    AppColors.tagOrangeText,
                  );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}
