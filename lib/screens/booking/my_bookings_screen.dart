import 'package:flutter/material.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/booking.dart';
import '../../models/split_payment.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking/booking_ticket_qr.dart';
import '../../widgets/main_drawer.dart';
import '../../widgets/review/pending_review_banner.dart';
import '../lfg/lfg_screen.dart';
import 'split_booking_screen.dart';
import 'split_payment_screen.dart';

/// Tab "Lịch Đặt & QR": sân đã đặt (vé QR, hủy đặt) và kèo LFG của tôi (rời / yêu cầu hủy trong chi tiết kèo).
class MyBookingsScreen extends StatefulWidget {
  final int initialTab;

  const MyBookingsScreen({super.key, this.initialTab = 0});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() => _revision++);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const MainDrawer(selectedIndex: 3),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          BookingStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: BookingStrings.tabBookings), Tab(text: BookingStrings.tabLfg)],
        ),
      ),
      body: Column(
        children: [
          const PendingReviewBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _BookingsView(revision: _revision),
                MyLfgMatchesView(revision: _revision, onChanged: () => setState(() => _revision++)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsView extends StatefulWidget {
  final int revision;

  const _BookingsView({required this.revision});

  @override
  State<_BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<_BookingsView> {
  List<Booking> _bookings = [];
  List<SplitPayment> _pendingSplits = [];
  String? _myId;
  bool _isLoading = true;
  String? _error;
  String? _cancellingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_BookingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bookings = await AppRepositories.booking.getMyBookings();
      // BE thật chia tiền theo đơn (thẻ "Chờ góp tiền" bên dưới), không dùng lượt chia theo mã.
      final splits = AppRepositories.booking.supportsSplitInvite ? <SplitPayment>[] : await AppRepositories.split.getMine();
      final user = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _bookings = bookings;
        _pendingSplits = splits.where((s) => s.status(now) == SplitStatus.pending).toList();
        _myId = user?.id;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = BookingStrings.loadError;
      });
    }
  }

  Future<void> _cancel(Booking b) async {
    final now = DateTime.now();
    final refund = b.refundIfCancelled(now);
    final free = b.refundsInFull(now);
    final message = (free ? BookingStrings.confirmCancelFree(refund) : BookingStrings.confirmCancelLate(b.cancelFee(now))) +
        (b.paymentType != BookingPaymentType.split
            ? ''
            : free
                ? BookingStrings.splitCancelFreeNote
                : BookingStrings.splitCancelLateNote);
    // Không tải được danh sách lý do thì vẫn cho hủy (BE dùng lý do mặc định).
    var reasons = const <CancelReason>[];
    try {
      reasons = await AppRepositories.booking.getCancelReasons();
    } catch (_) {
      // bỏ qua: hủy không cần lý do
    }
    if (!mounted) return;
    CancelReason? picked;
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text(BookingStrings.confirmCancelTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(BookingStrings.cancelReasonTitle, style: TextStyle(fontWeight: FontWeight.bold)),
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
                      decoration: const InputDecoration(hintText: BookingStrings.cancelReasonHint, isDense: true),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(BookingStrings.keep)),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text(BookingStrings.cancel),
            ),
          ],
        ),
      ),
    );
    final note = noteController.text;
    noteController.dispose();
    if (ok != true || !mounted) return;

    setState(() => _cancellingId = b.id);
    try {
      final reason = picked;
      final cancelled = await AppRepositories.booking.cancelBooking(
        b.id,
        reasonCode: reason == null || reason.isCustom ? null : reason.code,
        reason: reason == null ? null : (reason.isCustom ? note : reason.label),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(BookingStrings.cancelledMessage(cancelled.refunded))),
        );
      }
    } on BookingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
    _load();
  }

  void _showTicket(Booking b) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(BookingStrings.ticketTitle, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookingTicketQr(booking: b),
            const SizedBox(height: 8),
            Text('${b.facilityName}\n${b.sportCourtLabel}\n${b.schedule}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
              BookingStrings.ticketNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(BookingStrings.close)),
        ],
      ),
    );
  }

  Future<void> _openSplitBooking(Booking b) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SplitBookingScreen(bookingId: b.id)));
    _load();
  }

  Future<void> _openSplit(SplitPayment s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SplitPaymentScreen(splitId: s.id, initial: s)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _bookings.isEmpty && _pendingSplits.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(BookingStrings.retry)),
          ],
        ),
      );
    }
    final now = DateTime.now();
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_pendingSplits.isNotEmpty) ...[
            const Text(
              BookingStrings.pendingSplitsTitle,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            for (final s in _pendingSplits)
              Card(
                elevation: 0,
                color: AppColors.tagOrangeBg,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.tagOrangeText),
                ),
                child: ListTile(
                  onTap: () => _openSplit(s),
                  leading: const Icon(Icons.call_split, color: AppColors.tagOrangeText),
                  title: Text(
                    BookingStrings.pendingSplit(s.paidCount, s.parts, s.facilityName),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(s.schedule, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            const SizedBox(height: 8),
          ],
          if (_bookings.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.calendar_today, size: 60, color: AppColors.cardBorder),
                  SizedBox(height: 12),
                  Text(BookingStrings.empty, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                  SizedBox(height: 4),
                  Text(BookingStrings.emptyHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            for (final b in _bookings) _buildCard(b, now),
        ],
      ),
    );
  }

  Widget _buildCard(Booking b, DateTime now) {
    final status = b.status(now);
    final isBooker = b.bookerId == _myId;
    final awaiting = b.awaitingPayment && status == BookingStatus.upcoming;
    final (label, bg, fg) = awaiting
        ? (SplitPaymentStrings.awaiting, AppColors.tagOrangeBg, AppColors.tagOrangeText)
        : switch (status) {
            BookingStatus.upcoming => (BookingStrings.statusUpcoming, AppColors.tagGreenBg, AppColors.tagGreenText),
            BookingStatus.cancelled => (BookingStrings.statusCancelled, const Color(0xFFFFEBEE), const Color(0xFFC62828)),
            BookingStatus.completed => (BookingStrings.statusCompleted, AppColors.divider, AppColors.textSecondary),
          };
    final deadline = '${Formatters.time(b.freeCancelDeadline)} ${Formatters.weekdayDayMonth(b.freeCancelDeadline)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.sportCourtLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(b.facilityName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          Text(b.location, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            b.schedule,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
          ),
          const Divider(height: 20, color: AppColors.divider),
          _row(BookingStrings.total, Formatters.vnd(b.totalPrice)),
          _row(BookingStrings.paid, '${Formatters.vnd(b.amountPaid)} • ${b.paymentType.label}'),
          if (status == BookingStatus.cancelled && b.refunded > 0)
            _row('', BookingStrings.refunded(b.refunded), color: AppColors.primaryGreen),
          if (awaiting && b.myShare > 0)
            _row('', SplitPaymentStrings.yourShare(b.myShare), color: AppColors.tagOrangeText),
          if (!isBooker) _row('', BookingStrings.contributor, color: AppColors.textSecondary),
          if (status == BookingStatus.upcoming) ...[
            const SizedBox(height: 8),
            // Đơn chờ góp hủy lúc nào cũng hoàn đủ nên không hiện mốc 24 giờ.
            if (isBooker && !awaiting)
              Text(
                b.isFreeCancel(now) ? BookingStrings.freeCancelUntil(deadline) : BookingStrings.lateCancelNote,
                style: TextStyle(fontSize: 12, color: b.isFreeCancel(now) ? AppColors.textSecondary : Colors.red),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (b.canCancel(now, _myId ?? '')) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancellingId == null ? () => _cancel(b) : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _cancellingId == b.id
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text(BookingStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    // Đơn chia tiền chưa đủ thì chưa có vé: mở màn chia tiền (góp / theo dõi).
                    onPressed: () => awaiting ? _openSplitBooking(b) : _showTicket(b),
                    icon: Icon(awaiting ? Icons.groups_outlined : Icons.qr_code_2, size: 18),
                    label: Text(awaiting ? SplitPaymentStrings.openSplit : BookingStrings.ticket),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textMain),
              ),
            ),
          ],
        ),
      );
}
