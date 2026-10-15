import 'package:flutter/material.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/court_type.dart';
import '../../models/owner_facility.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_form.dart';

/// Thêm loại sân ([court] `null`) hoặc sửa số sân con, độ dài khung giờ, giờ cao điểm và bảng giá.
/// Pop trả về [OwnerFacility] sau khi lưu.
class CourtPricingScreen extends StatefulWidget {
  final OwnerFacility facility;
  final CourtConfig? court;

  const CourtPricingScreen({super.key, required this.facility, this.court});

  @override
  State<CourtPricingScreen> createState() => _CourtPricingScreenState();
}

class _CourtPricingScreenState extends State<CourtPricingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CourtPricing? _p = widget.court?.pricing;
  late final int _open = widget.facility.operations.openMinutes;
  late final int _close = widget.facility.operations.closeMinutes;

  late Sport _sport;
  late CourtType _type;
  late int _count = widget.court?.courtCount ?? 1;
  late int _slot = _p?.slotMinutes ?? 60;
  late int _peakStart = _p?.peakStart ?? (17 * 60).clamp(_open, _close);
  late int _peakEnd = _p?.peakEnd ?? (21 * 60).clamp(_open, _close);

  late final _weekday = _priceController(_p?.weekdayPrice);
  late final _weekdayPeak = _priceController(_p?.weekdayPeakPrice);
  late final _weekend = _priceController(_p?.weekendPrice);
  late final _weekendPeak = _priceController(_p?.weekendPeakPrice);

  bool _saving = false;
  bool get _isNew => widget.court == null;

  static TextEditingController _priceController(int? v) =>
      TextEditingController(text: v == null ? '' : Formatters.currency(v));

  @override
  void initState() {
    super.initState();
    final existing = widget.court;
    if (existing != null) {
      _sport = existing.sport;
      _type = existing.courtType;
    } else {
      final free = _freeKinds();
      _sport = free.isEmpty ? Sport.badminton : free.first.$1;
      _type = free.isEmpty ? CourtType.standard : free.first.$2;
    }
    for (final c in [_weekday, _weekdayPeak, _weekend, _weekendPeak]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_weekday, _weekdayPeak, _weekend, _weekendPeak]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Các loại sân cơ sở chưa có.
  List<(Sport, CourtType)> _freeKinds() => [
    for (final s in Sport.values)
      for (final t in CourtType.forSport(s))
        if (widget.facility.courtFor(s, t) == null) (s, t),
  ];

  bool get _peakValid => _peakEnd > _peakStart && _peakStart >= _open && _peakEnd <= _close;

  CourtPricing? get _pricing {
    final prices = [
      _weekday,
      _weekdayPeak,
      _weekend,
      _weekendPeak,
    ].map((c) => ThousandsInputFormatter.parse(c.text)).toList();
    if (prices.any((p) => p <= 0) || !_peakValid) return null;
    return CourtPricing(
      slotMinutes: _slot,
      peakStart: _peakStart,
      peakEnd: _peakEnd,
      weekdayPrice: prices[0],
      weekdayPeakPrice: prices[1],
      weekendPrice: prices[2],
      weekendPeakPrice: prices[3],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_peakValid) {
      if (!_peakValid) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.invalidPeak), backgroundColor: Colors.red));
      }
      return;
    }
    if (_isNew && widget.facility.courtFor(_sport, _type) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(OwnerFacilityStrings.duplicateCourt), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await AppRepositories.owner.saveCourt(
        widget.facility.id,
        CourtConfig(sport: _sport, courtType: _type, courtCount: _count, pricing: _pricing),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.saved)));
      Navigator.pop(context, updated);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _lock() async {
    final court = widget.court!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(OwnerFacilityStrings.lockTitle),
        content: Text(OwnerFacilityStrings.lockMessage(court.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(OwnerFacilityStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(OwnerFacilityStrings.lockCourt),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await AppRepositories.owner.lockCourt(widget.facility.id, court.sport, court.courtType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.lockedDone)));
      Navigator.pop(context, updated);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  String? _priceValidator(String? v) =>
      ThousandsInputFormatter.parse(v ?? '') > 0 ? null : OwnerFacilityStrings.invalidPrice;

  Widget _priceField(String label, TextEditingController c) => TextFormField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [ThousandsInputFormatter()],
    validator: _priceValidator,
    decoration: ownerInputDecoration(label, suffix: 'đ'),
  );

  @override
  Widget build(BuildContext context) {
    final free = _freeKinds();
    final pricing = _pricing;
    final preview = CourtConfig(sport: _sport, courtType: _type, courtCount: _count, pricing: pricing);
    final starts = preview.slotStarts(_open, _close);
    final now = DateTime.now();
    final nextWeekday = List.generate(
      7,
      (i) => now.add(Duration(days: i)),
    ).firstWhere((d) => !CourtPricing.isWeekend(d));
    final nextWeekend = List.generate(7, (i) => now.add(Duration(days: i))).firstWhere(CourtPricing.isWeekend);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          _isNew ? OwnerFacilityStrings.newCourtTitle : OwnerFacilityStrings.pricingTitle,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormSection(
              title: _isNew ? OwnerFacilityStrings.courtType : preview.label,
              children: [
                if (_isNew)
                  DropdownButtonFormField<(Sport, CourtType)>(
                    isExpanded: true,
                    initialValue: free.contains((_sport, _type)) ? (_sport, _type) : null,
                    decoration: ownerInputDecoration(OwnerFacilityStrings.courtType),
                    items: [
                      for (final k in free)
                        DropdownMenuItem(
                          value: k,
                          child: Text(CourtConfig(sport: k.$1, courtType: k.$2, courtCount: 1).label),
                        ),
                    ],
                    onChanged: (k) {
                      if (k != null) {
                        setState(() {
                          _sport = k.$1;
                          _type = k.$2;
                        });
                      }
                    },
                  ),
                Row(
                  children: [
                    const Expanded(child: Text(OwnerFacilityStrings.courtCount)),
                    CountStepper(value: _count, onChanged: (n) => setState(() => _count = n)),
                  ],
                ),
              ],
            ),
            FormSection(
              title: OwnerFacilityStrings.slotDuration,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in CourtPricing.slotOptions)
                      ChoiceChip(
                        label: Text(OwnerFacilityStrings.minutes(m)),
                        selected: _slot == m,
                        selectedColor: AppColors.lightGreen,
                        onSelected: (_) => setState(() => _slot = m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(OwnerFacilityStrings.peakHours, style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TimeField(
                        label: OwnerFacilityStrings.peakFrom,
                        minutes: _peakStart,
                        onChanged: (m) => setState(() => _peakStart = m),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TimeField(
                        label: OwnerFacilityStrings.peakTo,
                        minutes: _peakEnd,
                        onChanged: (m) => setState(() => _peakEnd = m),
                      ),
                    ),
                  ],
                ),
                if (!_peakValid)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(OwnerFacilityStrings.invalidPeak, style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            FormSection(
              title: OwnerFacilityStrings.weekday,
              children: [
                Row(
                  children: [
                    Expanded(child: _priceField(OwnerFacilityStrings.normalPrice, _weekday)),
                    const SizedBox(width: 12),
                    Expanded(child: _priceField(OwnerFacilityStrings.peakPrice, _weekdayPeak)),
                  ],
                ),
              ],
            ),
            FormSection(
              title: OwnerFacilityStrings.weekend,
              children: [
                Row(
                  children: [
                    Expanded(child: _priceField(OwnerFacilityStrings.normalPrice, _weekend)),
                    const SizedBox(width: 12),
                    Expanded(child: _priceField(OwnerFacilityStrings.peakPrice, _weekendPeak)),
                  ],
                ),
              ],
            ),
            if (pricing != null)
              FormSection(
                title: OwnerFacilityStrings.preview,
                children: [
                  if (starts.isEmpty)
                    const Text(OwnerFacilityStrings.noSlots, style: TextStyle(color: AppColors.textSecondary))
                  else ...[
                    _previewDay(OwnerFacilityStrings.previewWeekday, nextWeekday, starts, pricing),
                    const SizedBox(height: 12),
                    _previewDay(OwnerFacilityStrings.previewWeekend, nextWeekend, starts, pricing),
                  ],
                ],
              ),
            if (!_isNew)
              OutlinedButton.icon(
                onPressed: _saving ? null : _lock,
                icon: const Icon(Icons.lock_outline),
                label: const Text(OwnerFacilityStrings.lockCourt),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SubmitBar(label: OwnerFacilityStrings.save, busy: _saving, onPressed: _save),
    );
  }

  Widget _previewDay(String title, DateTime day, List<int> starts, CourtPricing pricing) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in starts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: pricing.isPeak(m) ? AppColors.tagOrangeBg : AppColors.lightGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${formatMinutes(m)} - ${formatMinutes(m + pricing.slotMinutes)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    Formatters.currency(pricing.priceAt(day, m)),
                    style: TextStyle(
                      fontSize: 11,
                      color: pricing.isPeak(m) ? AppColors.tagOrangeText : AppColors.darkGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}
