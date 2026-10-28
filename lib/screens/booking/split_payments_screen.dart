import 'package:flutter/material.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/split_payment_repository.dart';
import '../../models/booking.dart';
import '../../models/split_payment.dart';
import '../../theme/app_colors.dart';
import 'split_booking_screen.dart';
import 'split_payment_screen.dart';

/// "Chia Tiền Sân": nhập mã từ link bạn bè gửi, và xem các lượt chia của mình.
/// BE thật ([BookingRepository.supportsSplitInvite]): chia tiền bằng cách mời theo SĐT, không có mã →
/// chỉ liệt kê các đơn chia tiền (mình đặt hoặc được mời góp), mở màn chia tiền của đơn đó.
class SplitPaymentsScreen extends StatefulWidget {
  const SplitPaymentsScreen({super.key});

  @override
  State<SplitPaymentsScreen> createState() => _SplitPaymentsScreenState();
}

class _SplitPaymentsScreenState extends State<SplitPaymentsScreen> {
  final _code = TextEditingController();
  List<SplitPayment> _items = [];
  List<Booking> _splitBookings = [];
  bool _isLoading = true;
  bool _isOpening = false;

  bool get _byInvite => AppRepositories.booking.supportsSplitInvite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (_byInvite) {
        final bookings = await AppRepositories.booking.getMyBookings();
        if (mounted) setState(() => _splitBookings = bookings.where((b) => b.paymentType == BookingPaymentType.split).toList());
        return;
      }
      final items = await AppRepositories.split.getMine();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // Danh sách không tải được vẫn cho nhập mã.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isOpening = true);
    try {
      final split = await AppRepositories.split.findByCode(code);
      if (!mounted) return;
      _code.clear();
      await _open(split);
    } on SplitPaymentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  Future<void> _open(SplitPayment split) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SplitPaymentScreen(splitId: split.id, initial: split)),
    );
    _load();
  }

  Future<void> _openBooking(Booking booking) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SplitBookingScreen(bookingId: booking.id)));
    _load();
  }

  /// Nhãn trạng thái giống thẻ ở Lịch đặt.
  static (String, Color) _bookingStatus(Booking b, DateTime now) {
    final status = b.status(now);
    if (b.awaitingPayment && status == BookingStatus.upcoming) return (SplitPaymentStrings.awaiting, AppColors.tagOrangeText);
    return switch (status) {
      BookingStatus.upcoming => (BookingStrings.statusUpcoming, AppColors.tagGreenText),
      BookingStatus.cancelled => (BookingStrings.statusCancelled, const Color(0xFFC62828)),
      BookingStatus.completed => (BookingStrings.statusCompleted, AppColors.textSecondary),
    };
  }

  Widget _buildInviteList(DateTime now) {
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            SplitPaymentStrings.mine,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_splitBookings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(SplitPaymentStrings.empty, style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            for (final b in _splitBookings) _bookingTile(b, now),
        ],
      ),
    );
  }

  Widget _bookingTile(Booking b, DateTime now) {
    final (label, color) = _bookingStatus(b, now);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: ListTile(
        onTap: () => _openBooking(b),
        title: Text(b.facilityName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(b.schedule),
        trailing: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          SplitPaymentStrings.listTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: _byInvite ? _buildInviteList(now) : RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              SplitPaymentStrings.enterCode,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _openCode(),
                    decoration: InputDecoration(
                      hintText: SplitPaymentStrings.codeHint,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isOpening ? null : _openCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(SplitPaymentStrings.open),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              SplitPaymentStrings.mine,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(SplitPaymentStrings.empty, style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              for (final s in _items)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: ListTile(
                    onTap: () => _open(s),
                    title: Text(s.facilityName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${s.schedule}\n${splitStatusLabel(s.status(now))}'),
                    isThreeLine: true,
                    trailing: Text(
                      SplitPaymentStrings.progress(s.paidCount, s.parts),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: splitStatusColors(s.status(now)).fg),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
