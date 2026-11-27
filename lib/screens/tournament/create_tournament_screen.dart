import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/tournament_rules.dart';
import '../../core/strings/organizer_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/organized_tournament.dart';
import '../../models/owner_court.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';

/// Chọn file PDF: trả về đường dẫn trên máy (rỗng nếu hủy). Thay được trong test.
typedef PdfPicker = Future<List<String>> Function({required bool multiple});

Future<List<String>> defaultPdfPicker({required bool multiple}) async {
  if (multiple) {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    return [for (final f in files) ?f.path];
  }
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
  return [?file?.path];
}

/// Form tạo giải dùng chung (luồng 26/11 mục 1). Người chơi chọn cơ sở và có ô hợp đồng;
/// chủ sân truyền [fixedFacility] (cơ sở đang quản lý), không có ô hợp đồng. Mọi giải chờ Admin duyệt.
class CreateTournamentScreen extends StatefulWidget {
  final FacilityOption? fixedFacility;
  final PdfPicker? pickPdf;
  final DateTime Function()? now;

  const CreateTournamentScreen({super.key, this.fixedFacility, this.pickPdf, this.now});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _PrizeRow {
  final TextEditingController position;
  final TextEditingController amount = TextEditingController();

  _PrizeRow([String name = '']) : position = TextEditingController(text: name);

  void dispose() {
    position.dispose();
    amount.dispose();
  }
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _name = TextEditingController();
  final _facilityQuery = TextEditingController();
  final _minRating = TextEditingController();
  final _maxRating = TextEditingController();
  final _minRatedMatches = TextEditingController();
  final _max = TextEditingController(text: '8');
  final _fee = TextEditingController();
  final _description = TextEditingController();
  final List<_PrizeRow> _prizes = [_PrizeRow(OrganizerStrings.champion)];

  List<FacilityOption> _facilities = const [];
  FacilityOption? _facility;
  List<SportCategory> _sports = const [];
  bool _sportsError = false;
  String? _categoryId;
  DateTime? _start;
  DateTime? _end;
  DateTime? _deadline;
  TournamentTier _tier = TournamentTier.amateur;
  TournamentPurpose _purpose = TournamentPurpose.exchange;
  DivisionType _type = DivisionType.singles;

  /// null = theo gợi ý từ số người tối đa.
  BracketFormat? _format;
  final List<CourtScheduleRequest> _schedule = [];
  final List<TournamentDocument> _rulesFiles = [];
  TournamentDocument? _contract;
  String? _uploading;
  bool _busy = false;

  bool get _isPlayer => widget.fixedFacility == null;
  DateTime _now() => (widget.now ?? DateTime.now)();
  int get _maxCount => int.tryParse(_max.text.trim()) ?? 0;
  BracketFormat get _effectiveFormat => _format ?? TournamentRules.suggestFormat(_maxCount);

  @override
  void initState() {
    super.initState();
    _facility = widget.fixedFacility;
    _loadSports();
    if (_isPlayer) _loadFacilities();
  }

  @override
  void dispose() {
    for (final c in [_name, _facilityQuery, _minRating, _maxRating, _minRatedMatches, _max, _fee, _description]) {
      c.dispose();
    }
    for (final p in _prizes) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSports() async {
    setState(() => _sportsError = false);
    try {
      final sports = await AppRepositories.hostTournament.getSports();
      if (!mounted) return;
      setState(() {
        _sports = sports;
        _categoryId ??= sports.isEmpty ? null : sports.first.id;
      });
    } catch (_) {
      if (mounted) setState(() => _sportsError = true);
    }
  }

  Future<void> _loadFacilities() async {
    try {
      final list = await AppRepositories.hostTournament.getFacilities();
      if (mounted) setState(() => _facilities = list);
    } catch (_) {}
  }

  void _toast(String text, {bool error = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
  }

  // ---------------- Ngày ----------------

  Future<DateTime?> _pick(DateTime? current, DateTime first, DateTime last) {
    if (last.isBefore(first)) last = first;
    var initial = current ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    return showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
  }

  Future<void> _pickStart() async {
    final today = _now();
    final first = TournamentRules.minStart(today);
    final picked = await _pick(_start, first, first.add(const Duration(days: 365)));
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end != null && (_end!.isBefore(picked) || _end!.isAfter(TournamentRules.maxEnd(picked)))) _end = null;
      final def = TournamentRules.defaultDeadline(picked);
      if (_deadline == null || _deadline!.isAfter(def)) _deadline = def;
    });
  }

  Future<void> _pickEnd() async {
    final s = _start;
    final first = s ?? TournamentRules.minStart(_now());
    final picked = await _pick(
      _end,
      first,
      s == null ? first.add(const Duration(days: 365)) : TournamentRules.maxEnd(s),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _pickDeadline() async {
    final today = _now();
    final first = DateTime(today.year, today.month, today.day);
    final s = _start;
    final picked = await _pick(
      _deadline,
      first,
      s == null ? first.add(const Duration(days: 365)) : TournamentRules.maxDeadline(s),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  // ---------------- PDF ----------------

  Future<void> _addDocuments(bool contract) async {
    final paths = await (widget.pickPdf ?? defaultPdfPicker)(multiple: !contract);
    if (paths.isEmpty || !mounted) return;
    if (paths.any((p) => !p.toLowerCase().endsWith('.pdf'))) {
      _toast(OrganizerStrings.pdfOnly);
      return;
    }
    setState(() => _uploading = contract ? 'contract' : 'rules');
    try {
      for (final path in contract ? paths.take(1) : paths) {
        final url = await AppRepositories.hostTournament.uploadDocument(path);
        final doc = TournamentDocument(url: url, name: path.split(RegExp(r'[\\/]')).last);
        if (!mounted) return;
        setState(() => contract ? _contract = doc : _rulesFiles.add(doc));
      }
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  // ---------------- Gửi ----------------

  String? _validate() {
    if (_name.text.trim().isEmpty) return OrganizerStrings.nameRequired;
    if (_maxCount < TournamentRules.minParticipants) return OrganizerStrings.maxCountTooSmall;
    if (_categoryId == null) return OrganizerStrings.sportRequired;
    if (_facility == null) return OrganizerStrings.facilityRequired;
    if (_purpose == TournamentPurpose.development && _tier == TournamentTier.amateur) {
      return OrganizerStrings.developmentNeedsRated;
    }
    final dateError = TournamentRules.validateDates(start: _start, end: _end, deadline: _deadline, today: _now());
    if (dateError != null) return dateError;
    final fe = TournamentRules.formatError(_effectiveFormat, _maxCount);
    if (fe != null) return OrganizerStrings.formatFix(fe);
    final se = TournamentRules.validateSchedule(_schedule, start: _start, end: _end);
    if (se != null) return se;
    if (_tier != TournamentTier.amateur) {
      final values = [_minRating, _maxRating, _minRatedMatches].map((c) => int.tryParse(c.text.trim())).toList();
      if (values.any((v) => v == null)) return OrganizerStrings.ratingRequired;
      if (values[0]! > values[1]!) return OrganizerStrings.ratingOrder;
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      _toast(error);
      return;
    }
    final rated = _tier != TournamentTier.amateur;
    final draft = NewTournament(
      facilityId: _facility!.id,
      categoryId: _categoryId!,
      name: _name.text,
      start: _start!,
      end: _end!,
      deadline: _deadline,
      description: _description.text,
      tier: _tier,
      purpose: _purpose,
      minRating: rated ? int.tryParse(_minRating.text.trim()) : null,
      maxRating: rated ? int.tryParse(_maxRating.text.trim()) : null,
      minRatedMatches: rated ? int.tryParse(_minRatedMatches.text.trim()) : null,
      format: _effectiveFormat,
      type: _type,
      maxParticipants: _maxCount,
      entryFee: ThousandsInputFormatter.parse(_fee.text),
      prizes: [
        for (final p in _prizes)
          OrganizerPrize(position: p.position.text, amount: ThousandsInputFormatter.parse(p.amount.text)),
      ],
      rulesFiles: List.of(_rulesFiles),
      contract: _isPlayer ? _contract : null,
      schedule: List.of(_schedule),
    );
    setState(() => _busy = true);
    try {
      final approval = await AppRepositories.hostTournament.create(draft);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              approval == ApprovalStatus.approved ? OrganizerStrings.submittedApproved : OrganizerStrings.submitted,
            ),
          ),
        );
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------- Giao diện ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OrganizerStrings.createTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _facilitySection(),
            _gap,
            _field(OrganizerStrings.name, TextField(controller: _name, maxLength: 200, decoration: _input())),
            _sportField(),
            _gap,
            _dateRow(OrganizerStrings.start, _start, _pickStart),
            _dateRow(OrganizerStrings.end, _end, _pickEnd),
            _dateRow(OrganizerStrings.deadline, _deadline, _pickDeadline),
            _gap,
            _tierSection(),
            _gap,
            _purposeField(),
            _gap,
            _typeField(),
            _gap,
            _field(
              OrganizerStrings.maxCount(_type == DivisionType.premadeTeams),
              TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _input(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _gap,
            _formatField(),
            _gap,
            _scheduleSection(),
            _gap,
            _field(
              OrganizerStrings.entryFee,
              TextField(
                controller: _fee,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: _input(hint: '0'),
              ),
            ),
            _gap,
            _prizeSection(),
            _gap,
            _field(
              OrganizerStrings.description,
              TextField(controller: _description, maxLines: 4, maxLength: 4000, decoration: _input()),
            ),
            _documentGroup(
              title: OrganizerStrings.documents,
              hint: OrganizerStrings.documentsHint,
              files: _rulesFiles,
              multiple: true,
              onRemove: (d) => setState(() => _rulesFiles.remove(d)),
            ),
            if (_isPlayer) ...[
              _gap,
              _documentGroup(
                title: OrganizerStrings.contract,
                hint: OrganizerStrings.contractHint,
                files: [?_contract],
                multiple: false,
                onRemove: (_) => setState(() => _contract = null),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy || _uploading != null ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(OrganizerStrings.submit, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const Widget _gap = SizedBox(height: 14);

  InputDecoration _input({String? hint}) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppColors.white,
    counterText: '',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
    ),
  );

  Widget _hint(String text, {Color color = AppColors.textSecondary}) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: TextStyle(fontSize: 12, color: color)),
  );

  Widget _field(String label, Widget child) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(label), child]);

  Widget _facilitySection() {
    final f = _facility;
    if (f != null) {
      return _field(
        OrganizerStrings.facility,
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    if (f.address.isNotEmpty)
                      Text(f.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (_isPlayer)
                TextButton(
                  onPressed: () => setState(() {
                    _facility = null;
                    _facilityQuery.clear();
                  }),
                  child: const Text(OrganizerStrings.change),
                ),
            ],
          ),
        ),
      );
    }
    final query = _facilityQuery.text.trim();
    final hits = query.isEmpty
        ? const <FacilityOption>[]
        : TournamentRules.matchFacilities(_facilities, query).take(6).toList();
    return _field(
      OrganizerStrings.facility,
      Column(
        children: [
          TextField(
            controller: _facilityQuery,
            decoration: _input(hint: OrganizerStrings.facilityHint).copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
          if (query.isNotEmpty)
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              child: hits.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(OrganizerStrings.facilityNone, style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : Column(
                      children: [
                        for (final h in hits)
                          ListTile(
                            dense: true,
                            title: Text(h.name),
                            subtitle: h.address.isEmpty ? null : Text(h.address),
                            onTap: () => setState(() => _facility = h),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _sportField() {
    if (_sportsError) {
      return Row(
        children: [
          const Expanded(
            child: Text(OrganizerStrings.sportsError, style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: _loadSports, child: const Text(OrganizerStrings.retry)),
        ],
      );
    }
    return _field(
      OrganizerStrings.sport,
      DropdownButtonFormField<String>(
        initialValue: _categoryId,
        isExpanded: true,
        decoration: _input(),
        items: [for (final s in _sports) DropdownMenuItem(value: s.id, child: Text(s.name))],
        onChanged: (v) => setState(() => _categoryId = v),
      ),
    );
  }

  Widget _dateRow(String label, DateTime? value, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(value == null ? OrganizerStrings.pickDate : Formatters.date(value)),
        ),
      ],
    ),
  );

  Widget _tierSection() {
    final rated = _tier != TournamentTier.amateur;
    Widget num(TextEditingController c, String label) => Expanded(
      child: _field(
        label,
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _input(),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          OrganizerStrings.tier,
          DropdownButtonFormField<TournamentTier>(
            initialValue: _tier,
            isExpanded: true,
            decoration: _input(),
            items: [for (final t in TournamentTier.values) DropdownMenuItem(value: t, child: Text(t.label))],
            onChanged: (v) => setState(() {
              _tier = v ?? TournamentTier.amateur;
              if (_tier == TournamentTier.amateur && _purpose == TournamentPurpose.development) {
                _purpose = TournamentPurpose.exchange;
              }
            }),
          ),
        ),
        _hint(rated ? OrganizerStrings.tierRatedHint : OrganizerStrings.tierAmateurHint),
        if (rated) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              num(_minRating, OrganizerStrings.minRating),
              const SizedBox(width: 8),
              num(_maxRating, OrganizerStrings.maxRating),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [num(_minRatedMatches, OrganizerStrings.minRatedMatches)]),
        ],
      ],
    );
  }

  String _purposeLabel(TournamentPurpose p) => switch (p) {
    TournamentPurpose.development => OrganizerStrings.purposeDevelopmentNote,
    TournamentPurpose.internal => OrganizerStrings.purposeInternalNote,
    _ => p.label,
  };

  Widget _purposeField() => _field(
    OrganizerStrings.purpose,
    DropdownButtonFormField<TournamentPurpose>(
      key: ValueKey('purpose-${_tier.name}'),
      initialValue: _purpose,
      isExpanded: true,
      decoration: _input(),
      items: [
        for (final p in TournamentPurpose.values)
          DropdownMenuItem(
            value: p,
            enabled: !(p == TournamentPurpose.development && _tier == TournamentTier.amateur),
            child: Text(
              _purposeLabel(p),
              style: p == TournamentPurpose.development && _tier == TournamentTier.amateur
                  ? const TextStyle(color: AppColors.textSecondary)
                  : null,
            ),
          ),
      ],
      onChanged: (v) => setState(() => _purpose = v ?? TournamentPurpose.exchange),
    ),
  );

  Widget _typeField() => _field(
    OrganizerStrings.type,
    DropdownButtonFormField<DivisionType>(
      initialValue: _type,
      isExpanded: true,
      decoration: _input(),
      items: [for (final t in DivisionType.values) DropdownMenuItem(value: t, child: Text(t.label))],
      onChanged: (v) => setState(() => _type = v ?? DivisionType.singles),
    ),
  );

  Widget _formatField() {
    final suggestion = TournamentRules.suggestFormat(_maxCount);
    final f = _effectiveFormat;
    final error = _maxCount >= 2 ? TournamentRules.formatError(f, _maxCount) : null;
    final warning = error == null ? TournamentRules.formatWarning(f, _maxCount) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          OrganizerStrings.format,
          DropdownButtonFormField<BracketFormat>(
            key: ValueKey('format-${_format?.name}-${suggestion.name}'),
            initialValue: f,
            isExpanded: true,
            decoration: _input(),
            items: [
              for (final b in BracketFormat.values)
                DropdownMenuItem(
                  value: b,
                  child: Text('${b.label}${b == suggestion ? OrganizerStrings.suggested : ''}'),
                ),
            ],
            onChanged: (v) => setState(() => _format = v),
          ),
        ),
        _hint(OrganizerStrings.formatLocked),
        if (error != null) _hint(error, color: Colors.red),
        if (warning != null) _hint(warning, color: const Color(0xFFB45309)),
        if (error == null && _maxCount >= 2)
          _hint(OrganizerStrings.estimate(TournamentRules.estimateMatches(f, _maxCount))),
      ],
    );
  }

  Future<void> _pickRowDate(int index) async {
    final s = _start;
    if (s == null) return;
    final picked = await _pick(_schedule[index].date, s, _end ?? s);
    if (picked != null) setState(() => _schedule[index] = _schedule[index].copyWith(date: picked));
  }

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(OrganizerStrings.schedule),
        _hint(OrganizerStrings.scheduleHint),
        const SizedBox(height: 8),
        for (var i = 0; i < _schedule.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickRowDate(i),
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(
                          _schedule[i].date == null ? OrganizerStrings.day : Formatters.date(_schedule[i].date!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: OrganizerStrings.change,
                      icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _schedule.removeAt(i)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<CourtSession>(
                        initialValue: _schedule[i].session,
                        isExpanded: true,
                        decoration: _input().copyWith(labelText: OrganizerStrings.session),
                        items: [
                          for (final s in CourtSession.values)
                            DropdownMenuItem(
                              value: s,
                              child: Text(s.label, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => _schedule[i] = _schedule[i].copyWith(session: v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: '${_schedule[i].courtCount}',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _input().copyWith(labelText: OrganizerStrings.courtCount),
                        onChanged: (v) => _schedule[i] = _schedule[i].copyWith(courtCount: int.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _start == null ? null : () => setState(() => _schedule.add(CourtScheduleRequest(date: _start))),
          icon: const Icon(Icons.add),
          label: const Text(OrganizerStrings.addScheduleRow),
        ),
      ],
    );
  }

  Widget _prizeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(OrganizerStrings.prizes),
      for (final p in List.of(_prizes))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: p.position,
                  decoration: _input(hint: OrganizerStrings.prizePosition),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: p.amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: _input(hint: OrganizerStrings.prizeAmount),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _prizes.remove(p);
                  p.dispose();
                }),
              ),
            ],
          ),
        ),
      TextButton.icon(
        onPressed: () => setState(() => _prizes.add(_PrizeRow())),
        icon: const Icon(Icons.add),
        label: const Text(OrganizerStrings.addPrize),
      ),
    ],
  );

  Widget _documentGroup({
    required String title,
    required String hint,
    required List<TournamentDocument> files,
    required bool multiple,
    required void Function(TournamentDocument) onRemove,
  }) {
    final kind = multiple ? 'rules' : 'contract';
    final busy = _uploading != null;
    final buttonText = _uploading == kind
        ? OrganizerStrings.uploading
        : files.isEmpty
        ? OrganizerStrings.uploadPdf
        : multiple
        ? OrganizerStrings.addFile
        : OrganizerStrings.changeFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(title),
        _hint(hint),
        const SizedBox(height: 6),
        for (final d in files)
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(d.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                onPressed: busy ? null : () => onRemove(d),
              ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _addDocuments(!multiple),
          icon: const Icon(Icons.upload_file, size: 18),
          label: Text(buttonText),
        ),
      ],
    );
  }
}
