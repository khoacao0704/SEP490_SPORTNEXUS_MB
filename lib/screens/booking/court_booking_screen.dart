import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CourtBookingScreen extends StatefulWidget {
  const CourtBookingScreen({super.key});

  @override
  State<CourtBookingScreen> createState() => _CourtBookingScreenState();
}

class _CourtBookingScreenState extends State<CourtBookingScreen> {
  // Step State Variables (null = Not Selected)
  String? _selectedSport;
  String? _selectedCity;
  String? _selectedWard;
  Map<String, dynamic>? _selectedCourtObj;
  int? _selectedDateIndex;
  int? _selectedSlotIndex;

  final List<Map<String, dynamic>> _sports = [
    {'id': 'Badminton', 'name': 'Cầu Lông', 'icon': Icons.sports_tennis},
    {'id': 'Pickleball', 'name': 'Pickleball', 'icon': Icons.sports_kabaddi},
    {'id': 'Football', 'name': 'Bóng Đá', 'icon': Icons.sports_soccer},
    {'id': 'Basketball', 'name': 'Bóng Rổ', 'icon': Icons.sports_basketball},
    {'id': 'Tennis', 'name': 'Tennis', 'icon': Icons.sports_baseball},
  ];

  // Vietnam Provinces
  final List<String> _vietnamProvinces = [
    'Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Hải Phòng', 'Cần Thơ',
    'Bình Dương', 'Đồng Nai', 'Bà Rịa - Vũng Tàu', 'An Giang', 'Bắc Ninh'
  ];

  // Wards / Districts for Hồ Chí Minh
  final Map<String, List<String>> _cityWards = {
    'Hồ Chí Minh': [
      'Quận 1 • P. Bến Nghé',
      'Quận 3 • P. Võ Thị Sáu',
      'Quận 7 • P. Tân Thuận Đông',
      'Quận 7 • P. Tân Phong',
      'Q. Bình Thạnh • P. 25',
      'Q. Gò Vấp • P. 5',
      'TP. Thủ Đức • P. Linh Trung',
    ],
    'Hà Nội': [
      'Q. Hoàn Kiếm • P. Hàng Bạc',
      'Q. Cầu Giấy • P. Dịch Vọng',
      'Q. Đống Đa • P. Láng Hạ',
      'Q. Hai Bà Trưng • P. Bách Khoa',
    ],
    'Đà Nẵng': [
      'Q. Hải Châu • P. Hòa Cường Bắc',
      'Q. Thanh Khê • P. Vĩnh Trung',
      'Q. Sơn Trà • P. An Hải Bắc',
    ],
  };

  // Courts Data with Distance
  final List<Map<String, dynamic>> _courtsWithDistance = [
    {
      'name': 'Sân Thiên Triều',
      'subtitle': 'Thảm PVC tiêu chuẩn BWF',
      'distance': '1.086m',
      'icon': Icons.location_on_outlined,
    },
    {
      'name': 'Sân Eco Quận 7',
      'subtitle': 'Trong nhà - Đèn chống chói',
      'distance': '2.3 km',
      'icon': Icons.location_on_outlined,
    },
    {
      'name': 'Sân Chu Văn An',
      'subtitle': 'Sân VIP có điều hòa',
      'distance': '3.1 km',
      'icon': Icons.location_on_outlined,
    },
    {
      'name': 'Sân Kỳ Hòa',
      'subtitle': 'Khung cảnh thoáng mát',
      'distance': '4.5 km',
      'icon': Icons.location_on_outlined,
    },
  ];

  final List<DateTime> _dates = List.generate(7, (index) => DateTime.now().add(Duration(days: index)));

  final List<Map<String, dynamic>> _timeSlots = [
    {
      'time': '16:00 - 17:00',
      'isLocked': true,
      'statusText': 'Đã kín lịch',
      'price': 0,
    },
    {
      'time': '17:00 - 18:00',
      'isLocked': true,
      'statusText': 'FC Sài Gòn Đặt',
      'price': 0,
    },
    {
      'time': '18:00 - 19:00',
      'isLocked': false,
      'statusText': 'Trống',
      'price': 140000,
    },
    {
      'time': '19:00 - 19:30',
      'isLocked': false,
      'statusText': 'Trống',
      'price': 70000,
    },
    {
      'time': '19:30 - 20:30',
      'isLocked': false,
      'statusText': 'Trống',
      'price': 140000,
    },
    {
      'time': '20:30 - 21:30',
      'isLocked': false,
      'statusText': 'Trống',
      'price': 120000,
    },
  ];

  // 10-Minute Reservation Timer
  Timer? _reservationTimer;
  int _secondsRemaining = 600;

  void _startTimer() {
    _reservationTimer?.cancel();
    setState(() {
      _secondsRemaining = 600;
    });

    _reservationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _selectedSlotIndex = null;
        });
        _showExpiredDialog();
      }
    });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
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
          'Đã hết 10 phút giữ chỗ tạm thời. Vui lòng chọn lại khung giờ bạn muốn đặt.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
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

  void _showStepWarning(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF1D5238),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn Tỉnh / Thành phố', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _vietnamProvinces.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final city = _vietnamProvinces[index];
                    return ListTile(
                      title: Text(city),
                      trailing: _selectedCity == city ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                      onTap: () {
                        setState(() {
                          _selectedCity = city;
                          _selectedWard = null;
                          _selectedCourtObj = null;
                          _selectedDateIndex = null;
                          _selectedSlotIndex = null;
                          _reservationTimer?.cancel();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWardPicker() {
    final wards = _cityWards[_selectedCity] ?? ['Phường 1', 'Phường 2', 'Phường 3'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chọn Quận / Phường (${_selectedCity!})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: wards.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ward = wards[index];
                    return ListTile(
                      title: Text(ward),
                      trailing: _selectedWard == ward ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                      onTap: () {
                        setState(() {
                          _selectedWard = ward;
                          _selectedCourtObj = null;
                          _selectedDateIndex = null;
                          _selectedSlotIndex = null;
                          _reservationTimer?.cancel();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _reservationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSelectLocation = _selectedSport != null;
    final bool canSelectCourt = _selectedSport != null && _selectedCity != null && _selectedWard != null;
    final bool canSelectDate = canSelectCourt && _selectedCourtObj != null;
    final bool canSelectSlot = canSelectDate && _selectedDateIndex != null;

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
          'Đặt Sân Thể Thao',
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Choose Sport
            _buildSportsBar(),
            const SizedBox(height: 16),

            // 2. Choose Location (City & Ward)
            GestureDetector(
              onTap: canSelectLocation
                  ? null
                  : () => _showStepWarning('Vui lòng chọn Môn thể thao trước!'),
              child: Opacity(
                opacity: canSelectLocation ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !canSelectLocation,
                  child: _buildLocationSelectionRow(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Choose Court (Shows Distance)
            GestureDetector(
              onTap: canSelectCourt
                  ? null
                  : () => _showStepWarning('Vui lòng chọn Tỉnh/Thành và Phường trước!'),
              child: Opacity(
                opacity: canSelectCourt ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !canSelectCourt,
                  child: _buildCourtSelectionCard(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Choose Date
            GestureDetector(
              onTap: canSelectDate
                  ? null
                  : () => _showStepWarning('Vui lòng chọn Sân trước!'),
              child: Opacity(
                opacity: canSelectDate ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !canSelectDate,
                  child: _buildDatePickerBar(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Choose Time Slot
            GestureDetector(
              onTap: canSelectSlot
                  ? null
                  : () => _showStepWarning('Vui lòng chọn Ngày trước!'),
              child: Opacity(
                opacity: canSelectSlot ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !canSelectSlot,
                  child: _buildTimeSlotsGrid(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Reservation Timer Banner
            if (_selectedSlotIndex != null) _buildTimerBanner(),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // Bottom Confirm Bar
      bottomSheet: _selectedSlotIndex != null ? _buildBottomConfirmBar() : null,
    );
  }

  Widget _buildSportsBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sport = _sports[index];
          final bool isSelected = _selectedSport == sport['id'];

          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              sport['icon'] as IconData,
              size: 18,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
            ),
            label: Text(
              sport['name'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primaryGreen,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder,
              ),
            ),
            onSelected: (selected) {
              setState(() {
                _selectedSport = sport['id'] as String;
                _selectedCity = null;
                _selectedWard = null;
                _selectedCourtObj = null;
                _selectedDateIndex = null;
                _selectedSlotIndex = null;
                _reservationTimer?.cancel();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildLocationSelectionRow() {
    return Row(
      children: [
        // City Selector
        Expanded(
          child: GestureDetector(
            onTap: _showCityPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city, size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedCity ?? 'Thành phố/Tỉnh',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _selectedCity != null ? AppColors.textMain : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Ward Selector
        Expanded(
          child: GestureDetector(
            onTap: _selectedCity == null
                ? () => _showStepWarning('Vui lòng chọn Tỉnh/Thành phố trước!')
                : _showWardPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedWard ?? 'Quận / Phường',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _selectedWard != null ? AppColors.textMain : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourtSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Danh sách sân gần bạn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          ..._courtsWithDistance.map((court) {
            final bool isSelected = _selectedCourtObj?['name'] == court['name'];

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCourtObj = court;
                  _selectedDateIndex = null;
                  _selectedSlotIndex = null;
                  _reservationTimer?.cancel();
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryGreen : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports_tennis_outlined, color: AppColors.primaryGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            court['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain),
                          ),
                          Text(
                            court['subtitle'] as String,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'cách ${court['distance']}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
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
    );
  }

  Widget _buildDatePickerBar() {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = _dates[index];
          final bool isSelected = _selectedDateIndex == index;
          final String dayName = index == 0 ? 'Hôm nay' : 'T${date.weekday + 1}';

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDateIndex = index;
                _selectedSlotIndex = null;
                _reservationTimer?.cancel();
              });
            },
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlotsGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_timeSlots.length, (index) {
          final slot = _timeSlots[index];
          final bool isLocked = slot['isLocked'] as bool;
          final bool isSelected = _selectedSlotIndex == index;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSlotCard(
              index: index,
              time: slot['time'] as String,
              isLocked: isLocked,
              statusText: slot['statusText'] as String,
              price: slot['price'] as int,
              isSelected: isSelected,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSlotCard({
    required int index,
    required String time,
    required bool isLocked,
    required String statusText,
    required int price,
    required bool isSelected,
  }) {
    Color borderColor;
    Color bgColor;
    Color textColor;

    if (isSelected) {
      borderColor = AppColors.primaryGreen;
      bgColor = const Color(0xFFE8F5E9);
      textColor = AppColors.primaryGreen;
    } else if (isLocked) {
      borderColor = const Color(0xFFFCA5A5);
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFF991B1B);
    } else {
      borderColor = const Color(0xFFFCD34D);
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFF78350F);
    }

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              setState(() {
                _selectedSlotIndex = index;
              });
              _startTimer();
            },
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    time,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ),
                if (isLocked)
                  const Icon(Icons.lock_outlined, size: 14, color: Color(0xFF991B1B))
                else if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLocked ? statusText : '${_formatCurrency(price)} đ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLocked ? FontWeight.w500 : FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerBanner() {
    return Container(
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
    );
  }

  Widget _buildBottomConfirmBar() {
    final selectedSlot = _timeSlots[_selectedSlotIndex!];
    final int price = selectedSlot['price'] as int;

    return Container(
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
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TỔNG TIỀN TẠM TÍNH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                Text(
                  '${_formatCurrency(price)} đ',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã chọn ${selectedSlot['time']} tại ${_selectedCourtObj!['name']}.'),
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D5238),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('XÁC NHẬN ĐẶT SÂN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
