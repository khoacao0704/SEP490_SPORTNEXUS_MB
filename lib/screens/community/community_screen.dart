import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_drawer.dart';
import '../../widgets/review/fair_play_guard.dart';
import 'create_lfg_screen.dart';
import 'flash_claim_checkout_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // Filter States
  String _selectedSport = 'All';
  String _selectedCity = 'Hồ Chí Minh';
  String? _selectedWard;
  String _selectedFormat = 'All'; // 'All', 'Singles', 'Doubles', '1v3', 'Team'
  bool _isNearbyOnly = false;
  double _maxPrice = 300000;

  // Vietnam Provinces
  final List<String> _vietnamProvinces = [
    'Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Hải Phòng', 'Cần Thơ',
    'Bình Dương', 'Đồng Nai', 'Bà Rịa - Vũng Tàu', 'An Giang', 'Bắc Ninh'
  ];

  // Wards / Districts
  final Map<String, List<String>> _cityWards = {
    'Hồ Chí Minh': [
      'Tất cả Quận/Phường',
      'Quận 1 • P. Bến Nghé',
      'Quận 3 • P. Võ Thị Sáu',
      'Quận 7 • P. Tân Thuận Đông',
      'Quận 7 • P. Tân Phong',
      'Q. Bình Thạnh • P. 25',
      'Q. Gò Vấp • P. 5',
      'TP. Thủ Đức • P. Linh Trung',
    ],
    'Hà Nội': [
      'Tất cả Quận/Phường',
      'Q. Hoàn Kiếm • P. Hàng Bạc',
      'Q. Cầu Giấy • P. Dịch Vọng',
      'Q. Đống Đa • P. Láng Hạ',
    ],
    'Đà Nẵng': [
      'Tất cả Quận/Phường',
      'Q. Hải Châu • P. Hòa Cường Bắc',
      'Q. Thanh Khê • P. Vĩnh Trung',
    ],
  };

  // Master List of LFG Posts
  final List<Map<String, dynamic>> _allLfgPosts = [
    {
      'id': '1',
      'hostName': 'Chính Ngô',
      'hostAvatar': 'C',
      'hostFairPlay': 100,
      'sport': 'Badminton',
      'sportName': 'Cầu Lông (Đôi)',
      'formatType': 'Doubles',
      'format': 'Ghép 2 vs 2 • Cần 1 người',
      'courtName': 'Sân Eco Quận 7',
      'city': 'Hồ Chí Minh',
      'location': 'Quận 7 • P. Tân Thuận Đông',
      'distance': '1.2 km',
      'time': '19:30 - 20:30 (Tối nay)',
      'slotsLeft': 1,
      'totalSlots': 4,
      'slotPrice': 35000,
    },
    {
      'id': '2',
      'hostName': 'FC Sài Gòn',
      'hostAvatar': 'F',
      'hostFairPlay': 98,
      'sport': 'Football',
      'sportName': 'Bóng Đá Sân 7',
      'formatType': 'Team',
      'format': 'Team vs Team • Cần 1 Đội đối thủ',
      'courtName': 'Sân Vận Động Thống Nhất',
      'city': 'Hồ Chí Minh',
      'location': 'Quận 10 • P. 14',
      'distance': '3.5 km',
      'time': '20:00 - 21:30 (Tối nay)',
      'slotsLeft': 1,
      'totalSlots': 2,
      'slotPrice': 250000,
    },
    {
      'id': '3',
      'hostName': 'Minh Tuấn',
      'hostAvatar': 'M',
      'hostFairPlay': 95,
      'sport': 'Pickleball',
      'sportName': 'Pickleball (1v3)',
      'formatType': '1v3',
      'format': 'Ghép 1 vs 3 • Cần 3 người đủ 4',
      'courtName': 'Sân Pickleball Kỳ Hòa',
      'city': 'Hồ Chí Minh',
      'location': 'Quận 10 • P. 12',
      'distance': '4.1 km',
      'time': '18:00 - 19:30 (Ngày mai)',
      'slotsLeft': 3,
      'totalSlots': 4,
      'slotPrice': 40000,
    },
    {
      'id': '4',
      'hostName': 'Ballers Q7',
      'hostAvatar': 'B',
      'hostFairPlay': 90,
      'sport': 'Basketball',
      'sportName': 'Bóng Rổ 3x3',
      'formatType': 'Team',
      'format': 'Giao hữu • Cần 1 Team 3x3',
      'courtName': 'Sân Bóng Rổ RMIT',
      'city': 'Hồ Chí Minh',
      'location': 'Quận 7 • P. Tân Phong',
      'distance': '1.8 km',
      'time': '17:30 - 19:00 (Ngày mai)',
      'slotsLeft': 1,
      'totalSlots': 2,
      'slotPrice': 80000,
    },
    {
      'id': '5',
      'hostName': 'Hoàng Nam',
      'hostAvatar': 'H',
      'hostFairPlay': 100,
      'sport': 'Tennis',
      'sportName': 'Tennis (Đơn)',
      'formatType': 'Singles',
      'format': 'Ghép 1 vs 1 • Cần 1 đối thủ',
      'courtName': 'Sân Tennis HAGL',
      'city': 'Hồ Chí Minh',
      'location': 'Quận 7 • P. Tân Hưng',
      'distance': '2.0 km',
      'time': '06:00 - 07:30 (Sáng mai)',
      'slotsLeft': 1,
      'totalSlots': 2,
      'slotPrice': 120000,
    },
  ];

  final List<Map<String, dynamic>> _sports = [
    {'id': 'All', 'name': 'Tất cả', 'icon': Icons.sports},
    {'id': 'Badminton', 'name': 'Cầu Lông', 'icon': Icons.sports_tennis},
    {'id': 'Pickleball', 'name': 'Pickleball', 'icon': Icons.sports_kabaddi},
    {'id': 'Football', 'name': 'Bóng Đá', 'icon': Icons.sports_soccer},
    {'id': 'Basketball', 'name': 'Bóng Rổ', 'icon': Icons.sports_basketball},
    {'id': 'Tennis', 'name': 'Tennis', 'icon': Icons.sports_baseball},
  ];

  List<Map<String, dynamic>> get _filteredPosts {
    return _allLfgPosts.where((post) {
      if (_selectedSport != 'All' && post['sport'] != _selectedSport) return false;
      if (post['city'] != _selectedCity) return false;

      if (_selectedWard != null && _selectedWard!.isNotEmpty && _selectedWard != 'Tất cả Quận/Phường') {
        if (!post['location'].contains(_selectedWard!)) return false;
      }

      if (_selectedFormat != 'All' && post['formatType'] != _selectedFormat) return false;

      if (_isNearbyOnly) {
        double dist = double.tryParse(post['distance'].replaceAll(' km', '').replaceAll('m', '')) ?? 99;
        if (post['distance'].contains('km') && dist > 3.0) return false;
      }

      if (post['slotPrice'] > _maxPrice) return false;

      return true;
    }).toList();
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
                        });
                        Navigator.pop(context);
                        _showWardPicker(); // Open ward picker immediately
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
    final wards = _cityWards[_selectedCity] ?? ['Tất cả Quận/Phường', 'Quận 1', 'Quận 3', 'Quận 7'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chọn Quận / Phường (${_selectedCity})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          _selectedWard = ward == 'Tất cả Quận/Phường' ? null : ward;
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

  void _showAdvancedFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bộ Lọc Nâng Cao LFG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedFormat = 'All';
                            _isNearbyOnly = false;
                            _maxPrice = 300000;
                          });
                        },
                        child: const Text('Đặt lại', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Hình thức ghép
                          const Text('Hình Thức Ghép Trận:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildModalChip('Tất cả', _selectedFormat == 'All', () => setModalState(() => _selectedFormat = 'All')),
                              _buildModalChip('Đơn (1v1)', _selectedFormat == 'Singles', () => setModalState(() => _selectedFormat = 'Singles')),
                              _buildModalChip('Đôi (2v2)', _selectedFormat == 'Doubles', () => setModalState(() => _selectedFormat = 'Doubles')),
                              _buildModalChip('Ghép 1 vs 3 (Cần 3)', _selectedFormat == '1v3', () => setModalState(() => _selectedFormat = '1v3')),
                              _buildModalChip('Team vs Team', _selectedFormat == 'Team', () => setModalState(() => _selectedFormat = 'Team')),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 2. Mức giá tối đa
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Giá / Slot Tối Đa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                              Text('${_formatCurrency(_maxPrice.toInt())} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                            ],
                          ),
                          Slider(
                            value: _maxPrice,
                            min: 20000,
                            max: 300000,
                            divisions: 28,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) => setModalState(() => _maxPrice = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Parent state refresh
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5238),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('ÁP DỤNG BỘ LỌC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder),
      ),
      onSelected: (_) => onTap(),
    );
  }

  String _formatCurrency(int amount) {
    String str = amount.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts;

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
        title: const Text('Bảng Tin Ghép Trận (LFG)', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!await ensureCanJoinLfg(context) || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateLfgScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tạo Kèo Mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          )
        ],
      ),
      drawer: const MainDrawer(selectedIndex: 2),
      body: Column(
        children: [
          // Quick Filter Bar
          _buildQuickFilterBar(),
          // Sports Category Bar
          _buildSportsHorizontalBar(),
          const Divider(height: 1, color: AppColors.divider),

          // LFG List
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Không tìm thấy kèo LFG phù hợp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
                        const SizedBox(height: 4),
                        const Text('Thử thay đổi bộ lọc hoặc tạo kèo mới xem sao nhé!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _buildLfgCard(post);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterBar() {
    String locationLabel = _selectedWard == null
        ? _selectedCity
        : '$_selectedCity • ${_selectedWard!.split('•').last.trim()}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Location Picker Chip (City & Ward)
          GestureDetector(
            onTap: _showCityPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGreen),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.primaryGreen),
                  const SizedBox(width: 4),
                  Text(locationLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryGreen)),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.primaryGreen),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nearby Filter Toggle Chip
          GestureDetector(
            onTap: () {
              setState(() {
                _isNearbyOnly = !_isNearbyOnly;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isNearbyOnly ? AppColors.lightGreen : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _isNearbyOnly ? AppColors.primaryGreen : AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 14, color: _isNearbyOnly ? AppColors.primaryGreen : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Gần bạn (<3km)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _isNearbyOnly ? AppColors.primaryGreen : AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Format Quick Filter
          GestureDetector(
            onTap: _showAdvancedFilterSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedFormat != 'All' ? AppColors.lightGreen : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _selectedFormat != 'All' ? AppColors.primaryGreen : AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.style, size: 14, color: _selectedFormat != 'All' ? AppColors.primaryGreen : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _selectedFormat == 'All'
                        ? 'Hình thức ∨'
                        : _selectedFormat == 'Singles'
                            ? 'Đơn (1v1)'
                            : _selectedFormat == 'Doubles'
                                ? 'Đôi (2v2)'
                                : _selectedFormat == '1v3'
                                    ? 'Ghép 1v3'
                                    : 'Team vs Team',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _selectedFormat != 'All' ? AppColors.primaryGreen : AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Advanced Filter Icon
          GestureDetector(
            onTap: _showAdvancedFilterSheet,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.tune, size: 18, color: AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsHorizontalBar() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sport = _sports[index];
          final bool isSelected = _selectedSport == sport['id'];

          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              sport['icon'] as IconData,
              size: 16,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
            ),
            label: Text(
              sport['name'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primaryGreen,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder),
            ),
            onSelected: (bool selected) {
              setState(() {
                _selectedSport = sport['id'] as String;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildLfgCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Host Row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  post['hostAvatar'] as String,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['hostName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text('Host • Fair Play: ${post['hostFairPlay']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
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
                  post['sportName'] as String,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.divider),

          // Format & Details
          Text(post['format'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text('${post['courtName']} • ${post['location']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('cách ${post['distance']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.tagOrangeText),
              const SizedBox(width: 4),
              Text(post['time'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
            ],
          ),
          const SizedBox(height: 16),

          // Price & Flash Claim Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GIÁ / SLOT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Text(
                    '${_formatCurrency(post['slotPrice'] as int)} đ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!await ensureCanJoinLfg(context) || !mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlashClaimCheckoutScreen(
                        sportName: post['sportName'] as String,
                        hostName: post['hostName'] as String,
                        courtName: post['courtName'] as String,
                        location: post['location'] as String,
                        time: post['time'] as String,
                        slotPrice: post['slotPrice'] as int,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.flash_on, size: 16, color: Colors.white),
                label: const Text('FLASH CLAIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D5238),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
