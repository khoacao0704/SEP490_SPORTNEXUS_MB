import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_drawer.dart';
import '../../widgets/review/pending_review_banner.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _selectedFilterTab = 0; // 0: Tất cả, 1: Đặt Sân, 2: Kèo LFG

  List<Map<String, dynamic>> _bookings = [];

  // Default Mock Bookings
  final List<Map<String, dynamic>> _defaultBookings = [
    {
      'id': 'SPN-BK-849201',
      'type': 'Booking', // Booking or LFG
      'sport': 'Cầu Lông',
      'courtName': 'Sân Eco Quận 7',
      'location': 'Quận 7 • P. Tân Thuận Đông',
      'dateTime': '19:30 - 20:30 (Hôm nay)',
      'price': '140.000 đ',
      'paymentStatus': 'Đã thanh toán 100%',
      'qrCode': 'SPN-BK-849201-KHOA',
      'createdDate': '12/10/2026',
    },
    {
      'id': 'SPN-LFG-938210',
      'type': 'LFG',
      'sport': 'Bóng Đá Sân 7',
      'courtName': 'Sân Vận Động Thống Nhất',
      'location': 'Quận 10 • P. 14',
      'dateTime': '20:00 - 21:30 (Hôm nay)',
      'price': '250.000 đ',
      'paymentStatus': 'Flash Claim (1 Slot)',
      'qrCode': 'SPN-LFG-938210-GUEST',
      'createdDate': '12/10/2026',
    },
    {
      'id': 'SPN-LFG-551029',
      'type': 'LFG',
      'sport': 'Pickleball Đôi',
      'courtName': 'Sân Pickleball Kỳ Hòa',
      'location': 'Quận 10 • P. 12',
      'dateTime': '18:00 - 19:30 (Ngày mai)',
      'price': '40.000 đ',
      'paymentStatus': 'Host Đã Cọc 1/4',
      'qrCode': 'SPN-LFG-551029-HOST',
      'createdDate': '11/10/2026',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedList = prefs.getStringList('my_bookings_data');

    List<Map<String, dynamic>> loadedList = List.from(_defaultBookings);

    if (savedList != null && savedList.isNotEmpty) {
      for (var str in savedList) {
        try {
          loadedList.insert(0, jsonDecode(str) as Map<String, dynamic>);
        } catch (_) {}
      }
    }

    setState(() {
      _bookings = loadedList;
    });
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_selectedFilterTab == 1) {
      return _bookings.where((b) => b['type'] == 'Booking').toList();
    } else if (_selectedFilterTab == 2) {
      return _bookings.where((b) => b['type'] == 'LFG').toList();
    }
    return _bookings;
  }

  void _showQrTicketModal(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, color: AppColors.primaryGreen, size: 24),
                const SizedBox(width: 8),
                Text(
                  'VÉ QR CHECK-IN CÁ NHÂN',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Large QR Code Representation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryGreen, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: AppColors.textMain),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking['qrCode'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Match Info Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking['courtName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                  const SizedBox(height: 2),
                  Text('Môn: ${booking['sport']} • ${booking['location']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: AppColors.tagOrangeText),
                      const SizedBox(width: 4),
                      Text(booking['dateTime'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Scanner Notice
            const Text(
              '📌 Mỗi người chơi có 1 mã QR duy nhất. Vui lòng xuất trình mã này cho Chủ sân quét khi Check-in / Check-out.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D5238),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Đóng Vé', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    String str = amount.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredBookings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textMain),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          }
        ),
        title: const Text('Lịch Đặt Sân & Mã QR', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      drawer: const MainDrawer(selectedIndex: 3),
      body: Column(
        children: [
          // Filter Tabs (Tất cả, Đặt Sân, Kèo LFG)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterTab(0, 'Tất cả (${_bookings.length})'),
                const SizedBox(width: 8),
                _buildFilterTab(1, 'Sân đã đặt'),
                const SizedBox(width: 8),
                _buildFilterTab(2, 'Kèo LFG'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const PendingReviewBanner(),

          // Bookings List
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Chưa có lịch đặt sân nào', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
                        const SizedBox(height: 4),
                        const Text('Hãy đặt sân hoặc tham gia LFG để nhận vé QR nhé!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildBookingCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final bool isSelected = _selectedFilterTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilterTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D5238) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? const Color(0xFF1D5238) : AppColors.cardBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textMain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final bool isLfg = booking['type'] == 'LFG';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Badge & Status)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLfg ? const Color(0xFFFFF3E0) : AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(isLfg ? Icons.groups : Icons.sports_tennis, size: 14, color: isLfg ? const Color(0xFFEF6C00) : AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      isLfg ? 'KÈO LFG' : 'SÂN ĐÃ ĐẶT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLfg ? const Color(0xFFEF6C00) : AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                booking['paymentStatus'] as String,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.divider),

          // Court Name & Sport
          Text(booking['courtName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
          const SizedBox(height: 4),
          Text('Môn: ${booking['sport']} • ${booking['location']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.tagOrangeText),
              const SizedBox(width: 4),
              Text(booking['dateTime'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
            ],
          ),
          const SizedBox(height: 16),

          // Action Button: Open QR Code Ticket
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TỔNG TIỀN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Text(
                    booking['price'] as String,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showQrTicketModal(booking),
                icon: const Icon(Icons.qr_code_2, size: 18, color: Colors.white),
                label: const Text('MỞ VÉ QR CHECK-IN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D5238),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
