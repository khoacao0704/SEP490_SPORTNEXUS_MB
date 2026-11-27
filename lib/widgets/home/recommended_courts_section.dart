import 'package:flutter/material.dart';

import '../../core/strings/home_recommend_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/facility_repository.dart';
import '../../models/court_recommendation.dart';
import '../../models/time_slot.dart';
import '../../screens/booking/booking_checkout_screen.dart';
import '../../screens/facility/facility_search_screen.dart';
import '../../theme/app_colors.dart';
import '../facility/slot_picker.dart' show describeSlotSchedule;

/// Khối "Sân trống trong giờ rảnh của bạn" ở Trang chủ (như HomeRecommendations của Web): tối đa 6 ca,
/// nút "Đặt ca" giữ ca rồi mở màn thanh toán để người dùng xem lại (không trừ Điểm ngay, như Trợ lý AI của mobile).
/// Lỗi / không có gợi ý thì ẩn cả khối.
class RecommendedCourtsSection extends StatefulWidget {
  const RecommendedCourtsSection({super.key});

  @override
  State<RecommendedCourtsSection> createState() => _RecommendedCourtsSectionState();
}

class _RecommendedCourtsSectionState extends State<RecommendedCourtsSection> {
  List<CourtRecommendation> _items = const [];
  String? _bookingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await AppRepositories.courtRecommendation.getRecommendedCourts();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _book(CourtRecommendation c) async {
    final sport = c.sport;
    if (sport == null) return _error(HomeRecommendStrings.sportUnsupported);
    if (_bookingId != null) return;
    setState(() => _bookingId = c.courtSlotId);
    final SlotHold hold;
    try {
      hold = await AppRepositories.facility.holdSlots([
        TimeSlot(
          id: c.courtSlotId,
          facilityId: c.facilityId,
          sport: sport,
          courtName: c.courtName ?? '',
          start: c.start,
          end: c.end,
          price: c.price,
          isAvailable: true,
        ),
      ]);
    } on FacilityException catch (e) {
      if (mounted) setState(() => _bookingId = null);
      _error(e.message);
      _load(); // ca vừa có người đặt: tải lại gợi ý
      return;
    } catch (_) {
      if (mounted) setState(() => _bookingId = null);
      _error(HomeRecommendStrings.holdError);
      return;
    }
    if (!mounted) return;
    setState(() => _bookingId = null);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(
          sport: sport.label,
          courtName: c.facilityName,
          location: c.address,
          dateTime: describeSlotSchedule(hold.slots),
          totalAmount: hold.totalPrice,
          initialSecondsRemaining: hold.secondsRemaining(DateTime.now()),
          hold: hold,
        ),
      ),
    );
    // Thanh toán xong thì app về Trang chủ; còn quay lại từ màn thanh toán thì nhả chỗ.
    await AppRepositories.facility.releaseHold(hold.holdId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(HomeRecommendStrings.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilitySearchScreen())),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text(HomeRecommendStrings.findOther),
              ),
            ),
            for (final c in _items) _buildItem(c),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(CourtRecommendation c) {
    final meta = [
      if (c.sportName.isNotEmpty) c.sport?.label ?? c.sportName,
      ?c.courtName,
      '${Formatters.timeRange(c.start, c.end)} ${Formatters.weekdayDayMonth(c.start)}',
      if (c.distanceKm != null) '${c.distanceKm!.toStringAsFixed(1)} km',
    ].join(' · ');
    final busy = _bookingId == c.courtSlotId;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.facilityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(meta, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(Formatters.vnd(c.price),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _bookingId == null ? () => _book(c) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text(HomeRecommendStrings.book),
          ),
        ],
      ),
    );
  }
}
