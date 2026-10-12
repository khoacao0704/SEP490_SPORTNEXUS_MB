import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';

class TopUpWalletScreen extends StatefulWidget {
  const TopUpWalletScreen({super.key});

  @override
  State<TopUpWalletScreen> createState() => _TopUpWalletScreenState();
}

class _TopUpWalletScreenState extends State<TopUpWalletScreen> {
  int _selectedAmount = 100000;
  int _selectedPaymentMethod = 2; // 0: VietQR, 1: MoMo, 2: VNPAY
  bool _isLoading = false;

  final TextEditingController _amountController = TextEditingController(text: '100.000');

  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 0,
      'title': 'Tài khoản Ngân hàng (VietQR / Napas 24/7)',
      'subtitle': '• Miễn phí nạp, tức thì trong 30 giây',
      'icon': Icons.account_balance,
      'color': Color(0xFFE8F5E9),
      'iconColor': Color(0xFF2E7D32),
      'tag': null,
    },
    {
      'id': 1,
      'title': 'Ví điện tử MoMo',
      'subtitle': 'Liên kết ví MoMo hoặc quét mã QR',
      'icon': Icons.account_balance_wallet,
      'color': Color(0xFFFCE4EC),
      'iconColor': Color(0xFFC2185B),
      'tag': 'Tự động',
    },
    {
      'id': 2,
      'title': 'Cổng thanh toán VNPAY',
      'subtitle': 'Hỗ trợ thẻ ATM nội địa & hơn 40 ngân hàng',
      'icon': Icons.credit_card,
      'color': Color(0xFFE3F2FD),
      'iconColor': Color(0xFF1565C0),
      'tag': 'Nội địa',
    },
  ];

  String _formatCurrency(int amount) {
    String str = amount.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  void _updateAmount(int amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = _formatCurrency(amount);
    });
  }

  Future<void> _handleConfirmTopUp() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1)); // Simulate payment processing

    // Update balance in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    int currentBalance = prefs.getInt('wallet_balance') ?? 500000;
    int newBalance = currentBalance + _selectedAmount;
    await prefs.setInt('wallet_balance', newBalance);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Show Success Dialog
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
              child: const Icon(Icons.check, color: AppColors.primaryGreen, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nạp tiền thành công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã cộng ${_formatCurrency(_selectedAmount)} đ vào ví SportNexus của bạn.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to profile/previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Hoàn tất', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String paymentName = _selectedPaymentMethod == 0
        ? 'VietQR / Napas'
        : _selectedPaymentMethod == 1
            ? 'MoMo'
            : 'VNPAY';

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
          'Nạp Tiền Vào Ví Escrow',
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Green Banner: Fee Free & Safe Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phí giao dịch: Miễn phí',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Bảo vệ giao dịch bởi SportNexus Pay Safe',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 1: Amount Selection
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
                    'SỐ TIỀN MUỐN NẠP (VND)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount TextField
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.payments_outlined, color: AppColors.primaryGreen, size: 28),
                      ),
                      suffixText: 'đ',
                      suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedAmount = 0;
                            _amountController.clear();
                          });
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                      ),
                    ),
                    onChanged: (value) {
                      String raw = value.replaceAll('.', '').replaceAll(',', '').replaceAll('đ', '').trim();
                      int? parsed = int.tryParse(raw);
                      if (parsed != null) {
                        setState(() {
                          _selectedAmount = parsed;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quick Amount Chips
                  const Text(
                    'CHỌN NHANH ĐỊNH MỨC:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _quickAmounts.map((amt) {
                      final bool isSelected = _selectedAmount == amt;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _updateAmount(amt),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryGreen : const Color(0xFFCBD5E1),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+${_formatCurrency(amt)} đ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.primaryGreen : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Payment Methods
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
                    'PHƯƠNG THỨC NẠP TIỀN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._paymentMethods.map((method) {
                    final bool isSelected = _selectedPaymentMethod == method['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPaymentMethod = method['id'] as int;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE8F5E9).withOpacity(0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryGreen : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: method['id'] as int,
                              groupValue: _selectedPaymentMethod,
                              activeColor: AppColors.primaryGreen,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedPaymentMethod = val;
                                  });
                                }
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: method['color'] as Color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                method['icon'] as IconData,
                                color: method['iconColor'] as Color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          method['title'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      if (method['tag'] != null) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            method['tag'] as String,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    method['subtitle'] as String,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Summary Details
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chi tiết nạp ví',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Tức thì',
                          style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Số tiền nạp', '${_formatCurrency(_selectedAmount)} đ'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Nguồn tiền', paymentName),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Phí dịch vụ', 'Miễn phí', valueColor: const Color(0xFF16A34A)),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TỔNG THANH TOÁN',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          Text(
                            'Tiền thực trừ',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      Text(
                        '${_formatCurrency(_selectedAmount)} đ',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleConfirmTopUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D5238),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Xác nhận nạp tiền vào ví (${_formatCurrency(_selectedAmount)} đ)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Back Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF1E293B),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
