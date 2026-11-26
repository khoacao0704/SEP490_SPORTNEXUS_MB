import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/owner_booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';

/// Chi tiết đơn đặt sân (BookingDetailModal của Web): người đặt, tiền, người chơi, kèo LFG,
/// nút Hủy đơn (PENDING / PAID) và Kết thúc ca sớm (đã check-in, chưa hết giờ).
/// Pop trả về `true` nếu đơn đã thay đổi để màn trước tải lại.
class OwnerBookingDetailScreen extends StatefulWidget {
  final String bookingId;

  /// Bấm "Mở lịch đặt sân": màn trước chuyển sang lưới lịch.
  final VoidCallback? onOpenSchedule;

  const OwnerBookingDetailScreen({super.key, required this.bookingId, this.onOpenSchedule});

  @override
  State<OwnerBookingDetailScreen> createState() => _OwnerBookingDetailScreenState();
}

class _OwnerBookingDetailScreenState extends State<OwnerBookingDetailScreen> {
  OwnerBooking? _booking;
  String? _error;
  bool _changed = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await AppRepositories.owner.getBooking(widget.bookingId);
      if (mounted) {
        setState(() {
          _booking = b;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ownerErrorMessage(e));
    }
  }

  Future<void> _cancel() async {
    final b = _booking;
    if (b == null) return;
    if (await showOwnerCancelDialog(context, OwnerCancelTarget.fromBooking(b))) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _endEarly() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(OwnerStrings.endEarlyTitle),
        content: const Text(OwnerStrings.endEarlyBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(OwnerStrings.cancelBack)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(OwnerStrings.endEarlyConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _ending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppRepositories.owner.endBooking(widget.bookingId);
      messenger.showSnackBar(const SnackBar(content: Text(OwnerStrings.endEarlyDone)));
      _changed = true;
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is OwnerException ? e.message : OwnerStrings.endEarlyFailed),
        backgroundColor: Colors.red,
      ));
    }
    if (mounted) setState(() => _ending = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(
            OwnerStrings.detailTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: b == null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    if (_error == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ],
                )
              : _content(b),
        ),
        bottomNavigationBar: b == null ? null : _actions(b),
      ),
    );
  }

  Widget _content(OwnerBooking b) {
    final lfg = b.lfg;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${b.courtName}${b.sportName.isEmpty ? '' : ' • ${b.sportName}'} • '
          '${Formatters.dateTime(b.start)} – ${Formatters.time(b.end)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            BookingStatusBadge(b.status),
            if (b.isWalkIn) const OwnerBadge(OwnerStrings.walkInBadge, tone: BadgeTone.gray),
            if (lfg != null) const OwnerBadge(OwnerStrings.lfgBadge, tone: BadgeTone.blue),
            if (b.isNoShow) const OwnerBadge(OwnerStrings.noShowBadge, tone: BadgeTone.red),
          ],
        ),
        const SizedBox(height: 12),
        _card([
          _info(OwnerStrings.detailBooker, b.customerName ?? '—', sub: b.customerPhone),
          _info(OwnerStrings.detailTotal, Formatters.vnd(b.totalAmount)),
          _info(OwnerStrings.detailPaid, Formatters.vnd(b.paidAmount)),
          _info(OwnerStrings.detailPending, Formatters.vnd(b.pendingAmount)),
          _info(OwnerStrings.detailCreated, b.createdAt == null ? '—' : Formatters.dateTime(b.createdAt!)),
        ]),
        if (b.customerNote != null) ...[
          const SizedBox(height: 12),
          _card([
            const Text(OwnerStrings.detailNote, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(b.customerNote!, style: const TextStyle(color: AppColors.textMain)),
          ]),
        ],
        if (b.cancellation != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BadgeTone.red.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              OwnerStrings.cancelledInfo(
                b.cancellation!.cancelledAt == null ? '—' : Formatters.dateTime(b.cancellation!.cancelledAt!),
                b.cancellation!.reason ?? '—',
                b.cancellation!.refundAmount,
                b.cancellation!.penaltyAmount,
              ),
              style: TextStyle(color: BadgeTone.red.foreground, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _title(OwnerStrings.playersTitle(lfg != null, b.participants.length)),
        _card([
          for (final p in b.participants)
            _person(
              name: p.fullName,
              suffix: p.isHost ? OwnerStrings.hostSuffix : null,
              phone: p.phone,
              trailing: [
                Text(Formatters.vnd(p.amountContributed), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (p.paymentStatus.isNotEmpty) BookingStatusBadge(p.paymentStatus),
                p.isCheckedIn
                    ? const OwnerBadge(OwnerStrings.inCourt, tone: BadgeTone.green)
                    : const OwnerBadge(OwnerStrings.notInCourt, tone: BadgeTone.gray),
              ],
            ),
        ]),
        if (lfg != null) ...[
          const SizedBox(height: 16),
          _title(OwnerStrings.lfgTitle(lfg.acceptedCount, lfg.checkedInCount)),
          Text(
            '${lfg.isCancelled ? OwnerStrings.lfgCancelled(lfg.cancelReason) : OwnerStrings.lfgSummary(lfg.totalSlots, lfg.remainingSlots, lfg.pricePerPerson)}'
            ' • ${OwnerStrings.lfgExpected(lfg.acceptedCount)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _card([
            if (lfg.participants.isEmpty)
              const Text(OwnerStrings.lfgEmpty, style: TextStyle(color: AppColors.textSecondary))
            else
              for (final p in lfg.participants)
                Opacity(
                  opacity: p.isAccepted ? 1 : 0.6,
                  child: _person(
                    name: p.fullName,
                    phone: p.phone,
                    trailing: [
                      Text(
                        OwnerStrings.lfgPlayerStatus[p.status] ?? (p.status.isEmpty ? '—' : p.status),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(Formatters.vnd(p.amountPaid), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (p.isAccepted)
                        p.isCheckedIn
                            ? const OwnerBadge(OwnerStrings.inCourt, tone: BadgeTone.green)
                            : const OwnerBadge(OwnerStrings.notInCourt, tone: BadgeTone.gray),
                    ],
                  ),
                ),
          ]),
        ],
      ],
    );
  }

  Widget? _actions(OwnerBooking b) {
    final now = DateTime.now();
    final buttons = <Widget>[
      if (widget.onOpenSchedule != null)
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context, _changed);
            widget.onOpenSchedule!();
          },
          child: const Text(OwnerStrings.viewSchedule),
        ),
      if (b.canCancel)
        ElevatedButton(
          onPressed: _cancel,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text(OwnerStrings.cancelBooking),
        ),
      if (b.canEndEarly(now))
        ElevatedButton(
          onPressed: _ending ? null : _endEarly,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: Text(_ending ? OwnerStrings.endingEarly : OwnerStrings.endEarly),
        ),
    ];
    if (buttons.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: buttons,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
      );

  Widget _info(String label, String value, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain)),
                  if (sub != null) Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _person({required String name, String? suffix, String? phone, required List<Widget> trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: name,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain),
                children: [
                  if (suffix != null)
                    TextSpan(text: suffix, style: const TextStyle(fontWeight: FontWeight.normal, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (phone != null) Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: trailing),
          ],
        ),
      );
}
