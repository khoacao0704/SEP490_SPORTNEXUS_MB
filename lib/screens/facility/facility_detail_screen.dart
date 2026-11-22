import 'package:flutter/material.dart';
import '../../core/constants/booking_rules.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/facility_repository.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/recurring_plan.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking/recurring_booking_section.dart';
import '../../widgets/facility/amenity_icon.dart';
import '../../widgets/facility/court_type_selector.dart';
import '../../widgets/facility/facility_card.dart';
import '../../widgets/facility/facility_map.dart';
import '../../widgets/facility/slot_picker.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/review/facility_reviews_section.dart';
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

  /// Các sân con đang sáng (chọn nhiều được): lưới giờ dùng chung, bấm một khung là chọn khung đó cho mọi sân đang sáng.
  /// Giữ nguyên khi đổi ngày (sân nào còn trong ngày), chọn lại khi đổi môn / loại sân.
  final List<String> _courts = [];

  /// Sân con đầu tiên đang sáng (dùng cho thông tin sân).
  String? get _court => _courts.firstOrNull;
  bool _isLoadingSlots = true;
  String? _slotsError;
  DateTime _now = DateTime.now();

  /// Khung giờ đã chọn (theo id), có thể thuộc nhiều ngày và nhiều sân con. Giữ nguyên khi đổi ngày / sân, xóa khi đổi môn.
  final Map<String, TimeSlot> _selected = {};

  List<TimeSlot> get _selectedSorted => _selected.values.toList()..sort((a, b) => a.start.compareTo(b.start));

  int get _selectedTotal => _selected.values.fold(0, (sum, s) => sum + s.price);

  bool _isHolding = false;
  int _imageIndex = 0;

  /// Đặt lặp lại hằng tuần: các khung đang chọn (1 ngày, 1 sân con) là mẫu; lặp vào [_weekdays] trong [_weeks] tuần
  /// tính từ ngày bắt đầu, app dò cùng sân con, cùng giờ ở các ngày đó.
  bool _recurring = false;
  int _weeks = RecurringBookingRules.minSessions;
  final Set<int> _weekdays = {};
  DateTime? _planStart;
  RecurringPlan? _plan;
  bool _planning = false;
  int _planGeneration = 0;

  bool get _patternValid => RecurringPlan.isValidPattern(_selectedSorted);

  /// Gói đã dò xong, đủ mọi tuần.
  bool get _planReady => _recurring && !_planning && (_plan?.isComplete ?? false);

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
        _courts.clear();
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
        _courts.removeWhere((c) => !courts.contains(c));
        if (_courts.isEmpty) {
          // Mặc định sân đầu tiên còn khung trống trong ngày.
          final free = freeSlotsByCourt(slots, _now);
          final first = courts.where((c) => (free[c] ?? 0) > 0).firstOrNull ?? courts.firstOrNull;
          if (first != null) _courts.add(first);
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
      _refreshPlan();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoadingSlots = false;
        _slotsError = FacilityStrings.loadError;
      });
    }
  }

  /// Bấm một ô giờ: [parts] = khung giờ đó ở mọi sân đang sáng. Đã chọn đủ thì bỏ chọn cả, chưa thì chọn cả.
  void _toggleSlots(List<TimeSlot> parts) {
    if (parts.isEmpty) return;
    String? notice;
    setState(() {
      if (parts.every((s) => _selected.containsKey(s.id))) {
        for (final s in parts) {
          _selected.remove(s.id);
        }
        return;
      }
      // Đặt lặp lại: chỉ chọn trong 1 ngày bắt đầu — chọn khung ở ngày khác thì bỏ các khung trước.
      if (_recurring && _selected.isNotEmpty && !RecurringPlan.isSameDay([..._selected.values, ...parts])) {
        _selected.clear();
        notice = BookingStrings.recurringOneDay;
      }
      for (final s in parts) {
        _selected[s.id] = s;
      }
      // Đặt lặp lại chỉ cho 1 sân con: chọn thêm sân khác thì tắt lặp lại (vẫn đặt thường được).
      if (_recurring && _multiCourt) {
        _recurring = false;
        notice = BookingStrings.recurringLockedMultiCourt;
      }
    });
    if (notice case final message?) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    _refreshPlan();
  }

  /// Đang sáng nhiều sân / chọn khung trên nhiều sân con → khóa đặt lặp lại.
  bool get _multiCourt => _courts.length > 1 || RecurringPlan.courtCount(_selected.values.toList()) > 1;

  /// Bật / tắt một sân con. Bật thêm: chọn luôn các khung đã chọn trong ngày đang xem cho sân mới (nếu còn trống).
  /// Tắt: bỏ các khung của sân đó trong ngày đang xem. Luôn giữ ít nhất 1 sân.
  void _toggleCourt(String court) {
    String? notice;
    setState(() {
      if (_courts.contains(court)) {
        if (_courts.length == 1) return;
        _courts.remove(court);
        _selected.removeWhere((_, s) => s.courtName == court && _isSameDay(s.start, _date));
        return;
      }
      _courts.add(court);
      // Các giờ đang chọn trong ngày ở những sân đang sáng → chọn cùng giờ cho sân mới.
      final times = <String, TimeSlot>{
        for (final s in _selected.values)
          if (_isSameDay(s.start, _date) && _courts.contains(s.courtName)) '${s.start}|${s.end}': s,
      };
      final missing = <TimeSlot>[];
      for (final t in times.values) {
        final slot = _slots.where((s) => s.courtName == court && s.start == t.start && s.end == t.end).firstOrNull;
        if (slot != null && slot.isBookable(_now)) {
          _selected[slot.id] = slot;
        } else {
          missing.add(t);
        }
      }
      if (missing.isNotEmpty) {
        missing.sort((a, b) => a.start.compareTo(b.start));
        notice = BookingStrings.courtNotFree(court, missing.map((s) => Formatters.timeRange(s.start, s.end)).join(', '));
      }
      if (_recurring) {
        _recurring = false;
        notice = BookingStrings.recurringLockedMultiCourt;
      }
    });
    if (notice case final message?) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    _refreshPlan();
  }

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Ô của lưới giờ. 1 sân: khung thật. Nhiều sân: mỗi giờ một ô gộp — còn trống khi mọi sân đang sáng còn trống,
  /// giá = tổng các sân; [parts] giữ khung thật của từng ô (theo id ô).
  ({List<TimeSlot> tiles, Map<String, List<TimeSlot>> parts}) _grid() {
    final courts = _courts;
    if (courts.length <= 1) {
      final tiles = _slots.where((s) => s.courtName == _court).toList();
      return (tiles: tiles, parts: {for (final s in tiles) s.id: [s]});
    }
    final byTime = <String, List<TimeSlot>>{};
    for (final s in _slots.where((s) => courts.contains(s.courtName))) {
      (byTime['${s.start.toIso8601String()}|${s.end.toIso8601String()}'] ??= []).add(s);
    }
    final tiles = <TimeSlot>[];
    final parts = <String, List<TimeSlot>>{};
    for (final entry in byTime.entries) {
      final list = entry.value..sort((a, b) => courts.indexOf(a.courtName).compareTo(courts.indexOf(b.courtName)));
      final first = list.first;
      final id = 'multi|${entry.key}';
      parts[id] = list;
      tiles.add(TimeSlot(
        id: id,
        facilityId: first.facilityId,
        sport: first.sport,
        courtType: first.courtType,
        courtName: courts.join(', '),
        start: first.start,
        end: first.end,
        price: list.fold(0, (sum, s) => sum + s.price),
        isAvailable: list.length == courts.length && list.every((s) => !s.isFull),
      ));
    }
    tiles.sort((a, b) => a.start.compareTo(b.start));
    return (tiles: tiles, parts: parts);
  }

  void _setRecurring(bool on) {
    if (on && _multiCourt) return;
    setState(() => _recurring = on);
    _refreshPlan();
  }

  void _setWeeks(int weeks) {
    if (weeks == _weeks) return;
    setState(() => _weeks = weeks);
    _refreshPlan();
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (!_weekdays.remove(weekday)) _weekdays.add(weekday);
    });
    _refreshPlan();
  }

  /// Ngày bắt đầu của lịch lặp lại = ngày của các khung đang chọn.
  DateTime? get _startDate {
    final first = _selectedSorted.firstOrNull;
    return first == null ? null : DateTime(first.start.year, first.start.month, first.start.day);
  }

  /// Dò lại lịch lặp lại theo khung / thứ / số tuần đang chọn; kết quả của lần dò cũ về muộn bị bỏ qua.
  Future<void> _refreshPlan() async {
    final generation = ++_planGeneration;
    final start = _startDate;
    // Đổi ngày bắt đầu: mặc định lặp đúng thứ của ngày đó (người chơi chọn thêm thứ khác nếu muốn).
    if (start != null && start != _planStart) {
      _planStart = start;
      _weekdays
        ..clear()
        ..add(start.weekday);
    }
    if (!_recurring || !_patternValid || _weekdays.isEmpty) {
      if (_plan != null || _planning) {
        setState(() {
          _plan = null;
          _planning = false;
        });
      } else {
        setState(() {});
      }
      return;
    }
    setState(() => _planning = true);
    final plan = await RecurringPlan.build(
      pattern: _selectedSorted,
      weekdays: {..._weekdays},
      weeks: _weeks,
      loadDay: (date) =>
          AppRepositories.facility.getTimeSlots(_facility.id, _sport, date, courtType: _selectedSorted.first.courtType),
      now: DateTime.now(),
    );
    if (!mounted || generation != _planGeneration) return;
    setState(() {
      _plan = plan;
      _planning = false;
    });
  }

  /// Nhãn môn ở màn thanh toán: khung đã chọn cùng một loại sân thì kèm loại sân, nhiều loại thì chỉ tên môn.
  String get _sportLabel {
    final types = _selected.values.map((s) => s.courtType).toSet();
    final type = types.length == 1 ? types.single : null;
    return type == null || type.isStandard ? _sport.label : '${_sport.label} • ${type.label}';
  }

  /// Đặt nhiều sân con: sân thiếu khung giờ so với sân khác cùng ngày (`null` = hợp lệ).
  CourtsMismatch? get _courtsMismatch => findCourtsMismatch(_selected.values);

  /// Dữ liệu BE không tách quận / thành phố: dùng địa chỉ đầy đủ.
  String get _locationLabel => _facility.city.isEmpty ? _facility.address : '${_facility.district}, ${_facility.city}';

  Future<void> _handleBook() async {
    if (_selected.isEmpty || _courtsMismatch != null) return;
    final plan = _recurring ? _plan : null;
    if (_recurring && !_planReady) return;

    setState(() => _isHolding = true);
    SlotHold hold;
    try {
      hold = await AppRepositories.facility.holdSlots(plan?.slots ?? _selectedSorted);
    } on FacilityException catch (e) {
      if (!mounted) return;
      setState(() => _isHolding = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      _loadSlots();
      return;
    }
    if (!mounted) return;
    setState(() => _isHolding = false);

    // Gói gửi BE lấy bản khung mới nhất trong lượt giữ (cùng id).
    final held = {for (final s in hold.slots) s.id: s};
    final summary = plan == null ? '' : _recurringSummary(_selectedSorted, _weekdays);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(
          sport: _sportLabel,
          courtName: _facility.name,
          location: _locationLabel,
          // Gói: các ngày liệt kê ở khối "Các buổi trong lịch" của màn Thanh toán.
          dateTime: plan == null ? describeSlotSchedule(hold.slots) : summary,
          totalAmount: hold.totalPrice,
          initialSecondsRemaining: hold.secondsRemaining(DateTime.now()),
          hold: hold,
          packageDiscountPercent: _facility.recurringDiscountPercent,
          recurring: plan == null
              ? null
              : RecurringCheckout(
                  sessions: hold.slots.length,
                  discountPercent: _facility.recurringDiscountPercent,
                  summary: summary,
                  packages: [
                    for (final p in plan.packages) [for (final s in p) held[s.id] ?? s],
                  ],
                  days: [
                    for (final d in plan.sessions)
                      RecurringSession(date: d.date, slots: [for (final s in d.slots) held[s.id] ?? s], issue: d.issue),
                  ],
                ),
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

  /// "T3, T5 • Sân 1, Sân 2 • 09:00 - 11:00" (các khung liền nhau trên cùng sân gộp thành một khoảng giờ).
  static String _recurringSummary(List<TimeSlot> pattern, Set<int> weekdays) {
    final days = (weekdays.toList()..sort()).map((d) => BookingStrings.weekdayShort[d - 1]).join(', ');
    return '$days • ${describeCourtTimes(pattern)}';
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: RecurringBookingSection(
                    enabled: _recurring,
                    onToggle: _setRecurring,
                    available: !_multiCourt,
                    discountPercent: _facility.recurringDiscountPercent,
                    patternValid: _patternValid,
                    startDate: _startDate,
                    slotsPerDay: _selected.length,
                    weekdays: _weekdays,
                    onWeekdayToggled: _toggleWeekday,
                    weeks: _weeks,
                    onWeeksChanged: _setWeeks,
                    plan: _plan,
                    planning: _planning,
                  ),
                ),
                _buildAboutSection(),
                FacilityReviewsSection(facilityId: _facility.id, facilityName: _facility.name),
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
          // Wrap: máy hẹp / chữ to thì khoảng cách xuống dòng thay vì tràn.
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${_facility.rating}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  Flexible(
                    child: Text(
                      ' (${_facility.reviewCount} ${FacilityStrings.reviews})',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (widget.distanceKm != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me, size: 15, color: AppColors.primaryGreen),
                    const SizedBox(width: 2),
                    Text(
                      GeoUtils.formatDistance(widget.distanceKm!),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                    ),
                  ],
                ),
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
              Expanded(
                child: Text(
                  '${FacilityStrings.openingHours}: ${_facility.openTime} - ${_facility.closeTime}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (_facility.recurringDiscountPercent > 0) ...[
            const SizedBox(height: 10),
            RecurringDiscountBanner(percent: _facility.recurringDiscountPercent),
          ],
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
                  _courts.clear();
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
              // Giữ khung đã chọn ở loại sân khác (cùng môn): đặt chung được, vd. Sân 2 + Sân Cactus (sân đôi).
              setState(() {
                _courtType = type;
                _courts.clear();
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
            selectedCourts: _courts.toSet(),
            freeSlots: freeSlotsByCourt(_slots, _now),
            pickedSlots: {
              for (final c in courts) c: _selected.values.where((s) => s.courtName == c).length,
            },
            onSelected: _toggleCourt,
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
        if (_courts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              BookingStrings.multiCourtHint(_courts.length),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
            ),
          ),
        Builder(builder: (context) {
          final grid = _grid();
          return TimeSlotGrid(
            slots: grid.tiles,
            // Ô gộp nhiều sân sáng khi mọi sân đã chọn khung đó.
            selectedSlotIds: {
              for (final e in grid.parts.entries)
                if (e.value.every((s) => _selected.containsKey(s.id))) e.key,
            },
            now: _now,
            onSelected: (tile) => _toggleSlots(grid.parts[tile.id] ?? [tile]),
          );
        }),
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
                            Flexible(child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.textMain))),
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
                          _refreshPlan();
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
                                  _refreshPlan();
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
    final plan = _planReady ? _plan : null;
    final percent = _facility.recurringDiscountPercent;
    final total = plan == null ? _selectedTotal : RecurringBookingRules.discounted(plan.originalTotal, percent);
    final mismatch = _courtsMismatch;
    final canBook = count > 0 && !_isHolding && mismatch == null && (!_recurring || _planReady);
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
                    count == 0 ? FacilityStrings.selectSlotFirst : Formatters.vnd(total),
                    style: TextStyle(
                      fontSize: count == 0 ? 13 : 20,
                      fontWeight: FontWeight.bold,
                      color: count == 0 ? AppColors.textSecondary : AppColors.primaryGreen,
                    ),
                  ),
                  if (plan != null)
                    Text.rich(
                      TextSpan(
                        text: BookingStrings.packageTitle(plan.slots.length),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        children: [
                          if (percent > 0)
                            TextSpan(
                              text: '  ${Formatters.vnd(plan.originalTotal)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    )
                  else if (count > 0)
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
                  if (mismatch != null)
                    Text(
                      BookingStrings.courtsMismatch(
                        mismatch.court,
                        mismatch.missing.map((r) => Formatters.timeRange(r.$1, r.$2)).join(', '),
                        Formatters.weekdayDayMonth(mismatch.day),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.red, height: 1.3),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canBook ? _handleBook : null,
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
