import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/app_repositories.dart';
import '../../core/constants/booking_rules.dart';
import '../../core/constants/split_payment_rules.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/split_payment_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/booking.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';
import '../main/main_navigation_screen.dart';
import '../wallet/vietqr_payment_screen.dart';
import 'split_payment_screen.dart';

class BookingCheckoutScreen extends StatefulWidget {
  final String sport;
  final String courtName;
  final String location;
  final String dateTime;
  final int totalAmount;
  final int initialSecondsRemaining;

  /// Chỗ đang giữ; có thì cho phép chia tiền nhóm (giữ tiếp khung giờ 30 phút).
  final SlotHold? hold;

  const BookingCheckoutScreen({
    this.hold,
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

  int _paymentTypeIndex = 0; // 0: Full Payment (100%), 1: Partial Deposit (1/4), 2: Chia tiền nhóm
  int _splitParts = SplitPaymentRules.allowedParts.last;

  int get _payAmount {
    switch (_paymentTypeIndex) {
      case 0:
        return widget.totalAmount;
      case 1:
        // Mỗi khung giờ là một lượt đặt riêng nên cọc 1/4 tính theo từng khung.
        final hold = widget.hold;
        return hold == null
            ? BookingRules.depositAmount(widget.totalAmount)
            : BookingRules.depositFor(hold.slots.map((s) => s.price));
      default:
        return SplitPaymentRules.bookerAmount(widget.totalAmount, _splitParts);
    }
  }

  String get _payLabel => switch (_paymentTypeIndex) {
    0 => 'Thanh toán 100% tiền sân',
    1 => 'Ký quỹ 1 phần (1/4) tiền sân',
    _ => SplitPaymentStrings.payNow(_splitParts),
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
  }

  Future<void> _loadWalletBalance() async {
    final balance = await AppRepositories.paymentWallet.getBalance();
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
    if (_paymentTypeIndex == 2) return _startSplit();
    final hold = widget.hold;
    if (hold == null) return;
    final payAmount = _payAmount;

    if (_selectedPaymentMethod == 0 && _walletBalance < payAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số dư ví không đủ! Vui lòng nạp thêm tiền hoặc chọn phương thức VietQR.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final List<Booking> bookings;
    try {
      if (_selectedPaymentMethod == 1 && !await _payByVietQr(payAmount)) return;
      bookings = await AppRepositories.booking.createBooking(
        hold: hold,
        paymentType: _paymentTypeIndex == 0 ? BookingPaymentType.full : BookingPaymentType.deposit,
        facilityName: widget.courtName,
        sportLabel: widget.sport,
        location: widget.location,
        schedule: widget.dateTime,
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
    setState(() => _isLoading = false);

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
              'Đã thanh toán ${_formatCurrency(payAmount)} đ cho ${widget.courtName}. Vé QR Cá nhân đã sẵn sàng.',
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
                    QrImageView(data: bookings.single.ticketCode, size: 140, backgroundColor: Colors.white),
                    const SizedBox(height: 4),
                    Text(
                      'MÃ CHECK-IN: ${bookings.single.ticketCode}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
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

  /// Chia tiền nhóm: trả phần của mình (ví hoặc VietQR), giữ tiếp khung giờ 30 phút rồi sang màn chia tiền.
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

  /// Chuyển khoản đúng số tiền vào ví qua VietQR (BE xác nhận) để trừ ví ở bước sau.
  /// Trả về false nếu người dùng thoát / hết hạn (đã tắt trạng thái đang xử lý).
  Future<bool> _payByVietQr(int amount) async {
    final order = await AppRepositories.paymentWallet.createTopUp(amount);
    if (!mounted) return false;
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VietQrPaymentScreen(order: order, wallet: AppRepositories.paymentWallet)),
    );
    if (paid == true) return true;
    if (mounted) setState(() => _isLoading = false);
    _loadWalletBalance();
    return false;
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
                  _buildSummaryRow(
                    Icons.payments_outlined,
                    'Tổng tiền sân gốc',
                    '${_formatCurrency(widget.totalAmount)} đ',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Select Payment Type (Full vs Deposit)
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
                                  '${_formatCurrency(widget.totalAmount)} đ',
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentTypeIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _paymentTypeIndex == 1 ? const Color(0xFFE8F5E9) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _paymentTypeIndex == 1 ? AppColors.primaryGreen : AppColors.cardBorder,
                                width: _paymentTypeIndex == 1 ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Ký quỹ (1/4 tiền sân)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatCurrency((widget.totalAmount / 4).round())} đ',
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
                  if (widget.hold != null) ...[const SizedBox(height: 10), _buildSplitOption()],
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
                                  'Ví Escrow SportNexus',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                Text(
                                  'Số dư: ${_formatCurrency(_walletBalance)} ₫',
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TỔNG THANH TOÁN KỲ NÀY',
                        style: TextStyle(
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
                  Text(
                    '${_formatCurrency(payAmount)} đ',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Button 1: Green Confirm & Get QR Ticket
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleConfirmPayment,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    'Xác nhận thanh toán & lấy vé QR (${_formatCurrency(payAmount)} đ)',
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

  Widget _buildSplitOption() {
    final selected = _paymentTypeIndex == 2;
    return GestureDetector(
      onTap: () => setState(() => _paymentTypeIndex = 2),
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
                    '${_formatCurrency(_payAmount)} đ',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(SplitPaymentStrings.optionHint, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            if (selected) ...[
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

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
        ),
      ],
    );
  }
}
