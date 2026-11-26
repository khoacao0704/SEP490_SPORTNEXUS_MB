import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/owner_slot_strings.dart';
import '../../models/owner_court.dart';
import '../../theme/app_colors.dart';

/// Loại sân gợi ý theo môn (COURT_PRESETS của Web): [nhãn, số người mỗi đội].
const List<({List<String> match, List<(String, int)> types})> _presets = [
  (match: ['bong da', 'football', 'soccer'], types: [('Sân 5 người', 5), ('Sân 7 người', 7), ('Sân 11 người', 11)]),
  (match: ['cau long', 'badminton'], types: [('Sân đơn', 1), ('Sân đôi', 2)]),
  (match: ['pickleball'], types: [('Sân đơn', 1), ('Sân đôi', 2)]),
  (match: ['tennis', 'quan vot'], types: [('Sân đơn', 1), ('Sân đôi', 2)]),
  (match: ['bong ro', 'basketball'], types: [('Sân 3x3', 3), ('Sân 5x5', 5)]),
  (match: ['bong chuyen', 'volleyball'], types: [('Sân 6 người', 6), ('Bóng chuyền bãi biển (2 người)', 2)]),
];

String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
    .replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e')
    .replaceAll(RegExp('[ìíịỉĩ]'), 'i')
    .replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
    .replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u')
    .replaceAll(RegExp('[ỳýỵỷỹ]'), 'y')
    .replaceAll('đ', 'd');

List<(String, int)>? presetsOf(String? sportName) {
  if (sportName == null) return null;
  final name = _plain(sportName);
  return _presets.where((p) => p.match.any(name.contains)).firstOrNull?.types;
}

/// Mở form Thêm sân mới / Sửa sân (CourtFormModal của Web). Trả về dữ liệu đã kiểm tra, hoặc null nếu hủy.
Future<CourtInput?> showCourtForm(
  BuildContext context, {
  required List<SportCategory> sports,
  OwnerCourt? court,
  String? defaultSportId,
  int? defaultPrice,
}) =>
    showModalBottomSheet<CourtInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CourtForm(sports: sports, court: court, defaultSportId: defaultSportId, defaultPrice: defaultPrice),
    );

class _CourtForm extends StatefulWidget {
  final List<SportCategory> sports;
  final OwnerCourt? court;
  final String? defaultSportId;
  final int? defaultPrice;

  const _CourtForm({required this.sports, this.court, this.defaultSportId, this.defaultPrice});

  @override
  State<_CourtForm> createState() => _CourtFormState();
}

class _CourtFormState extends State<_CourtForm> {
  late String? _categoryId = widget.court?.categoryId ?? widget.defaultSportId ?? widget.sports.firstOrNull?.id;
  late final _name = TextEditingController(text: widget.court?.name ?? '');
  late final _price = TextEditingController(
    text: widget.court != null ? '${widget.court!.defaultPrice}' : (widget.defaultPrice == null ? '' : '${widget.defaultPrice}'),
  );
  late final _courtTypeText = TextEditingController(text: widget.court?.courtType ?? '');
  late final _surface = TextEditingController(text: widget.court?.surfaceType ?? '');
  late final _maxPlayers = TextEditingController(text: widget.court?.maxPlayers?.toString() ?? '');
  late final _teamSizeText = TextEditingController(text: widget.court?.teamSize?.toString() ?? '');
  late String? _courtType = widget.court?.courtType;
  late bool? _isIndoor = widget.court?.isIndoor;
  late int? _teamSize = widget.court?.teamSize;
  late int? _slotMinutes = widget.court?.slotMinutes;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _price, _courtTypeText, _surface, _maxPlayers, _teamSizeText]) {
      c.dispose();
    }
    super.dispose();
  }

  SportCategory? get _sport => widget.sports.where((s) => s.id == _categoryId).firstOrNull;

  void _submit() {
    final presets = presetsOf(_sport?.name);
    final price = int.tryParse(_price.text.trim());
    final maxText = _maxPlayers.text.trim();
    final maxPlayers = maxText.isEmpty ? null : int.tryParse(maxText);
    final teamSize = presets != null ? _teamSize : (_teamSizeText.text.trim().isEmpty ? null : int.tryParse(_teamSizeText.text.trim()));
    String? error;
    if (_categoryId == null) {
      error = OwnerSlotStrings.errSport;
    } else if (_name.text.trim().isEmpty) {
      error = OwnerSlotStrings.errName;
    } else if (price == null || price < 0) {
      error = OwnerSlotStrings.errPrice;
    } else if (maxText.isNotEmpty && (maxPlayers == null || maxPlayers < 1 || maxPlayers > 100)) {
      error = OwnerSlotStrings.errMaxPlayers;
    } else if (teamSize != null && (teamSize < 1 || teamSize > 15) ||
        (presets == null && _teamSizeText.text.trim().isNotEmpty && teamSize == null)) {
      error = OwnerSlotStrings.errTeamSize;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final courtType = presets != null ? _courtType : _courtTypeText.text.trim();
    final surface = _surface.text.trim();
    Navigator.pop(
      context,
      CourtInput(
        categoryId: _categoryId!,
        name: _name.text.trim(),
        defaultPrice: price!,
        courtType: courtType == null || courtType.isEmpty ? null : courtType,
        isIndoor: _isIndoor,
        surfaceType: surface.isEmpty ? null : surface,
        maxPlayers: maxPlayers,
        teamSize: teamSize,
        slotMinutes: _slotMinutes,
        status: widget.court?.status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final court = widget.court;
    final presets = presetsOf(_sport?.name);
    final teamOptions = presets == null ? <int>[] : ({for (final p in presets) p.$2}.toList()..sort());
    final legacyType = presets != null && _courtType != null && !presets.any((p) => p.$1 == _courtType);
    final legacyTeam = presets != null && _teamSize != null && !teamOptions.contains(_teamSize);
    final stats = court == null
        ? ''
        : OwnerSlotStrings.courtStats(
            court.availableSlotsNext7Days, court.effectiveSlotMinutes, court.minUpcomingPrice, court.maxUpcomingPrice);
    final minutesOptions = [
      ...OwnerSlotStrings.slotMinuteOptions,
      if (_slotMinutes != null && !OwnerSlotStrings.slotMinuteOptions.contains(_slotMinutes)) _slotMinutes!,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      court == null ? OwnerSlotStrings.addCourtTitle : OwnerSlotStrings.editCourtTitle(court.name),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text(
                court == null ? OwnerSlotStrings.addCourtHint : OwnerSlotStrings.editCourtHint,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: Text(stats, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1D4ED8))),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: OwnerSlotStrings.sport, border: OutlineInputBorder(), isDense: true),
                hint: widget.sports.isEmpty ? const Text(OwnerSlotStrings.loadingSports) : null,
                items: [for (final s in widget.sports) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => setState(() {
                  // Đổi môn: loại sân / số người mỗi đội của môn cũ không còn đúng.
                  _categoryId = v;
                  _courtType = null;
                  _teamSize = null;
                  _courtTypeText.clear();
                  _teamSizeText.clear();
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: OwnerSlotStrings.courtName,
                  hintText: OwnerSlotStrings.courtNameHint,
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: OwnerSlotStrings.defaultPrice,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              if (presets != null)
                DropdownButtonFormField<String?>(
                  key: ValueKey('type-$_categoryId'),
                  initialValue: _courtType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: OwnerSlotStrings.courtType, border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text(OwnerSlotStrings.notDeclared)),
                    if (legacyType) DropdownMenuItem(value: _courtType, child: Text(OwnerSlotStrings.legacy(_courtType!))),
                    for (final p in presets) DropdownMenuItem(value: p.$1, child: Text(p.$1)),
                  ],
                  // Chọn loại sân: tự điền số người mỗi đội tương ứng.
                  onChanged: (v) => setState(() {
                    _courtType = v;
                    final preset = presets.where((p) => p.$1 == v).firstOrNull;
                    if (preset != null) _teamSize = preset.$2;
                  }),
                )
              else
                TextField(
                  controller: _courtTypeText,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: OwnerSlotStrings.courtType,
                    hintText: OwnerSlotStrings.courtTypeHint,
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _surface,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: OwnerSlotStrings.surface,
                  hintText: OwnerSlotStrings.surfaceHint,
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<bool?>(
                initialValue: _isIndoor,
                isExpanded: true,
                decoration: const InputDecoration(labelText: OwnerSlotStrings.indoor, border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: null, child: Text(OwnerSlotStrings.notDeclared)),
                  DropdownMenuItem(value: true, child: Text(OwnerSlotStrings.indoorYes)),
                  DropdownMenuItem(value: false, child: Text(OwnerSlotStrings.indoorNo)),
                ],
                onChanged: (v) => setState(() => _isIndoor = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _maxPlayers,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: OwnerSlotStrings.maxPlayers, border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              if (presets != null)
                DropdownButtonFormField<int?>(
                  key: ValueKey('team-$_categoryId-$_teamSize'),
                  initialValue: _teamSize,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: OwnerSlotStrings.teamSize, border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text(OwnerSlotStrings.notDeclared)),
                    if (legacyTeam) DropdownMenuItem(value: _teamSize, child: Text(OwnerSlotStrings.legacy(OwnerSlotStrings.people(_teamSize!)))),
                    for (final n in teamOptions) DropdownMenuItem(value: n, child: Text(OwnerSlotStrings.people(n))),
                  ],
                  onChanged: (v) => setState(() => _teamSize = v),
                )
              else
                TextField(
                  controller: _teamSizeText,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: OwnerSlotStrings.teamSize, border: OutlineInputBorder(), isDense: true),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: _slotMinutes,
                isExpanded: true,
                decoration: const InputDecoration(labelText: OwnerSlotStrings.slotMinutes, border: OutlineInputBorder(), isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(OwnerSlotStrings.bySport(_sport?.defaultSlotMinutes ?? 120))),
                  for (final m in minutesOptions) DropdownMenuItem(value: m, child: Text(OwnerSlotStrings.minutes(m))),
                ],
                onChanged: (v) => setState(() => _slotMinutes = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerSlotStrings.cancel)),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    child: Text(court == null ? OwnerSlotStrings.create : OwnerSlotStrings.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
