import 'package:flutter/material.dart';

import '../../core/strings/common_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/strings/owner_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/court_type.dart';
import '../../models/owner_facility.dart';
import '../../models/sport.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_form.dart';

/// Tạo giải ([tournament] `null`) hoặc sửa giải. Đã có người đăng ký thì chỉ sửa mô tả, giải thưởng, điều lệ.
/// Pop trả về [Tournament] sau khi lưu.
class TournamentFormScreen extends StatefulWidget {
  final Tournament? tournament;

  const TournamentFormScreen({super.key, this.tournament});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Tournament? _t = widget.tournament;
  late final bool _locked = (_t?.entries.isNotEmpty) ?? false;

  late final _name = TextEditingController(text: _t?.name);
  late final _fee = TextEditingController(text: _t == null ? '' : Formatters.currency(_t.entryFee));
  late final _description = TextEditingController(text: _t?.description);

  List<OwnerFacility> _facilities = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  String? _facilityId;
  late Sport _sport = _t?.sport ?? Sport.badminton;
  late CourtType _courtType = _t?.courtType ?? CourtType.standard;
  late TournamentEntryType _entryType = _t?.entryType ?? TournamentEntryType.single;
  late int _maxMembers = _t?.maxMembers ?? 1;
  late int _maxEntries = _t?.maxEntries ?? 8;
  late DateTime _deadline;
  late DateTime _start;
  late DateTime _end;
  late List<TournamentPrize> _prizes = [...?_t?.prizes];
  late List<String> _rules = _t == null ? [...OwnerTournamentStrings.defaultRules] : [..._t.rules];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    _deadline = _t?.registrationDeadline ?? d.add(const Duration(days: 7, hours: 23, minutes: 59));
    _start = _t?.startDate ?? d.add(const Duration(days: 10, hours: 7));
    _end = _t?.endDate ?? d.add(const Duration(days: 10, hours: 18));
    _facilityId = _t?.facilityId;
    _loadFacilities();
  }

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await AppRepositories.owner.getOwnerFacilities();
      if (!mounted) return;
      setState(() {
        // Khi sửa giải: giữ cơ sở của giải dù loại sân của nó đã bị khóa sau đó.
        _facilities = all
            .where((f) => f.isApproved && (f.activeCourts.isNotEmpty || f.id == _t?.facilityId))
            .toList();
        _loading = false;
        if (_facilityId == null && _facilities.isNotEmpty) _selectFacility(_facilities.first.id);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = CommonStrings.genericError;
        });
      }
    }
  }

  OwnerFacility? get _facility => _facilities.where((f) => f.id == _facilityId).firstOrNull;

  /// Đang sửa giải trên chính cơ sở / môn / loại sân của giải: luôn giữ giá trị hiện tại trong danh sách chọn.
  bool get _onOriginalFacility => _t != null && _facilityId == _t.facilityId;

  List<Sport> get _sports {
    final list = (_facility?.activeCourts.map((c) => c.sport).toSet().toList()) ?? <Sport>[];
    if (_onOriginalFacility && !list.contains(_t!.sport)) list.add(_t.sport);
    return list;
  }

  List<CourtType> get _courtTypes {
    final list = _facility?.activeCourts.where((c) => c.sport == _sport).map((c) => c.courtType).toList() ?? <CourtType>[];
    if (_onOriginalFacility && _sport == _t!.sport && !list.contains(_t.courtType)) list.add(_t.courtType);
    return list;
  }

  void _selectFacility(String id) {
    _facilityId = id;
    final sports = _sports;
    _selectSport(sports.contains(_sport) ? _sport : sports.first);
  }

  void _selectSport(Sport s) {
    _sport = s;
    final types = _courtTypes;
    _courtType = types.contains(_courtType) ? _courtType : types.first;
    final entryTypes = TournamentDraft.entryTypesFor(s);
    if (!entryTypes.contains(_entryType)) _entryType = entryTypes.first;
    _fixMembers();
  }

  int get _minMembers => switch (_entryType) {
    TournamentEntryType.single => 1,
    TournamentEntryType.pair => 2,
    TournamentEntryType.team => _courtType.playersPerTeam,
  };

  void _fixMembers() {
    final min = _minMembers;
    _maxMembers = _entryType == TournamentEntryType.team ? _maxMembers.clamp(min, min * 2) : min;
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _addPrize() async {
    final prize = await showDialog<TournamentPrize>(context: context, builder: (_) => const _PrizeDialog());
    if (prize != null) setState(() => _prizes = [..._prizes, prize]);
  }

  Future<void> _addRule() async {
    final rule = await showTextPrompt(
      context,
      title: OwnerTournamentStrings.addRule,
      confirmLabel: OwnerTournamentStrings.add,
      cancelLabel: OwnerTournamentStrings.cancel,
    );
    if (rule != null) setState(() => _rules = [..._rules, rule]);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _facilityId == null) return;
    final draft = TournamentDraft(
      name: _name.text,
      facilityId: _facilityId!,
      sport: _sport,
      courtType: _courtType,
      entryType: _entryType,
      minMembers: _minMembers,
      maxMembers: _maxMembers,
      maxEntries: _maxEntries,
      entryFee: ThousandsInputFormatter.parse(_fee.text),
      registrationDeadline: _deadline,
      startDate: _start,
      endDate: _end,
      description: _description.text,
      prizes: _prizes,
      rules: _rules,
    );
    setState(() => _saving = true);
    try {
      final repo = AppRepositories.organizer;
      final t = _t;
      final saved = t == null ? await repo.createTournament(draft) : await repo.updateTournament(t.id, draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t == null ? OwnerTournamentStrings.created : OwnerTournamentStrings.saved)),
      );
      Navigator.pop(context, saved);
    } on TournamentException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  String _dateLabel(DateTime d) => '${Formatters.weekdayDayMonth(d)}/${d.year} • ${Formatters.time(d)}';

  @override
  Widget build(BuildContext context) {
    final isNew = _t == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          isNew ? OwnerTournamentStrings.createTitle : OwnerTournamentStrings.editTitle,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _loadFacilities, child: const Text(OwnerStrings.retry)),
                ],
              ),
            )
          : _facilities.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(OwnerTournamentStrings.noFacility, textAlign: TextAlign.center),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_locked)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.tagOrangeBg, borderRadius: BorderRadius.circular(12)),
                      child: const Text(
                        OwnerTournamentStrings.lockedNote,
                        style: TextStyle(fontSize: 13, color: AppColors.tagOrangeText),
                      ),
                    ),
                  _basicSection(),
                  _datesSection(),
                  _infoSection(),
                ],
              ),
            ),
      bottomNavigationBar: _loading || _error != null || _facilities.isEmpty
          ? null
          : SubmitBar(
              label: isNew ? OwnerTournamentStrings.publish : OwnerTournamentStrings.save,
              busy: _saving,
              onPressed: _save,
            ),
    );
  }

  Widget _basicSection() {
    final entryTypes = TournamentDraft.entryTypesFor(_sport);
    return FormSection(
      title: OwnerTournamentStrings.sectionBasic,
      children: [
        TextFormField(
          controller: _name,
          enabled: !_locked,
          decoration: ownerInputDecoration(OwnerTournamentStrings.name),
          validator: (v) => (v == null || v.trim().isEmpty) ? OwnerTournamentStrings.required : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _facilityId,
          decoration: ownerInputDecoration(OwnerTournamentStrings.facility),
          items: [for (final f in _facilities) DropdownMenuItem(value: f.id, child: Text(f.profile.name))],
          onChanged: _locked ? null : (id) => setState(() => _selectFacility(id!)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<Sport>(
                isExpanded: true,
                key: ValueKey('sport-$_facilityId'),
                initialValue: _sport,
                decoration: ownerInputDecoration(OwnerTournamentStrings.sport),
                items: [for (final s in _sports) DropdownMenuItem(value: s, child: Text(s.label))],
                onChanged: _locked ? null : (s) => setState(() => _selectSport(s!)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<CourtType>(
                isExpanded: true,
                key: ValueKey('court-$_facilityId-${_sport.name}'),
                initialValue: _courtType,
                decoration: ownerInputDecoration(OwnerTournamentStrings.courtType),
                items: [for (final c in _courtTypes) DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: _locked
                    ? null
                    : (c) => setState(() {
                        _courtType = c!;
                        _fixMembers();
                      }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(OwnerTournamentStrings.entryType, style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final e in entryTypes)
              ChoiceChip(
                label: Text(e.label),
                selected: _entryType == e,
                selectedColor: AppColors.lightGreen,
                onSelected: _locked
                    ? null
                    : (_) => setState(() {
                        _entryType = e;
                        _fixMembers();
                      }),
              ),
          ],
        ),
        if (_entryType == TournamentEntryType.team) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(OwnerTournamentStrings.teamSize),
                    Text(
                      OwnerTournamentStrings.teamSizeHint(_minMembers),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              CountStepper(
                value: _maxMembers,
                min: _minMembers,
                onChanged: (n) {
                  if (!_locked && n <= _minMembers * 2) setState(() => _maxMembers = n);
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text(OwnerTournamentStrings.maxEntries, style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final n in TournamentDraft.sizeOptions)
              ChoiceChip(
                label: Text('$n'),
                selected: _maxEntries == n,
                selectedColor: AppColors.lightGreen,
                onSelected: _locked ? null : (_) => setState(() => _maxEntries = n),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fee,
          enabled: !_locked,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: ownerInputDecoration(OwnerTournamentStrings.entryFee, suffix: 'đ'),
          validator: (v) => (v == null || v.trim().isEmpty) ? OwnerTournamentStrings.required : null,
        ),
        const SizedBox(height: 4),
        const Text(OwnerTournamentStrings.feeNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _dateRow(String label, DateTime value, ValueChanged<DateTime> onChanged) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: _locked
        ? null
        : () async {
            final picked = await _pickDateTime(value);
            if (picked != null) setState(() => onChanged(picked));
          },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: ownerInputDecoration(label),
        child: Row(
          children: [
            Expanded(
              child: Text(_dateLabel(value), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.event, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );

  Widget _datesSection() => FormSection(
    title: OwnerTournamentStrings.sectionDates,
    hint: OwnerTournamentStrings.closureNote,
    children: [
      _dateRow(OwnerTournamentStrings.deadline, _deadline, (d) => _deadline = d),
      _dateRow(OwnerTournamentStrings.startDate, _start, (d) => _start = d),
      _dateRow(OwnerTournamentStrings.endDate, _end, (d) => _end = d),
    ],
  );

  Widget _infoSection() => FormSection(
    title: OwnerTournamentStrings.sectionInfo,
    children: [
      TextFormField(
        controller: _description,
        maxLines: 3,
        decoration: ownerInputDecoration(OwnerTournamentStrings.description),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text(OwnerTournamentStrings.prizes, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: _addPrize,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(OwnerTournamentStrings.add),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
          ),
        ],
      ),
      const Text(OwnerTournamentStrings.prizesNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      for (var i = 0; i < _prizes.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
          title: Text(_prizes[i].title),
          subtitle: Text(
            [
              if (_prizes[i].amount > 0) Formatters.vnd(_prizes[i].amount),
              if (_prizes[i].extra.isNotEmpty) _prizes[i].extra,
            ].join(' + '),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _prizes = [..._prizes]..removeAt(i)),
          ),
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(
            child: Text(OwnerTournamentStrings.rules, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: _addRule,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(OwnerTournamentStrings.add),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
          ),
        ],
      ),
      for (var i = 0; i < _rules.length; i++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${i + 1}.', style: const TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_rules[i])),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              onPressed: () => setState(() => _rules = [..._rules]..removeAt(i)),
            ),
          ],
        ),
    ],
  );
}

/// Hộp thoại thêm một giải thưởng; các ô nhập do hộp thoại tự giữ và hủy.
class _PrizeDialog extends StatefulWidget {
  const _PrizeDialog();

  @override
  State<_PrizeDialog> createState() => _PrizeDialogState();
}

class _PrizeDialogState extends State<_PrizeDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _extra = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      TournamentPrize(title: title, amount: ThousandsInputFormatter.parse(_amount.text), extra: _extra.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(OwnerTournamentStrings.addPrize),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          autofocus: true,
          decoration: const InputDecoration(labelText: OwnerTournamentStrings.prizeTitle),
        ),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: const InputDecoration(labelText: OwnerTournamentStrings.prizeAmount, suffixText: 'đ'),
        ),
        TextField(
          controller: _extra,
          decoration: const InputDecoration(labelText: OwnerTournamentStrings.prizeExtra),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerTournamentStrings.cancel)),
      TextButton(onPressed: _submit, child: const Text(OwnerTournamentStrings.add)),
    ],
  );
}
