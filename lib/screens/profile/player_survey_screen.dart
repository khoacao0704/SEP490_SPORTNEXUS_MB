import 'package:flutter/material.dart';

import '../../core/services/location_service.dart';
import '../../core/strings/survey_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/onboarding_gate.dart';
import '../../data/repositories/player_profile_repository.dart';
import '../../models/player_survey.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';

/// Khảo sát người chơi 4 bước: môn + trình độ → lịch rảnh → khu vực & giá → mục tiêu.
///
/// [mandatory]: người chơi chưa làm khảo sát (sau đăng nhập / BE báo ONBOARDING_REQUIRED) — không quay lại được,
/// chỉ có Đăng xuất; xong thì gọi [onCompleted]. Không bắt buộc (sửa từ Hồ sơ): xong thì pop `true`.
class PlayerSurveyScreen extends StatefulWidget {
  final bool mandatory;
  final void Function(BuildContext context)? onCompleted;
  final void Function(BuildContext context)? onLogout;

  const PlayerSurveyScreen({super.key, this.mandatory = false, this.onCompleted, this.onLogout});

  /// Giá sân tối đa chọn nhanh; `null` = không giới hạn.
  static const List<int?> priceOptions = [null, 150000, 250000, 400000, 600000];

  @override
  State<PlayerSurveyScreen> createState() => _PlayerSurveyScreenState();
}

class _PlayerSurveyScreenState extends State<PlayerSurveyScreen> {
  static const int _steps = 4;

  PlayerSurvey? _survey;
  bool _loadFailed = false;
  bool _saving = false;
  bool _locating = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final survey = await AppRepositories.playerProfile.getSurvey();
      if (mounted) setState(() => _survey = survey);
    } on PlayerProfileException {
      if (!mounted) return;
      // Bắt buộc: vẫn cho làm từ đầu; sửa từ Hồ sơ: báo lỗi, cho thử lại.
      setState(() => widget.mandatory ? _survey = const PlayerSurvey() : _loadFailed = true);
    }
  }

  void _update(PlayerSurvey survey) => setState(() => _survey = survey);

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
  }

  /// Lỗi của bước hiện tại; `null` = hợp lệ.
  String? _stepError(PlayerSurvey s) => switch (_step) {
    0 => s.sports.isEmpty ? SurveyStrings.needSport : null,
    1 => s.availability.isEmpty ? SurveyStrings.needWindow : null,
    3 => s.goal == null || s.frequency == null ? SurveyStrings.needGoal : null,
    _ => null,
  };

  Future<void> _next() async {
    final s = _survey!;
    final error = _stepError(s);
    if (error != null) return _snack(error);
    if (_step < _steps - 1) return setState(() => _step++);

    setState(() => _saving = true);
    try {
      await AppRepositories.playerProfile.saveSurvey(s);
      await OnboardingGate.markCompleted();
      if (!mounted) return;
      _snack(widget.mandatory ? SurveyStrings.completed : SurveyStrings.saved);
      if (widget.onCompleted != null) {
        widget.onCompleted!(context);
      } else {
        Navigator.pop(context, true);
      }
    } on PlayerProfileException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message, error: true);
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final result = await const LocationService().getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    final point = result.point;
    if (point == null) return _snack(SurveyStrings.locationFailed);
    _update(_survey!.copyWith(latitude: point.latitude, longitude: point.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final survey = _survey;
    return PopScope(
      canPop: !widget.mandatory && _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          automaticallyImplyLeading: !widget.mandatory || _step > 0,
          leading: _step > 0 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--)) : null,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: Text(
            widget.mandatory ? SurveyStrings.title : SurveyStrings.editTitle,
            style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (widget.mandatory && widget.onLogout != null)
              TextButton(
                onPressed: _saving ? null : () => widget.onLogout!(context),
                child: const Text(SurveyStrings.logout),
              ),
          ],
        ),
        body: survey == null
            ? Center(
                child: _loadFailed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(SurveyStrings.loadError),
                          TextButton(onPressed: _load, child: const Text(SurveyStrings.retry)),
                        ],
                      )
                    : const CircularProgressIndicator(),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.mandatory && _step == 0) ...[
                    const Text(SurveyStrings.intro, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    SurveyStrings.step(_step + 1, _steps),
                    style: const TextStyle(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (_step + 1) / _steps,
                    color: AppColors.primaryGreen,
                    backgroundColor: AppColors.divider,
                  ),
                  const SizedBox(height: 16),
                  ...switch (_step) {
                    0 => _sportsStep(survey),
                    1 => _availabilityStep(survey),
                    2 => _areaStep(survey),
                    _ => _goalStep(survey),
                  },
                ],
              ),
        bottomNavigationBar: survey == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.authPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                          : Text(
                              _step < _steps - 1
                                  ? SurveyStrings.next
                                  : widget.mandatory
                                      ? SurveyStrings.finish
                                      : SurveyStrings.save,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ---------------- Bước 1: môn + trình độ ----------------

  List<Widget> _sportsStep(PlayerSurvey s) {
    final selected = {for (final x in s.sports) x.sport: x};
    return [
      _title(SurveyStrings.sportsTitle, SurveyStrings.sportsHint),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final sport in Sport.values)
            FilterChip(
              label: Text(sport.label),
              selected: selected.containsKey(sport),
              onSelected: (on) => _update(
                s.copyWith(
                  sports: on
                      ? [...s.sports, SurveySport(sport: sport, level: SkillLevel.beginner)]
                      : s.sports.where((x) => x.sport != sport).toList(),
                ),
              ),
            ),
        ],
      ),
      for (final item in s.sports) ...[const SizedBox(height: 16), _sportCard(s, item)],
    ];
  }

  Widget _sportCard(PlayerSurvey s, SurveySport item) {
    void replace(SurveySport next) =>
        _update(s.copyWith(sports: [for (final x in s.sports) x.sport == item.sport ? next : x]));
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.sport.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(SurveyStrings.level, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final level in SkillLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: item.level == level,
                  onSelected: (_) => replace(item.copyWith(level: level)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(SurveyStrings.formats, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in PlayFormat.optionsFor(item.sport))
                FilterChip(
                  label: Text(f.label),
                  selected: item.formats.contains(f.apiValue),
                  onSelected: (on) => replace(
                    item.copyWith(
                      formats: on ? [...item.formats, f.apiValue] : item.formats.where((x) => x != f.apiValue).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Bước 2: lịch rảnh ----------------

  List<Widget> _availabilityStep(PlayerSurvey s) => [
    _title(SurveyStrings.availabilityTitle, SurveyStrings.availabilityHint),
    if (s.availability.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(SurveyStrings.noWindows, style: TextStyle(color: AppColors.textSecondary)),
      )
    else
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final w in s.availability)
            InputChip(
              label: Text(w.label),
              onDeleted: () => _update(s.copyWith(availability: s.availability.where((x) => x != w).toList())),
            ),
        ],
      ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: s.availability.length >= PlayerSurvey.maxWindows ? null : () => _addWindows(s),
        icon: const Icon(Icons.add),
        label: const Text(SurveyStrings.addWindow),
      ),
    ),
  ];

  Future<void> _addWindows(PlayerSurvey s) async {
    final windows = await showModalBottomSheet<List<AvailabilityWindow>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddWindowSheet(),
    );
    if (windows == null || windows.isEmpty || !mounted) return;
    final current = _survey!;
    if (windows.any((w) => current.availability.any(w.overlaps))) return _snack(SurveyStrings.windowOverlap);
    if (current.availability.length + windows.length > PlayerSurvey.maxWindows) {
      return _snack(SurveyStrings.tooManyWindows(PlayerSurvey.maxWindows));
    }
    _update(
      current.copyWith(availability: [...current.availability, ...windows]..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
    );
  }

  // ---------------- Bước 3: khu vực & giá ----------------

  List<Widget> _areaStep(PlayerSurvey s) => [
    _title(SurveyStrings.areaTitle, SurveyStrings.areaHint),
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.hasLocation)
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                const Expanded(child: Text(SurveyStrings.locationSet)),
                TextButton(
                  onPressed: () => _update(s.copyWith(clearLocation: true)),
                  child: const Text(SurveyStrings.clearLocation),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(_locating ? SurveyStrings.locating : SurveyStrings.useLocation),
            ),
          const SizedBox(height: 12),
          Text(SurveyStrings.radius(s.radiusKm), style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.radiusKm.toDouble(),
            min: PlayerSurvey.minRadiusKm.toDouble(),
            max: PlayerSurvey.maxRadiusKm.toDouble(),
            divisions: PlayerSurvey.maxRadiusKm - PlayerSurvey.minRadiusKm,
            label: '${s.radiusKm} km',
            activeColor: AppColors.primaryGreen,
            onChanged: (v) => _update(s.copyWith(radiusKm: v.round())),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    const Text(SurveyStrings.maxPrice, style: TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final price in PlayerSurveyScreen.priceOptions)
          ChoiceChip(
            label: Text(price == null ? SurveyStrings.noPriceLimit : Formatters.vnd(price)),
            selected: s.maxPricePerHour == price,
            onSelected: (_) =>
                _update(price == null ? s.copyWith(clearMaxPrice: true) : s.copyWith(maxPricePerHour: price)),
          ),
      ],
    ),
  ];

  // ---------------- Bước 4: mục tiêu ----------------

  List<Widget> _goalStep(PlayerSurvey s) => [
    _title(SurveyStrings.goalTitle, null),
    _choices<PlayGoal>(SurveyStrings.goal, PlayGoal.values, s.goal, (g) => g.label, (g) => _update(s.copyWith(goal: g))),
    const SizedBox(height: 16),
    _choices<PlayFrequency>(
      SurveyStrings.frequency,
      PlayFrequency.values,
      s.frequency,
      (f) => f.label,
      (f) => _update(s.copyWith(frequency: f)),
    ),
    const SizedBox(height: 16),
    _choices<Gender>(
      SurveyStrings.gender,
      Gender.values,
      s.gender,
      (g) => g.label,
      (g) => _update(s.gender == g ? s.copyWith(clearGender: true) : s.copyWith(gender: g)),
    ),
  ];

  Widget _choices<T>(String label, List<T> values, T? selected, String Function(T) labelOf, void Function(T) onTap) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(label: Text(labelOf(v)), selected: selected == v, onSelected: (_) => onTap(v)),
            ],
          ),
        ],
      );

  Widget _title(String title, String? hint) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ],
    ),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );
}

/// Chọn các ngày + giờ bắt đầu / kết thúc → mỗi ngày một khung giờ.
class _AddWindowSheet extends StatefulWidget {
  const _AddWindowSheet();

  @override
  State<_AddWindowSheet> createState() => _AddWindowSheetState();
}

class _AddWindowSheetState extends State<_AddWindowSheet> {
  final Set<int> _days = {};
  DayTime _start = DayTime.hm(18, 0);
  DayTime _end = DayTime.hm(21, 0);
  String? _error;

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    setState(() {
      final value = DayTime.hm(picked.hour, picked.minute);
      start ? _start = value : _end = value;
      _error = null;
    });
  }

  void _submit() {
    if (_days.isEmpty) return setState(() => _error = SurveyStrings.needDay);
    if (_end.compareTo(_start) <= 0) return setState(() => _error = SurveyStrings.endAfterStart);
    final days = AvailabilityWindow.weekOrder.where(_days.contains);
    Navigator.pop(context, [for (final d in days) AvailabilityWindow(dayOfWeek: d, start: _start, end: _end)]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(SurveyStrings.addWindow, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(SurveyStrings.days, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in AvailabilityWindow.weekOrder)
                  FilterChip(
                    label: Text(AvailabilityWindow.dayLabel(d)),
                    selected: _days.contains(d),
                    onSelected: (on) => setState(() {
                      on ? _days.add(d) : _days.remove(d);
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => _pick(true), child: Text('${SurveyStrings.from} ${_start.hhmm}')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(onPressed: () => _pick(false), child: Text('${SurveyStrings.to} ${_end.hhmm}')),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text(SurveyStrings.cancel)),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _submit, child: const Text(SurveyStrings.add)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
