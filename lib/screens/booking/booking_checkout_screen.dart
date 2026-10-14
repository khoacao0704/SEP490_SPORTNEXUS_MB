import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';

class BookingCheckoutScreen extends StatefulWidget {
  final String sport;
  final String courtName;
  final String location;
  final String dateTime;
  final int totalAmount;
  final int initialSecondsRemaining;

  const BookingCheckoutScreen({
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

  int _paymentTypeIndex = 0; // 0: Full Payment (100%), 1: Partial Deposit (1/4)
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _walletBalance = prefs.getInt('wallet_balance') ?? 500000;
    });
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
    int payAmount = _paymentTypeIndex == 0 ? widget.totalAmount : (widget.totalAmount / 4).round();

    if (_selectedPaymentMethod == 0 && _walletBalance < payAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số dư ví không đủ! Vui lòng nạp thêm tiền hoặc chọn phương thức VietQR.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1)); // Process payment

    if (_selectedPaymentMethod == 0) {
      final prefs = await SharedPreferences.getInstance();
      int newBalance = _walletBalance - payAmount;
      await prefs.setInt('wallet_balance', newBalance);
    }

    // Save Booking Data for MyBookingsScreen
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('my_bookings_data') ?? [];
    Map<String, dynamic> newBooking = {
      'id': 'SPN-BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'type': 'Booking',
      'sport': widget.sport,
      'courtName': widget.courtName,
      'location': widget.location,
      'dateTime': widget.dateTime,
      'price': '${_formatCurrency(payAmount)} đ',
      'paymentStatus': _paymentTypeIndex == 0 ? 'Đã thanh toán 100%' : 'Đã cọc 1/4',
      'qrCode': 'SPN-BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-KHOA',
      'createdDate': '12/10/2026',
    };
    list.add(jsonEncode(newBooking));
    await prefs.setStringList('my_bookings_data', list);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

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
              decoration: const BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
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

            // Mock QR Code Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 100, color: AppColors.textMain),
                  const SizedBox(height: 4),
                  Text(
                    'MÃ CHECK-IN: SPN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
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
                  // Close dialog + checkout + booking flow screens, back to Home
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Về Trang Chủ', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    int payAmount = _paymentTypeIndex == 0 ? widget.totalAmount : (widget.totalAmount / 4).round();

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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
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
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.courtName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
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
                  _buildSummaryRow(Icons.payments_outlined, 'Tổng tiền sân gốc', '${_formatCurrency(widget.totalAmount)} đ'),
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
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
                                const Text('Thanh toán 100%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMain)),
                                const SizedBox(height: 4),
                                Text('${_formatCurrency(widget.totalAmount)} đ', style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
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
                                const Text('Ký quỹ (1/4 tiền sân)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMain)),
                                const SizedBox(height: 4),
                                Text('${_formatCurrency((widget.totalAmount / 4).round())} đ', style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: SportNexus Escrow Wallet
                  GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 0 ? const Color(0xFFE8F5E9).withOpacity(0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 0 ? AppColors.primaryGreen : AppColors.cardBorder,
                          width: _selectedPaymentMethod == 0 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: 0,
                            groupValue: _selectedPaymentMethod,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
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
                                const Text('Ví Escrow SportNexus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                                Text('Số dư: ${_formatCurrency(_walletBalance)} ₫', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
                        color: _selectedPaymentMethod == 1 ? const Color(0xFFE8F5E9).withOpacity(0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 1 ? AppColors.primaryGreen : AppColors.cardBorder,
                          width: _selectedPaymentMethod == 1 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: 1,
                            groupValue: _selectedPaymentMethod,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
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
                                Text('Quét mã VietQR / Napas 24/7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                                Text('Tự động xác nhận giao dịch', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
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
                        _paymentTypeIndex == 0 ? 'Thanh toán 100% tiền sân' : 'Ký quỹ 1 phần (1/4) tiền sân',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_formatCurrency(payAmount)} đ',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
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
