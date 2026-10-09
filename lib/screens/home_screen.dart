import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/main_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildTabs(),
          _buildFilters(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildSessionCard();
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleSpacing: 16,
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
      title: const Text(
        'SportNexus',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppColors.textMain),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign In'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabItem('Find sessions', true),
          const SizedBox(width: 24),
          _buildTabItem('Find venues', false),
          const SizedBox(width: 24),
          _buildTabItem('Find groups', false),
          const SizedBox(width: 24),
          _buildTabItem('Find tournaments', false),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (isSelected)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 3,
            width: 30,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          )
      ],
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip(Icons.location_on_outlined, 'Hồ Chí Minh'),
          const SizedBox(width: 8),
          _buildFilterChip(Icons.calendar_today_outlined, 'Soonest d...'),
          const SizedBox(width: 8),
          _buildIconButton(Icons.auto_awesome),
          const SizedBox(width: 8),
          _buildIconButton(Icons.tune),
        ],
      ),
    );
  }

  Widget _buildFilterChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Icon(icon, size: 20, color: AppColors.textSecondary),
    );
  }

  Widget _buildSessionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side - Image Placeholder
          Container(
            width: 120,
            height: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 40),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.sports_tennis, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Badminton',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Right Side - Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kèo sân Eco Quận 7',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Host Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.primaryGreen,
                        child: const Text('C', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      const Text('Chính Ngô', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Time
                  const Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: AppColors.tagOrangeText),
                      SizedBox(width: 4),
                      Text('Today, 14:00-16:00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Location
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Eco Quận 7 • Tân Thuận',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Tags and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildLevelTag('TBY', AppColors.tagGreenBg, AppColors.tagGreenText),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_right_alt, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          _buildLevelTag('TB+', AppColors.tagOrangeBg, AppColors.tagOrangeText),
                        ],
                      ),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '60k-70k ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                            TextSpan(text: '/slot', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
