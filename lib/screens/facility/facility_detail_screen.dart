import 'package:flutter/material.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/facility_repository.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/amenity_icon.dart';
import '../../widgets/facility/court_type_selector.dart';
import '../../widgets/facility/facility_card.dart';
import '../../widgets/facility/facility_map.dart';
import '../../widgets/facility/slot_picker.dart';
import '../../widgets/facility/sport_icon.dart';
import '../booking/booking_checkout_screen.dart';

class FacilityDetailScreen extends StatefulWidget {
  final Facility facility;
  final double? distanceKm;
  final Sport? initialSport;

  const FacilityDetailScreen({super.key, required this.facility, this.distanceKm, this.initialSport});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  static const int _bookableDays = 7;

  late Sport _sport;
  late CourtType _courtType;
  late final List<DateTime> _dates;
  late DateTime _date;

  /// Khung giờ của mọi sân con trong ngày đang xem.
  List<TimeSlot> _slots = [];

  /// Sân con đang xem; giữ nguyên khi đổi ngày, chọn lại khi đổi môn / loại sân.
  String? _court;
  bool _isLoadingSlots = true;
  String? _slotsError;
  DateTime _now = DateTime.now();

  /// Khung giờ đã chọn (theo id), có thể thuộc nhiều ngày và nhiều sân con. Giữ nguyên khi đổi ngày / sân, xóa khi đổi môn.
  final Map<String, TimeSlot> _selected = {};

  List<TimeSlot> get _selectedSorted => _selected.values.toList()..sort((a, b) => a.start.compareTo(b.start));

  int get _selectedTotal => _selected.values.fold(0, (sum, s) => sum + s.price);

  bool _isHolding = false;
  int _imageIndex = 0;

  /// Mỗi lần tải khung giờ tăng số này; kết quả của lần tải cũ về muộn sẽ bị bỏ qua.
  int _loadGeneration = 0;

  /// Bản từ kết quả tìm kiếm, thay bằng bản đầy đủ (ảnh, mô tả, số sân từng môn...) khi tải xong.
  late Facility _facility = widget.facility;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSport;
    _sport = initial != null && _facility.offeringFor(initial) != null
        ? initial
        : _facility.sports.firstOrNull ?? initial ?? Sport.values.first;
    _courtType = _facility.offeringFor(_sport)?.courtType ?? CourtType.standard;

    final today = DateTime(_now.year, _now.month, _now.day);
    _dates = List.generate(_bookableDays, (i) => today.add(Duration(days: i)));
    _date = today;
    _loadSlots();
    _loadFacility();
  }

  Future<void> _loadFacility() async {
    final Facility fresh;
    try {
      fresh = await AppRepositories.facility.getFacility(_facility.id);
    } on FacilityException {
      return; // vẫn dùng thông tin từ kết quả tìm kiếm
    }
    if (!mounted) return;
    // Môn / loại sân đang xem không còn ở cơ sở (vd. sân con vừa tạm ngưng) thì chuyển sang môn đầu tiên.
    final stillOffered = fresh.offeringFor(_sport, courtType: _courtType) != null;
    setState(() {
      _facility = fresh;
      if (!stillOffered && fresh.sports.isNotEmpty) {
        _sport = fresh.offeringFor(_sport) != null ? _sport : fresh.sports.first;
        _courtType = fresh.offeringFor(_sport)!.courtType;
        _court = null;
        _selected.clear();
      }
    });
    if (!stillOffered && fresh.sports.isNotEmpty) _loadSlots();
  }

  Future<void> _loadSlots() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoadingSlots = true;
      _slotsError = null;
    });
    try {
      final slots = await AppRepositories.facility.getTimeSlots(_facility.id, _sport, _date, courtType: _courtType);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _slots = slots;
        _now = DateTime.now();
        _isLoadingSlots = false;
        final courts = courtsOf(slots);
        if (!courts.contains(_court)) {
          // Mặc định sân đầu tiên còn khung trống trong ngày.
          final free = freeSlotsByCourt(slots, _now);
          _court = courts.where((c) => (free[c] ?? 0) > 0).firstOrNull ?? courts.firstOrNull;
        }
        // Cập nhật khung đã chọn của ngày này theo dữ liệu mới; khung vừa hết sân / đã qua thì bỏ chọn.
        for (final slot in slots) {
          if (!_selected.containsKey(slot.id)) continue;
          if (slot.isBookable(_now)) {
            _selected[slot.id] = slot;
          } else {
            _selected.remove(slot.id);
          }
        }
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoadingSlots = false;
        _slotsError = FacilityStrings.loadError;
      });
    }
  }

  void _toggleSlot(TimeSlot slot) {
    setState(() {
      if (_selected.remove(slot.id) == null) _selected[slot.id] = slot;
    });
  }

  Future<void> _handleBook() async {
    if (_selected.isEmpty) return;

    setState(() => _isHolding = true);
    SlotHold hold;
    try {
      hold = await AppRepositories.facility.holdSlots(_selectedSorted);
    } on FacilityException catch (e) {
      if (!mounted) return;
      setState(() => _isHolding = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      _loadSlots();
      return;
    }
    if (!mounted) return;
    setState(() => _isHolding = false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(
          sport: _courtType.isStandard ? _sport.label : '${_sport.label} • ${_courtType.label}',
          courtName: _facility.name,
          // Dữ liệu BE không tách quận / thành phố: dùng địa chỉ đầy đủ.
          location: _facility.city.isEmpty ? _facility.address : '${_facility.district}, ${_facility.city}',
          dateTime: describeSlotSchedule(hold.slots),
          totalAmount: hold.totalPrice,
          initialSecondsRemaining: hold.secondsRemaining(DateTime.now()),
          hold: hold,
        ),
      ),
    );

    // Thanh toán thành công thì màn Thanh toán đưa người dùng về Trang chủ (màn này đã bị đóng).
    // Còn mounted nghĩa là người dùng quay lại hoặc hết giờ giữ chỗ: nhả chỗ và tải lại số sân trống
    // (vẫn giữ các khung đã chọn để người dùng đặt lại nhanh).
    if (!mounted) return;
    await AppRepositories.facility.releaseHold(hold.holdId);
    _loadSlots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildImageHeader(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoHeader(),
                _section(
                  title: FacilityStrings.chooseSport,
                  child: _buildSportSelector(),
                ),
                _section(
                  title: FacilityStrings.chooseDate,
                  child: DateSelectorBar(
                    dates: _dates,
                    selected: _date,
                    markedDates: _selected.values.map((s) => s.start).toSet(),
                    onSelected: (d) {
                      setState(() => _date = d);
                      _loadSlots();
                    },
                  ),
                ),
                _section(
                  title: FacilityStrings.chooseSlot,
                  child: _buildSlots(),
                ),
                _buildAboutSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageHeader() {
    final images = _facility.imageUrls;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textMain,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              const FacilityImage(url: null)
            else
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _imageIndex = i),
                itemBuilder: (_, i) => FacilityImage(url: images[i]),
              ),
            if (images.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _imageIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _imageIndex ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _facility.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${_facility.rating}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              Text(
                ' (${_facility.reviewCount} ${FacilityStrings.reviews})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (widget.distanceKm != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.near_me, size: 15, color: AppColors.primaryGreen),
                const SizedBox(width: 2),
                Text(
                  GeoUtils.formatDistance(widget.distanceKm!),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _facility.fullAddress,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${FacilityStrings.openingHours}: ${_facility.openTime} - ${_facility.closeTime}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSportSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _facility.sports.map((sport) {
            final selected = sport == _sport;
            final courts = _facility.offeringsFor(sport).fold(0, (sum, o) => sum + o.courtCount);
            return ChoiceChip(
              avatar: Icon(sportIcon(sport), size: 16, color: selected ? Colors.white : AppColors.primaryGreen),
              label: Text('${sport.label} • ${FacilityStrings.courtCount(courts)}'),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                if (selected) return;
                setState(() {
                  _sport = sport;
                  _courtType = _facility.offeringFor(sport)!.courtType;
                  _court = null;
                  _selected.clear(); // khung giờ của môn khác không dùng được
                });
                _loadSlots();
              },
              selectedColor: AppColors.primaryGreen,
              backgroundColor: AppColors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textMain,
              ),
              side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          }).toList(),
        ),
        // Có sân đã phân loại (vd. sân 5 người) — kể cả khi môn còn sân chưa phân loại ("Sân tiêu chuẩn").
        if (!_courtType.isStandard || _facility.offeringsFor(_sport).length > 1) ...[
          const SizedBox(height: 12),
          const Text(
            FacilityStrings.chooseCourtType,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          CourtTypeSelector(
            offerings: _facility.offeringsFor(_sport),
            selected: _courtType,
            onSelected: (type) {
              if (type == _courtType) return;
              setState(() {
                _courtType = type;
                _court = null;
                _selected.clear(); // khung giờ của loại sân khác không dùng được
              });
              _loadSlots();
            },
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.darkGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  FacilityStrings.sameCourtsNote,
                  style: TextStyle(fontSize: 12, color: AppColors.darkGreen, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlots() {
    if (_isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }
    if (_slotsError != null) {
      return Center(
        child: Column(
          children: [
            Text(_slotsError!, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _loadSlots, child: const Text(FacilityStrings.retry)),
          ],
        ),
      );
    }
    final courts = courtsOf(_slots);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (courts.isNotEmpty) ...[
          const Text(
            FacilityStrings.chooseCourt,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          CourtSelector(
            courts: courts,
            selected: _court,
            freeSlots: freeSlotsByCourt(_slots, _now),
            onSelected: (court) => setState(() => _court = court),
          ),
          if (_facility.courtDetailOf(_sport, _court) case final detail?) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            FacilityStrings.multiSlotHint,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        TimeSlotGrid(
          slots: _slots.where((s) => s.courtName == _court).toList(),
          selectedSlotIds: _selected.keys.toSet(),
          now: _now,
          onSelected: _toggleSlot,
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_facility.description.isNotEmpty)
          _section(
            title: FacilityStrings.about,
            child: Text(
              _facility.description,
              style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.5),
            ),
          ),
        if (_facility.amenities.isNotEmpty)
          _section(
            title: FacilityStrings.amenities,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _facility.amenities
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(amenityIcon(_facility.amenityIcons[a]), size: 14, color: AppColors.primaryGreen),
                            const SizedBox(width: 4),
                            Text(a, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        if (_facility.rules.isNotEmpty)
          _section(
            title: FacilityStrings.rules,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _facility.rules
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        if (_facility.hasLocation)
          _section(
            title: FacilityStrings.location,
            child: FacilityLocationPreview(location: _facility.location),
          ),
        if (_facility.phone.isNotEmpty)
          _section(
            title: FacilityStrings.contact,
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(_facility.phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  void _showSelectedSlotsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final slots = _selectedSorted;
          // Bỏ hết khung trong sheet thì đóng sheet.
          if (slots.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
            });
          }
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          FacilityStrings.selectedSlotsTitle,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(_selected.clear);
                          Navigator.pop(sheetContext);
                        },
                        child: const Text(FacilityStrings.clearSelection, style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: slots
                        .map((s) => ListTile(
                              leading: const Icon(Icons.schedule, color: AppColors.primaryGreen),
                              title: Text(
                                '${s.courtName} • ${Formatters.slotLabel(s.start, s.end)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(Formatters.vnd(s.price)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                                onPressed: () {
                                  setState(() => _selected.remove(s.id));
                                  setSheetState(() {});
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    final count = _selected.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    FacilityStrings.totalLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0 ? FacilityStrings.selectSlotFirst : Formatters.vnd(_selectedTotal),
                    style: TextStyle(
                      fontSize: count == 0 ? 13 : 20,
                      fontWeight: FontWeight.bold,
                      color: count == 0 ? AppColors.textSecondary : AppColors.primaryGreen,
                    ),
                  ),
                  if (count > 0)
                    InkWell(
                      onTap: _showSelectedSlotsSheet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text.rich(
                          TextSpan(
                            text: '${FacilityStrings.selectedSlotCount(count)} • ',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            children: const [
                              TextSpan(
                                text: FacilityStrings.viewSelected,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: count == 0 || _isHolding ? null : _handleBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.authPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.cardBorder,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isHolding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(FacilityStrings.bookNow, style: TextStyle(fontWeight: FontWeight.bold)),
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
