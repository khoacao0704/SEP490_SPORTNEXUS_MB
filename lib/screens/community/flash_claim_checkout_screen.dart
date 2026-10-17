import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/wallet_transaction.dart';
import '../../theme/app_colors.dart';

class FlashClaimCheckoutScreen extends StatefulWidget {
  final String sportName;
  final String hostName;
  final String courtName;
  final String location;
  final String time;
  final int slotPrice;

  const FlashClaimCheckoutScreen({
    super.key,
    required this.sportName,
    required this.hostName,
    required this.courtName,
    required this.location,
    required this.time,
    required this.slotPrice,
  });

  @override
  State<FlashClaimCheckoutScreen> createState() => _FlashClaimCheckoutScreenState();
}

class _FlashClaimCheckoutScreenState extends State<FlashClaimCheckoutScreen> {
  int _selectedPaymentMethod = 0; // 0: Wallet, 1: VietQR
  int _walletBalance = 500000;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final balance = await AppRepositories.paymentWallet.getBalance();
    if (!mounted) return;
    setState(() => _walletBalance = balance);
  }

  String _formatCurrency(int amount) {
    String str = amount.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> _handleConfirmClaim() async {
    if (_selectedPaymentMethod == 0 && _walletBalance < widget.slotPrice) {
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

    await Future.delayed(const Duration(seconds: 1)); // Simulate payment

    if (_selectedPaymentMethod == 0) {
      try {
        await AppRepositories.paymentWallet.pay(
          amount: widget.slotPrice,
          type: TransactionType.flashClaim,
          description: 'Tham gia kèo ${widget.sportName} • ${widget.courtName}',
        );
      } on WalletException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
        return;
      }
    }

    // Save Flash Claim Booking Data for MyBookingsScreen
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('my_bookings_data') ?? [];
    Map<String, dynamic> newBooking = {
      'id': 'SPN-FC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'type': 'LFG',
      'sport': widget.sportName,
      'courtName': widget.courtName,
      'location': widget.location,
      'dateTime': widget.time,
      'price': '${_formatCurrency(widget.slotPrice)} đ',
      'paymentStatus': 'Flash Claim (1 Slot)',
      'qrCode': 'SPN-FC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-GUEST',
      'createdDate': '12/10/2026',
    };
    list.add(jsonEncode(newBooking));
    await prefs.setStringList('my_bookings_data', list);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Show Success Dialog with Personal QR Check-in Ticket
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
              child: const Icon(Icons.flash_on, color: AppColors.primaryGreen, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Flash Claim Thành Công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã giành slot thành công kèo ${widget.sportName} của Host ${widget.hostName}. Vé QR Cá nhân đã được khởi tạo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Mock Personal QR Ticket Box
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
                    'MÃ CHECK-IN CÁ NHÂN: GUEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
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
                  Navigator.pop(context); // Go back to Community Feed
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Hoàn Tất', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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
          'Thanh Toán Flash Claim Slot',
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Flash Claim Speed Notice Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.flash_on, color: AppColors.primaryGreen, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cơ chế Flash Claim: First-Come, First-Served',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Slot thuộc về người hoàn tất thanh toán trước. Host không có quyền duyệt.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Match Details Card
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
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryGreen,
                        child: Text(
                          widget.hostName.isNotEmpty ? widget.hostName[0].toUpperCase() : 'H',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.hostName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                          const Text('Host Kèo • Fair Play Score: 100', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.sportName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.divider),
                  _buildSummaryRow(Icons.sports_tennis, 'Môn & Loại kèo', widget.sportName),
                  const SizedBox(height: 10),
                  _buildSummaryRow(Icons.location_on_outlined, 'Sân & Địa chỉ', '${widget.courtName} • ${widget.location}'),
                  const SizedBox(height: 10),
                  _buildSummaryRow(Icons.access_time, 'Thời gian đá/đánh', widget.time),
                  const Divider(height: 24, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GIÁ 1 SLOT VÃNG LAI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text(
                        '${_formatCurrency(widget.slotPrice)} đ',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
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
                    'PHƯƠNG THỨC THANH TOÁN',
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TỔNG THANH TOÁN SLOT LFG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'First-Come, First-Served',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_formatCurrency(widget.slotPrice)} đ',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Button 1: Confirm & Claim
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleConfirmClaim,
                  icon: const Icon(Icons.flash_on, size: 20),
                  label: Text(
                    'Xác nhận thanh toán & nhận vé QR (${_formatCurrency(widget.slotPrice)} đ)',
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
                    'Quay lại / Hủy claim',
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
