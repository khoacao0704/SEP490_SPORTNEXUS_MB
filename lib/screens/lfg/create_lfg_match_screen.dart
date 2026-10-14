import 'package:flutter/material.dart';
import '../../core/constants/lfg_rules.dart';
import '../../core/constants/vietnam_cities.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/facility_repository.dart';
import '../../models/facility.dart';
import '../../models/facility_search.dart';
import '../../models/lfg_match.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/slot_picker.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/lfg/lfg_actions.dart';
import '../../widgets/review/fair_play_guard.dart';
import 'lfg_match_detail_screen.dart';
import 'lfg_payment_screen.dart';

/// Tạo kèo: chọn môn → hình thức → sân → khung giờ (48 giờ – 5 ngày tới) → thanh toán cọc host.
class CreateLfgMatchScreen extends StatefulWidget {
  const CreateLfgMatchScreen({super.key});

  @override
  State<CreateLfgMatchScreen> createState() => _CreateLfgMatchScreenState();
}

class _CreateLfgMatchScreenState extends State<CreateLfgMatchScreen> {
  Sport _sport = Sport.badminton;
  late LfgFormat _format = LfgFormat.forSport(_sport).last;
  String _city = VietnamCities.hoChiMinh.name;
  String? _district;
  List<String> _districts = [];

  List<Facility> _facilities = [];
  bool _loadingFacilities = false;
  Facility? _facility;

  late final List<DateTime> _dates = _eligibleDates(DateTime.now());
  late DateTime _date = _dates.first;
  List<TimeSlot> _slots = [];
  bool _loadingSlots = false;
  TimeSlot? _slot;

  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _loadFacilities();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Các ngày có thể có khung giờ hợp lệ: từ ngày chứa mốc +48 giờ tới ngày chứa mốc +5 ngày.
  static List<DateTime> _eligibleDates(DateTime now) {
    final first = now.add(LfgRules.fillDeadlineBeforeStart);
    final last = now.add(LfgRules.maxCreateAhead);
    final dates = <DateTime>[];
    for (var d = DateTime(first.year, first.month, first.day); !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      dates.add(d);
    }
    return dates;
  }

  Future<void> _loadDistricts() async {
    final districts = await AppRepositories.facility.getDistricts(_city);
    if (mounted) setState(() => _districts = districts);
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _loadingFacilities = true;
      _facility = null;
      _slots = [];
      _slot = null;
    });
    try {
      final results = await AppRepositories.facility
          .searchFacilities(FacilitySearchQuery(city: _city, district: _district, sport: _sport, sort: FacilitySort.rating));
      if (!mounted) return;
      setState(() {
        _facilities = results.map((r) => r.facility).toList();
        _loadingFacilities = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFacilities = false);
    }
  }

  Future<void> _loadSlots() async {
    final facility = _facility;
    if (facility == null) return;
    setState(() {
      _loadingSlots = true;
      _slot = null;
    });
    try {
      final slots = await AppRepositories.facility.getTimeSlots(facility.id, _sport, _date);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _slots = slots.where((s) => !s.isFull && LfgRules.canCreateFor(s.start, now)).toList();
        _loadingSlots = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _selectSport(Sport sport) {
    setState(() {
      _sport = sport;
      _format = LfgFormat.forSport(sport).last;
    });
    _loadFacilities();
  }

  Future<void> _pickCity() async {
    final city = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text(LfgStrings.chooseCity, style: TextStyle(fontWeight: FontWeight.bold))),
            for (final c in VietnamCities.all)
              ListTile(
                title: Text(c.name),
                trailing: c.name == _city ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                onTap: () => Navigator.pop(sheetContext, c.name),
              ),
          ],
        ),
      ),
    );
    if (city == null || city == _city) return;
    setState(() {
      _city = city;
      _district = null;
      _districts = [];
    });
    _loadDistricts();
    _loadFacilities();
  }

  Future<void> _submit() async {
    final facility = _facility;
    final slot = _slot;
    if (facility == null || slot == null) return;
    // Chặn sớm lần nữa: điểm có thể đã đổi trong lúc đang ở màn này.
    if (!await ensureCanJoinLfg(context) || !mounted) return;

    setState(() => _isSubmitting = true);
    final SlotHold hold;
    try {
      hold = await AppRepositories.facility.holdSlots([slot]);
    } on FacilityException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showLfgError(context, e.message);
        _loadSlots();
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final created = await Navigator.push<LfgMatch>(
      context,
      MaterialPageRoute(
        builder: (_) => LfgPaymentScreen(
          summary: LfgPaymentSummary(
            heading: LfgStrings.createTitle,
            sport: _sport,
            format: _format,
            facilityName: facility.name,
            district: facility.district,
            start: slot.start,
            end: slot.end,
          ),
          amount: LfgRules.depositPerSlot(slot.price, _format.totalSlots),
          expiresAt: hold.expiresAt,
          onConfirm: () => AppRepositories.lfg.createMatch(
            hold: hold,
            facility: facility,
            format: _format,
            note: _noteController.text,
          ),
          onRelease: () => AppRepositories.facility.releaseHold(hold.holdId),
        ),
      ),
    );
    if (created == null || !mounted) {
      _loadSlots();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(LfgStrings.createSuccess), backgroundColor: AppColors.primaryGreen),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LfgMatchDetailScreen(matchId: created.id, initial: created)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          LfgStrings.createTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _title(LfgStrings.stepSport),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in Sport.values)
                _chip(
                  label: s.label,
                  icon: sportIcon(s),
                  selected: s == _sport,
                  onTap: () => _selectSport(s),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _title(LfgStrings.stepFormat),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in LfgFormat.forSport(_sport))
                _chip(label: f.label, selected: f == _format, onTap: () => setState(() => _format = f)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LfgStrings.depositExplain(_format.label, _format.totalSlots, _format.isTeam),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _title(LfgStrings.stepFacility),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(label: _city, icon: Icons.location_on, selected: true, onTap: _pickCity),
                const SizedBox(width: 8),
                _chip(
                  label: LfgStrings.allDistricts,
                  selected: _district == null,
                  onTap: () {
                    setState(() => _district = null);
                    _loadFacilities();
                  },
                ),
                for (final d in _districts) ...[
                  const SizedBox(width: 8),
                  _chip(
                    label: d,
                    selected: d == _district,
                    onTap: () {
                      setState(() => _district = d);
                      _loadFacilities();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildFacilities(),
          if (_facility != null) ...[
            const SizedBox(height: 18),
            _title(LfgStrings.stepTime),
            const Text(LfgStrings.timeWindowNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            DateSelectorBar(
              dates: _dates,
              selected: _date,
              markedDates: {if (slot != null) slot.start},
              onSelected: (d) {
                setState(() => _date = d);
                _loadSlots();
              },
            ),
            const SizedBox(height: 12),
            if (_loadingSlots)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_slots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(LfgStrings.noSlots, style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              TimeSlotGrid(
                slots: _slots,
                selectedSlotIds: {if (slot != null) slot.id},
                now: DateTime.now(),
                onSelected: (s) => setState(() => _slot = s),
              ),
            const SizedBox(height: 18),
            _title(LfgStrings.stepNote),
            TextField(
              controller: _noteController,
              maxLength: 200,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: LfgStrings.noteHint,
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: slot == null ? null : _buildBottomBar(slot),
    );
  }

  Widget _buildFacilities() {
    if (_loadingFacilities) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }
    if (_facilities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(LfgStrings.noFacilities, style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      children: [
        for (final f in _facilities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _facility = f);
                  _loadSlots();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: f.id == _facility?.id ? AppColors.primaryGreen : AppColors.cardBorder,
                      width: f.id == _facility?.id ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                            Text(
                              '${f.district} • ★ ${f.rating}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.vnd(f.offeringFor(_sport)?.priceFrom ?? f.priceFrom),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(TimeSlot slot) {
    final deposit = LfgRules.depositPerSlot(slot.price, _format.totalSlots);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${LfgStrings.courtPrice} ${Formatters.vnd(slot.price)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Formatters.vnd(deposit),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(LfgStrings.continueToPay, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
      );

  static Widget _chip({required String label, required bool selected, required VoidCallback onTap, IconData? icon}) {
    return ChoiceChip(
      showCheckmark: false,
      avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryGreen),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.white,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMain),
      side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
