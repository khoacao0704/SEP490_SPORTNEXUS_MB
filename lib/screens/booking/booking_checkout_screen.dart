import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_repositories.dart';
import '../../core/constants/voucher_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants/booking_rules.dart';
import '../../core/constants/split_payment_rules.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/split_payment_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/booking.dart';
import '../../models/recurring_plan.dart';
import '../../models/time_slot.dart';
import '../../models/voucher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking/booking_ticket_qr.dart';
import '../../widgets/booking/invite_by_phone.dart';
import '../../widgets/booking/recurring_booking_section.dart';
import '../main/main_navigation_screen.dart';
import '../wallet/vietqr_payment_screen.dart';
import 'split_booking_screen.dart';
import 'split_payment_screen.dart';

class BookingCheckoutScreen extends StatefulWidget {
  final String sport;
  final String courtName;
  final String location;
  final String dateTime;
  final int totalAmount;
  final int initialSecondsRemaining;

  /// Chỗ đang giữ; có thì cho phép chia Điểm nhóm (giữ tiếp khung giờ 30 phút).
  final SlotHold? hold;

  /// Đặt gói cố định hằng tuần: [hold] gồm khung giờ mọi buổi, [totalAmount] là giá gốc (chưa giảm).
  /// Gói chỉ thanh toán 100%, không chia Điểm nhóm.
  final RecurringCheckout? recurring;

  /// % giảm gói của cơ sở: dùng khi đặt thường mà các ca tình cờ thành gói (BE tự coi là gói và tự giảm).
  final int packageDiscountPercent;

  const BookingCheckoutScreen({
    this.hold,
    this.recurring,
    this.packageDiscountPercent = 0,
    super.key,
    required this.sport,
    required this.courtName,
    required this.location,
    required this.dateTime,
    required this.totalAmount,
    this.initialSecondsRemaining = 568, // Default ~9 mins 28 secs
  });

  @override
  State<BookingCheckoutScreen> createState() => _BookingCheckoutScreenState();
}

class _BookingCheckoutScreenState extends State<BookingCheckoutScreen> {
  late int _secondsRemaining;
  Timer? _timer;

  int _paymentTypeIndex = 0; // 0: Thanh toán 100%, 2: Chia Điểm nhóm (đặt sân thường không có cọc)
  int _splitParts = SplitPaymentRules.allowedParts.last;

  /// Chia Điểm theo cách mời bạn (BE thật) thay cho chia mã/link.
  bool get _splitByInvite => AppRepositories.booking.supportsSplitInvite;

  /// Những người được mời góp (luồng mời bạn).
  final List<PlayerLookup> _invitees = [];

  /// Số người chia Điểm mỗi ca (gồm người đặt).
  int get _people => _invitees.length + 1;

  /// Phần người đặt trả ngay khi mời bạn: cộng phần của mình ở từng ca (mỗi ca là một đơn).
  int get _inviteHostAmount {
    final prices = widget.hold?.slots.map((s) => s.price) ?? [widget.totalAmount];
    return prices.fold(0, (sum, p) => sum + SplitPaymentRules.hostShare(p, _people));
  }

  /// Phần mỗi người được mời góp (tổng các ca).
  int get _inviteeAmount {
    final prices = widget.hold?.slots.map((s) => s.price) ?? [widget.totalAmount];
    return prices.fold(0, (sum, p) => sum + SplitPaymentRules.inviteeShare(p, _people));
  }

  /// Lý do lịch lặp lại không thành gói (app tự kiểm theo luật BE vì BE chưa có API xem trước). Rỗng = hợp lệ.
  List<String> get _recurringProblems => widget.recurring?.problems ?? const [];

  /// Gói sai luật: không hiện giảm giá, khóa thanh toán (BE sẽ từ chối).
  bool get _recurringBlocked => _recurringProblems.isNotEmpty;

  /// Đặt thường (không bật lặp lại) nhưng các ca tình cờ thành gói đúng luật BE (≥4 buổi sau khi gộp ca liền nhau,
  /// cùng sân con, cùng độ dài, cách đúng 7 ngày): BE tự coi là gói → tự giảm %, không cho chia tiền.
  late final bool _autoPackage = widget.recurring == null &&
      widget.hold != null &&
      RecurringPlan.packageError(widget.hold!.slots) == null;

  /// Đơn là gói (chủ động bật lặp lại hoặc tình cờ thành gói): khóa chia tiền, chữ bill / nút riêng.
  bool get _isPackage => widget.recurring != null || _autoPackage;

  int get _discountPercent =>
      widget.recurring?.discountPercent ?? (_autoPackage ? widget.packageDiscountPercent : 0);

  /// Gói hợp lệ và cơ sở có giảm: hiện giá gốc gạch ngang + giá mới.
  bool get _discountApplied => _isPackage && _discountPercent > 0 && !_recurringBlocked;

  /// Tổng sau giảm của gói (tạm tính; giá thật do BE tính khi đặt). Đặt lẻ hoặc gói sai luật: giá gốc.
  int get _fullAmount => !_isPackage || _recurringBlocked
      ? widget.totalAmount
      : RecurringBookingRules.discounted(widget.totalAmount, _discountPercent);

  // ---------- Voucher (thẻ 43): 1 mã / đơn, chỉ đơn thường thành đúng 1 đơn, trả 100% ----------

  /// Mã còn dùng của người chơi (`null` khi đang tải / tải lỗi).
  List<Voucher>? _vouchers;
  Voucher? _voucher;

  /// Lý do không dùng được voucher cho đơn này (`null` = dùng được).
  String? get _voucherBlockReason {
    if (_isPackage) return BookingStrings.voucherNotForPackage;
    if (!VoucherRules.formsSingleBooking(widget.hold?.slots ?? const [])) return BookingStrings.voucherSingleOnly;
    if (_paymentTypeIndex == 2) return BookingStrings.voucherNotForSplit;
    return null;
  }

  /// Số Điểm voucher giảm (tính trên giá sau giảm gói, như BE).
  int get _voucherDiscount =>
      _voucher == null || _voucherBlockReason != null ? 0 : VoucherRules.discount(_fullAmount, _voucher!.discountPercent);

  Future<void> _loadVouchers() async {
    try {
      final now = DateTime.now();
      final list = (await AppRepositories.voucher.getMyVouchers(status: VoucherStatus.active))
          .where((v) => v.expiresAt.isAfter(now))
          .toList()
        ..sort((a, b) => b.discountPercent != a.discountPercent
            ? b.discountPercent.compareTo(a.discountPercent)
            : a.expiresAt.compareTo(b.expiresAt));
      if (!mounted) return;
      setState(() {
        _vouchers = list;
        if (_voucher != null && !list.any((v) => v.id == _voucher!.id)) _voucher = null;
      });
    } catch (_) {
      if (mounted) setState(() => _vouchers = const []);
    }
  }

  Future<void> _pickVoucher() async {
    final reason = _voucherBlockReason;
    if (reason != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    final vouchers = _vouchers ?? const [];
    if (vouchers.isEmpty) return;
    // Hàm trả `null` khi đóng sheet; chọn "Không dùng mã" trả chuỗi rỗng.
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  BookingStrings.voucherSheetTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ),
              for (final v in vouchers)
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined, color: AppColors.primaryGreen),
                  title: Text(BookingStrings.voucherChosen(v.discountPercent),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${BookingStrings.voucherExpires('${Formatters.dayMonth(v.expiresAt)}/${v.expiresAt.year}')} • '
                    '-${Formatters.vnd(VoucherRules.discount(_fullAmount, v.discountPercent))}',
                  ),
                  trailing: Icon(
                    v.id == _voucher?.id ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: AppColors.primaryGreen,
                  ),
                  onTap: () => Navigator.pop(sheet, v.id),
                ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.textSecondary),
                title: const Text(BookingStrings.voucherDontUse),
                trailing: Icon(
                  _voucher == null ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: AppColors.primaryGreen,
                ),
                onTap: () => Navigator.pop(sheet, ''),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _voucher = vouchers.where((v) => v.id == picked).firstOrNull);
  }

  int get _payAmount {
    switch (_paymentTypeIndex) {
      case 0:
        return _fullAmount - _voucherDiscount;
      default:
        return _splitByInvite ? _inviteHostAmount : SplitPaymentRules.bookerAmount(widget.totalAmount, _splitParts);
    }
  }

  String get _payLabel => switch (_paymentTypeIndex) {
    0 when widget.recurring != null => BookingStrings.packageTitle(widget.recurring!.sessions),
    0 when _autoPackage => BookingStrings.packageLabel,
    0 => 'Thanh toán 100% giá sân',
    _ => _splitByInvite ? SplitPaymentStrings.invitePay : SplitPaymentStrings.payNow(_splitParts),
  };
  int _selectedPaymentMethod = 0; // 0: SportNexus Wallet, 1: VietQR

  int _walletBalance = 500000;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSecondsRemaining;
    _startTimer();
    _loadWalletBalance();
    if (widget.hold != null) _loadVouchers();
  }

  Future<void> _loadWalletBalance() async {
    final balance = await AppRepositories.bookingWallet.getBalance();
    if (!mounted) return;
    setState(() => _walletBalance = balance);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _showExpiredDialog();
      }
    });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Hết thời gian giữ chỗ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Đã hết thời gian giữ chỗ tạm thời. Khung giờ đặt đã tự động giải phóng.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to CourtBookingScreen
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int amount) {
    String str = amount.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> _handleConfirmPayment() async {
    if (_paymentTypeIndex == 2) return _splitByInvite ? _startInviteSplit() : _startSplit();
    final hold = widget.hold;
    if (hold == null) return;
    // Kiểm lại ngay trước khi trừ Điểm (nút đã khóa, đây là chặn thêm).
    if (_recurringBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BookingStrings.recurringInvalid(_recurringProblems)), backgroundColor: Colors.red),
      );
      return;
    }
    final payAmount = _payAmount;

    if (_selectedPaymentMethod == 0 && _walletBalance < payAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không đủ Điểm! Vui lòng nạp thêm Điểm hoặc chọn phương thức VietQR.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final recurring = widget.recurring;
    // Lặp lại nhiều thứ / nhiều cụm giờ: BE chỉ nhận mỗi gói một thứ → đặt lần lượt từng gói.
    final packages = recurring == null ? [hold.slots] : recurring.packages;
    final bookings = <Booking>[];
    var donePackages = 0;
    try {
      if (_selectedPaymentMethod == 1 && !await _payByVietQr(payAmount)) return;
      for (final slots in packages) {
        bookings.addAll(await AppRepositories.booking.createBooking(
          hold: SlotHold(holdId: hold.holdId, slots: slots, expiresAt: hold.expiresAt),
          paymentType: BookingPaymentType.full,
          facilityName: widget.courtName,
          sportLabel: widget.sport,
          location: widget.location,
          schedule: widget.dateTime,
          recurring: recurring != null,
          discountPercent: _discountPercent,
          voucher: _voucherDiscount > 0 ? _voucher : null,
        ));
        donePackages++;
      }
    } on BookingException catch (e) {
      // Voucher bị BE từ chối (hết hạn / đã dùng…): bỏ mã đang chọn, tải lại danh sách để chọn mã khác.
      if (_voucher != null) {
        setState(() => _voucher = null);
        _loadVouchers();
      }
      donePackages == 0 ? _fail(e.message) : _partialFail(donePackages, packages.length, e.message);
      return;
    } on WalletException catch (e) {
      donePackages == 0 ? _fail(e.message) : _partialFail(donePackages, packages.length, e.message);
      return;
    }
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _isLoading = false);
    // Số tiền thật BE đã trừ (gói: giá đã giảm của từng buổi).
    final paidTotal = bookings.isEmpty ? payAmount : bookings.fold(0, (sum, b) => sum + b.amountPaid);

    // Success Dialog & QR Code Ticket
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đặt sân thành công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              _isPackage
                  ? BookingStrings.packagesBooked(bookings.length, packages.length, paidTotal)
                  : 'Đã thanh toán ${_formatCurrency(paidTotal)} Điểm cho ${widget.courtName}. Vé QR Cá nhân đã sẵn sàng.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            if (bookings.length == 1)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    BookingTicketQr(booking: bookings.single, size: 140),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Đóng luồng đặt sân, mở tab "Lịch Đặt & QR" để xem vé và hủy nếu cần.
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Xem Lịch Đặt & QR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Chia Điểm nhóm: trả phần của mình (ví hoặc VietQR), giữ tiếp khung giờ 30 phút rồi sang màn chia Điểm.
  Future<void> _startSplit() async {
    final hold = widget.hold!;
    final amount = _payAmount;
    if (_selectedPaymentMethod == 0 && _walletBalance < amount) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(SplitPaymentStrings.insufficient), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_selectedPaymentMethod == 1 && !await _payByVietQr(amount)) return;
      final split = await AppRepositories.split.create(
        hold: hold,
        parts: _splitParts,
        facilityName: widget.courtName,
        sportLabel: widget.sport,
        location: widget.location,
        schedule: widget.dateTime,
      );
      if (!mounted) return;
      _timer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SplitPaymentStrings.createdMessage), backgroundColor: AppColors.primaryGreen),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SplitPaymentScreen(splitId: split.id, initial: split),
        ),
      );
    } on SplitPaymentException catch (e) {
      _fail(e.message);
    } on WalletException catch (e) {
      _fail(e.message);
    }
  }

  /// Chia Điểm theo cách mời bạn: trả phần của mình (ví hoặc VietQR), mỗi ca một đơn chờ bạn bè góp.
  Future<void> _startInviteSplit() async {
    final hold = widget.hold!;
    if (_invitees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SplitPaymentStrings.inviteRequired), backgroundColor: Colors.red),
      );
      return;
    }
    final amount = _payAmount;
    if (_selectedPaymentMethod == 0 && _walletBalance < amount) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(SplitPaymentStrings.insufficient), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final List<Booking> bookings;
    try {
      if (_selectedPaymentMethod == 1 && !await _payByVietQr(amount)) return;
      bookings = await AppRepositories.booking.createSplitBooking(
        hold: hold,
        inviteeIds: _invitees.map((p) => p.id).toList(),
        facilityName: widget.courtName,
        sportLabel: widget.sport,
        location: widget.location,
      );
    } on BookingException catch (e) {
      _fail(e.message);
      return;
    } on WalletException catch (e) {
      _fail(e.message);
      return;
    }
    if (!mounted) return;
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(SplitPaymentStrings.invitedMessage), backgroundColor: AppColors.primaryGreen),
    );
    // Một ca: mở màn chia Điểm của đơn đó; nhiều ca: mỗi ca một đơn trong Lịch Đặt.
    if (bookings.length == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SplitBookingScreen(bookingId: bookings.single.id)),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
        (route) => false,
      );
    }
  }

  /// Chuyển khoản đúng số tiền vào Ví điểm qua VietQR (BE xác nhận) để trừ ví ở bước sau.
  /// Trả về false nếu người dùng thoát / hết hạn (đã tắt trạng thái đang xử lý).
  Future<bool> _payByVietQr(int amount) async {
    final order = await AppRepositories.bookingWallet.createTopUp(amount);
    if (!mounted) return false;
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VietQrPaymentScreen(order: order, wallet: AppRepositories.bookingWallet)),
    );
    if (paid == true) return true;
    if (mounted) setState(() => _isLoading = false);
    _loadWalletBalance();
    return false;
  }

  /// Chia Điểm BE chưa hỗ trợ thì báo "đang phát triển", giữ lựa chọn hiện tại.
  void _selectPaymentType(int index) {
    final booking = AppRepositories.booking;
    final unavailable = switch (index) {
      2 when !booking.supportsSplitPayment && !booking.supportsSplitInvite => BookingStrings.splitUnavailable,
      _ => null,
    };
    if (unavailable != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(unavailable)));
      return;
    }
    // Chuyển sang chia tiền: BE không nhận voucher cho đơn chia tiền → bỏ mã đang chọn.
    final dropVoucher = index == 2 && _voucher != null;
    setState(() {
      _paymentTypeIndex = index;
      if (dropVoucher) _voucher = null;
    });
    if (dropVoucher) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(BookingStrings.voucherRemovedForSplit)));
    }
  }

  /// Lặp lại nhiều gói: một số gói đã đặt (đã trừ Điểm) rồi gói sau lỗi → báo rõ, đưa người dùng tới Lịch Đặt.
  void _partialFail(int done, int total, String message) {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _isLoading = false);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(BookingStrings.recurringPartialTitle),
        content: Text(BookingStrings.recurringPartialFail(done, total, message)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              dialogContext,
              MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
              (route) => false,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Xem Lịch Đặt & QR'),
          ),
        ],
      ),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    _loadWalletBalance();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    int payAmount = _payAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thanh Toán Đặt Sân',
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Timer Banner matching screenshot
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giữ chỗ tạm thời cho bạn',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Khung giờ sẽ tự động giải phóng sau ${_formatTimer(_secondsRemaining)} phút.',
                          style: const TextStyle(color: Color(0xFFB45309), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTimer(_secondsRemaining),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Booking Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.courtName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              'Môn: ${widget.sport} • ${widget.location}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.divider),
                  _buildSummaryRow(Icons.calendar_today_outlined, 'Ngày & Khung giờ', widget.dateTime),
                  const SizedBox(height: 10),
                  if (widget.recurring case final r?) ...[
                    _buildSummaryRow(Icons.event_repeat, BookingStrings.packageLabel, BookingStrings.packageSummary(r.sessions, r.summary)),
                    const SizedBox(height: 10),
                  ],
                  // Gói được giảm: gạch giá gốc, giá mới màu đỏ kèm "Đã áp dụng giảm X%".
                  _buildSummaryRow(
                    Icons.payments_outlined,
                    'Tổng giá sân gốc',
                    '${_formatCurrency(widget.totalAmount)} Điểm',
                    valueStyle: _discountApplied
                        ? const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  if (_discountApplied) ...[
                    const SizedBox(height: 10),
                    _buildSummaryRow(
                      Icons.local_offer_outlined,
                      BookingStrings.discountRow(_discountPercent),
                      '${_formatCurrency(_fullAmount)} Điểm',
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                      valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                      iconColor: Colors.red,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        BookingStrings.monthlyPackageNote(_discountPercent),
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700, height: 1.4),
                      ),
                    ),
                  ],
                  if (_autoPackage) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${BookingStrings.autoPackageNote(_discountPercent)} ${BookingStrings.recurringCancelRule} '
                      '${BookingStrings.recurringNoSplit} ${BookingStrings.estimatedNote}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                  if (widget.recurring case final r?) ...[
                    if (_recurringBlocked) ...[
                      const SizedBox(height: 12),
                      _buildRecurringWarning(),
                    ],
                    if (r.days.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildRecurringDays(r),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      '${BookingStrings.recurringCancelRule} ${BookingStrings.recurringNoSplit} ${BookingStrings.estimatedNote}',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                  // Đơn lẻ (không phải gói): luật hoàn khi hủy theo bậc thời gian.
                  if (widget.hold != null && !_isPackage) ...[
                    const SizedBox(height: 10),
                    const Text(
                      BookingStrings.cancelPolicy,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                  if (widget.hold != null) ...[
                    const Divider(height: 24, color: AppColors.divider),
                    _buildVoucherSection(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Select Payment Type (100% / chia Điểm nhóm)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHỌN HÌNH THỨC THANH TOÁN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentTypeIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _paymentTypeIndex == 0 ? const Color(0xFFE8F5E9) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _paymentTypeIndex == 0 ? AppColors.primaryGreen : AppColors.cardBorder,
                                width: _paymentTypeIndex == 0 ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Thanh toán 100%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatCurrency(_fullAmount - _voucherDiscount)} Điểm',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.hold != null) ...[
                    const SizedBox(height: 10),
                    _buildSplitOption(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Select Payment Method
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PHƯƠNG THỨC THANH TOÁN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: SportNexus Escrow Wallet
                  GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 0 ? const Color(0xFFE8F5E9).withValues(alpha: 0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 0 ? AppColors.primaryGreen : AppColors.cardBorder,
                          width: _selectedPaymentMethod == 0 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          RadioGroup<int>(
                            groupValue: _selectedPaymentMethod,
                            onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
                            child: Radio<int>(value: 0, activeColor: AppColors.primaryGreen),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: AppColors.primaryGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Đổi Điểm',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                Text(
                                  'Ví điểm • Số dư: ${_formatCurrency(_walletBalance)} Điểm',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option 2: VietQR
                  GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 1),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 1 ? const Color(0xFFE8F5E9).withValues(alpha: 0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 1 ? AppColors.primaryGreen : AppColors.cardBorder,
                          width: _selectedPaymentMethod == 1 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          RadioGroup<int>(
                            groupValue: _selectedPaymentMethod,
                            onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
                            child: Radio<int>(value: 1, activeColor: AppColors.primaryGreen),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2E7D32), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quét mã VietQR / Napas 24/7',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                Text(
                                  'Tự động xác nhận giao dịch',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120), // Spacing for bottom bar
          ],
        ),
      ),

      // Bottom Bar matching screenshot exactly
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Row matching screenshot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nhãn dài (vd. chia Điểm) xuống dòng thay vì đẩy số tiền ra ngoài màn hình hẹp.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPackage ? BookingStrings.packagePrepayTitle : 'TỔNG THANH TOÁN KỲ NÀY',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _payLabel,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Số tiền lớn tự thu nhỏ trên máy hẹp / chữ to.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_formatCurrency(payAmount)} Điểm',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Button 1: Green Confirm & Get QR Ticket
              // Cao tối thiểu 48, chữ dài / chữ to thì nút cao thêm (2 dòng) thay vì tràn.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _recurringBlocked ? null : _handleConfirmPayment,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isPackage
                        ? BookingStrings.payNowPackage(payAmount)
                        : 'Xác nhận thanh toán & lấy vé QR (${_formatCurrency(payAmount)} Điểm)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D5238),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Button 2: Red Cancel / Back Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626), // Solid red matching image
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Quay lại chọn giờ khác / hủy đặt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gói: nút chia tiền làm mờ, bấm vào chỉ giải thích (BE trả 400 nếu gói gửi chia tiền).
  Widget _buildLockedSplitOption() => GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text(BookingStrings.splitNotForPackage)));
        },
        child: Opacity(
          opacity: 0.5,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.groups_outlined, size: 20, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    SplitPaymentStrings.option,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );

  Widget _buildSplitOption() {
    if (_isPackage) return _buildLockedSplitOption();
    final selected = _paymentTypeIndex == 2;
    return GestureDetector(
      onTap: () => _selectPaymentType(2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_outlined, size: 20, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    SplitPaymentStrings.option,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMain),
                  ),
                ),
                if (selected)
                  Text(
                    '${_formatCurrency(_payAmount)} Điểm',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _splitByInvite ? SplitPaymentStrings.inviteHint : SplitPaymentStrings.optionHint,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (selected && _splitByInvite) ..._buildInviteSection(),
            if (selected && !_splitByInvite) ...[
              const SizedBox(height: 10),
              const Text(
                SplitPaymentStrings.partsTitle,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final parts in SplitPaymentRules.allowedParts)
                    ChoiceChip(
                      label: Text(SplitPaymentStrings.partsLabel(parts)),
                      selected: parts == _splitParts,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _splitParts = parts),
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: AppColors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: parts == _splitParts ? Colors.white : AppColors.textMain,
                      ),
                      side: BorderSide(color: parts == _splitParts ? AppColors.primaryGreen : AppColors.cardBorder),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                SplitPaymentStrings.explain(
                  _splitParts,
                  _payAmount,
                  SplitPaymentRules.shareAmount(widget.totalAmount, _splitParts),
                ),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInviteSection() => [
        const SizedBox(height: 10),
        InviteByPhoneField(
          excludeIds: _invitees.map((p) => p.id).toSet(),
          onFound: (player) => setState(() => _invitees.add(player)),
        ),
        for (final p in _invitees)
          InviteeTile(
            name: p.fullName,
            subtitle: p.phoneMasked,
            onRemove: () => setState(() => _invitees.remove(p)),
          ),
        if (_invitees.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            SplitPaymentStrings.inviteExplain(_people, _inviteeAmount, _inviteHostAmount),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          SplitPaymentStrings.inviteByLinkSoon,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        ),
      ];

  /// Nút "Chọn Voucher" (mờ kèm lý do khi đơn không dùng được) + công thức Tổng tiền → Voucher giảm N% → Thực tế cần thanh toán.
  Widget _buildVoucherSection() {
    final blocked = _voucherBlockReason;
    final vouchers = _vouchers;
    final none = vouchers != null && vouchers.isEmpty;
    final voucher = blocked == null ? _voucher : null;
    final label = voucher != null
        ? BookingStrings.voucherChosen(voucher.discountPercent)
        : none && blocked == null
            ? BookingStrings.voucherNone
            : BookingStrings.voucherPick;
    final enabled = blocked == null && !none && vouchers != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: enabled || voucher != null ? 1 : 0.5,
          child: Material(
            color: voucher != null ? AppColors.lightGreen : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: voucher != null ? AppColors.primaryGreen : AppColors.cardBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              // Mờ vẫn bấm được để báo lý do; chưa có mã thì không làm gì.
              onTap: none && blocked == null ? null : _pickVoucher,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined,
                        size: 20, color: enabled || voucher != null ? AppColors.primaryGreen : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(blocked != null ? Icons.lock_outline : Icons.chevron_right,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (voucher != null) ...[
          const SizedBox(height: 10),
          _buildSummaryRow(Icons.receipt_outlined, BookingStrings.formulaTotal, '${_formatCurrency(_fullAmount)} Điểm'),
          const SizedBox(height: 6),
          _buildSummaryRow(
            Icons.remove_circle_outline,
            BookingStrings.formulaDiscount(voucher.discountPercent),
            '-${_formatCurrency(_voucherDiscount)} Điểm',
            valueStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            Icons.payments_outlined,
            BookingStrings.formulaPay,
            '${_formatCurrency(_fullAmount - _voucherDiscount)} Điểm',
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
            valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
          ),
        ],
      ],
    );
  }

  /// Cảnh báo đỏ: lịch không thành gói → không giảm giá, không cho thanh toán.
  Widget _buildRecurringWarning() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    BookingStrings.recurringInvalidTitle,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    BookingStrings.recurringInvalid(_recurringProblems),
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// Từng ngày của gói: ✔ đặt được, ❌ bị kẹt / thuộc gói sai luật.
  Widget _buildRecurringDays(RecurringCheckout r) {
    final bad = r.badSlotIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          BookingStrings.recurringDaysTitle,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        const SizedBox(height: 4),
        for (final d in r.days)
          RecurringDayRow(
            session: d,
            invalidReason: d.slots.any((s) => bad.contains(s.id)) ? BookingStrings.recurringWeekInvalid : null,
          ),
      ],
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    Color iconColor = AppColors.textSecondary,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: labelStyle ?? const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
        ),
      ],
    );
  }
}
