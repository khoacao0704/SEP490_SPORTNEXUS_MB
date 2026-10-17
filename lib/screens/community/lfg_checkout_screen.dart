import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/wallet_transaction.dart';
import '../../theme/app_colors.dart';

class LfgCheckoutScreen extends StatefulWidget {
  final String sport;
  final String format;
  final String courtName;
  final String location;
  final String dateTime;
  final int totalCourtPrice;
  final int hostDepositAmount;
  final double depositRatio;
  final int initialSecondsRemaining;

  const LfgCheckoutScreen({
    super.key,
    required this.sport,
    required this.format,
    required this.courtName,
    required this.location,
    required this.dateTime,
    required this.totalCourtPrice,
    required this.hostDepositAmount,
    required this.depositRatio,
    this.initialSecondsRemaining = 568,
  });

  @override
  State<LfgCheckoutScreen> createState() => _LfgCheckoutScreenState();
}

class _LfgCheckoutScreenState extends State<LfgCheckoutScreen> {
  late int _secondsRemaining;
  Timer? _timer;

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
          'Đã hết thời gian giữ chỗ tạm thời cho kèo LFG. Khung giờ đặt đã tự động giải phóng.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to CreateLfgScreen
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

  Future<void> _handleConfirmLfgDeposit() async {
    if (_selectedPaymentMethod == 0 && _walletBalance < widget.hostDepositAmount) {
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

    await Future.delayed(const Duration(seconds: 1));

    if (_selectedPaymentMethod == 0) {
      try {
        await AppRepositories.paymentWallet.pay(
          amount: widget.hostDepositAmount,
          type: TransactionType.lfgDeposit,
          description: 'Cọc tạo kèo ${widget.sport} • ${widget.courtName}',
        );
      } on WalletException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
        return;
      }
    }

    // Save LFG Booking Data for MyBookingsScreen
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('my_bookings_data') ?? [];
    Map<String, dynamic> newBooking = {
      'id': 'SPN-LFG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'type': 'LFG',
      'sport': widget.sport,
      'courtName': widget.courtName,
      'location': widget.location,
      'dateTime': widget.dateTime,
      'price': '${_formatCurrency(widget.hostDepositAmount)} đ',
      'paymentStatus': 'Host Đã Cọc ${(widget.depositRatio * 100).toInt()}%',
      'qrCode': 'SPN-LFG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-HOST',
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
              'Đăng Kèo LFG Thành Công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã cọc thành công ${_formatCurrency(widget.hostDepositAmount)} đ cho kèo ${widget.format}. Kèo đã xuất hiện trên Bảng Tin LFG.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Mock QR Code Box for Host
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 90, color: AppColors.textMain),
                  const SizedBox(height: 4),
                  Text(
                    'MÃ CHECK-IN HOST: LFG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to CreateLfgScreen
                  Navigator.pop(context); // Back to Community Feed
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Xem Bảng Tin LFG', style: TextStyle(fontWeight: FontWeight.bold)),
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
          'Thanh Toán Cọc Kèo LFG',
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Timer Banner
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

            // 2. LFG Summary Details
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
                        child: const Icon(Icons.groups, color: AppColors.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.format,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                            ),
                            Text(
                              '${widget.courtName} • ${widget.location}',
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
                  _buildSummaryRow(Icons.payments_outlined, 'Tổng tiền thuê sân gốc', '${_formatCurrency(widget.totalCourtPrice)} đ'),
                  const SizedBox(height: 10),
                  _buildSummaryRow(Icons.pie_chart_outline, 'Tỷ lệ cọc Host', '${(widget.depositRatio * 100).toInt()}% tiền sân'),
                  const Divider(height: 24, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SỐ TIỀN CỌC HOST CẦN TRẢ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text(
                        '${_formatCurrency(widget.hostDepositAmount)} đ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Payment Method Selection
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
                    'PHƯƠNG THỨC THANH TOÁN CỌC',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),

                  // Wallet Option
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

                  // VietQR Option
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
            const SizedBox(height: 120),
          ],
        ),
      ),

      // Bottom Bar
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
                        'Host cọc ${(widget.depositRatio * 100).toInt()}% tiền sân để đăng LFG',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_formatCurrency(widget.hostDepositAmount)} đ',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Button 1: Green Confirm & Create LFG
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleConfirmLfgDeposit,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    'Xác nhận cọc & Đăng LFG (${_formatCurrency(widget.hostDepositAmount)} đ)',
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

              // Button 2: Red Cancel Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Quay lại chọn giờ khác / hủy',
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
