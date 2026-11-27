import 'package:flutter/material.dart';

import '../../widgets/common/text_prompt_dialog.dart';

import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/tournament_rules.dart';
import '../../core/strings/organizer_strings.dart';
import '../../core/strings/player_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/organized_tournament.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';
import '../../widgets/tournament/organizer_match_sections.dart';
import '../../widgets/tournament/organizer_sections.dart';
import 'organized_tournaments_tab.dart';

/// Màn quản lý một giải tôi tổ chức (phần cơ bản): thông tin, tài liệu đã gửi, lịch sân yêu cầu,
/// sửa thông tin / lệ phí, hủy (khóa từ 24 giờ trước hạn đăng ký), xóa.
class OrganizedTournamentScreen extends StatefulWidget {
  final String tournamentId;
  final DateTime Function()? now;

  /// Chủ sân: thêm mục giữ / trả ca sân cho giải (người chơi làm BTC không giữ ca được).
  final bool ownerMode;

  const OrganizedTournamentScreen({super.key, required this.tournamentId, this.now, this.ownerMode = false});

  @override
  State<OrganizedTournamentScreen> createState() => _OrganizedTournamentScreenState();
}

class _OrganizedTournamentScreenState extends State<OrganizedTournamentScreen> {
  OrganizedTournament? _t;
  String? _error;
  bool _busy = false;
  final _fee = TextEditingController();

  /// Tăng sau khi chủ sân giữ / trả ca để lịch sân tải lại.
  int _scheduleRevision = 0;
  Set<String> _heldCourts = const {};

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await AppRepositories.hostTournament.getDetail(widget.tournamentId);
      if (mounted) setState(() => _t = t);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
  }

  Future<void> _run(Future<void> Function() action, String success, {bool close = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (close) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(success)));
        return;
      }
      _toast(success);
      await _load();
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveFee() async {
    if (_fee.text.trim().isEmpty) return;
    final fee = ThousandsInputFormatter.parse(_fee.text);
    await _run(
      () => AppRepositories.hostTournament.updateInfo(widget.tournamentId, TournamentInfoUpdate(entryFee: fee)),
      OrganizerStrings.feeSaved,
    );
    _fee.clear();
  }

  Future<void> _cancel(OrganizedTournament t) async {
    final reason = await showTextPrompt(
      context,
      title: OrganizerStrings.cancelTitle(t.name),
      hint: OrganizerStrings.cancelHint,
      confirm: OrganizerStrings.cancelConfirm,
      cancel: OrganizerStrings.keep,
      destructive: true,
    );
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      _toast(OrganizerStrings.cancelReasonRequired, error: true);
      return;
    }
    await _run(() => AppRepositories.hostTournament.cancel(t.id, reason), OrganizerStrings.cancelled);
  }

  Future<void> _delete(OrganizedTournament t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(OrganizerStrings.deleteConfirm(t.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(OrganizerStrings.keep)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(OrganizerStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => AppRepositories.hostTournament.delete(t.id), OrganizerStrings.deleted, close: true);
  }

  Future<void> _edit(OrganizedTournament t) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTournamentInfoScreen(tournament: t, now: widget.now),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OrganizerStrings.manageTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: t == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: _content(t),
              ),
            ),
    );
  }

  List<Widget> _content(OrganizedTournament t) {
    final canCancel = TournamentRules.canOrganizerCancel(t.deadline, _now());
    return [
      Text(
        t.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
      ),
      const SizedBox(height: 6),
      OrganizedStatusChip(tournament: t),
      if (t.isPendingApproval)
        _banner(OrganizerStrings.pendingBanner, const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      if (t.isRejected)
        _banner(OrganizerStrings.rejectedBanner(t.approvalNote), const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      if (t.isCancelled)
        _banner(
          OrganizerStrings.cancelledBanner(t.cancellationReason),
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
        ),
      if (t.purpose == TournamentPurpose.internal)
        _banner(OrganizerStrings.internalBanner, const Color(0xFFF5F3FF), const Color(0xFF5B21B6)),
      const SizedBox(height: 12),
      _card([
        _row(PlayerTournamentStrings.venue, [t.facilityName, t.facilityAddress].where((s) => s.isNotEmpty).join(' • ')),
        if (t.sportName.isNotEmpty) _row(OrganizerStrings.sport, t.sportName),
        _row(PlayerTournamentStrings.playTime, PlayerTournamentStrings.dateRange(t.start, t.end)),
        if (t.deadline != null) _row(PlayerTournamentStrings.regDeadline, Formatters.date(t.deadline!)),
        if (t.tier != null) _row(PlayerTournamentStrings.tierTitle, t.tier!.label),
        if (t.purpose != null) _row(PlayerTournamentStrings.purposeTitle, t.purpose!.label),
        _row(OrganizerStrings.type, t.type.label),
        _row(OrganizerStrings.participants, '${t.registeredCount}/${t.maxParticipants}'),
        if (t.format != null) _row(PlayerTournamentStrings.formatTitle, t.format!.label),
        _row(PlayerTournamentStrings.entryFee, PlayerTournamentStrings.fee(t.entryFee)),
        if (t.tier != null && t.tier != TournamentTier.amateur)
          _row(
            PlayerTournamentStrings.eloTitle,
            PlayerTournamentStrings.eloCondition(t.minRating, t.maxRating, t.minRatedMatches),
          ),
        _row(
          OrganizerStrings.prizes,
          t.prizes.isEmpty
              ? OrganizerStrings.noPrizes
              : '${t.prizes.map((p) => '${p.position} ${Formatters.vnd(p.amount)}').join(' • ')} ${OrganizerStrings.prizeTotal(t.prizeTotal)}',
        ),
      ]),
      if (t.description.isNotEmpty) ...[
        const SizedBox(height: 12),
        _card([
          Text(PlayerTournamentStrings.introTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(t.description, style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
        ]),
      ],
      if (t.requestedSchedule.isNotEmpty) ...[
        const SizedBox(height: 12),
        _card([
          const Text(OrganizerStrings.requestedSchedule, style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final r in t.requestedSchedule)
            Text(
              '${r.date == null ? '' : Formatters.date(r.date!)} • '
              '${r.startTime != null && r.endTime != null ? '${r.startTime}–${r.endTime}' : r.session.label} • '
              '${r.courtCount} ${OrganizerStrings.courtCount.toLowerCase()}',
              style: const TextStyle(fontSize: 13),
            ),
        ]),
      ],
      const SizedBox(height: 12),
      _card([
        const Text(OrganizerStrings.sentDocuments, style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (t.documents.isEmpty)
          const Text(OrganizerStrings.noDocuments, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
        else
          for (final d in t.documents)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => launchUrl(Uri.parse(d.url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.red),
              label: Text(d.name),
            ),
      ]),
      if (!t.isOrganizer)
        _banner(
          OrganizerStrings.atFacilityNote(t.organizerName.isEmpty ? OrganizerStrings.someoneElse : t.organizerName),
          const Color(0xFFEFF6FF),
          const Color(0xFF1E3A8A),
        ),
      if (t.isOrganizer && t.needsRegistrationDecision(_now())) RegistrationDecisionCard(tournament: t, onDone: _load),
      if (t.isOrganizer && !t.isPendingApproval && !t.isRejected)
        OrganizerCompetitionPanel(tournament: t, onChanged: _load),
      if (widget.ownerMode && !t.isClosed && !t.isPendingApproval && !t.isRejected && t.facilityId.isNotEmpty)
        CourtBlockSection(
          tournament: t,
          heldCourtNames: _heldCourts,
          onChanged: () => setState(() => _scheduleRevision++),
        ),
      if (!t.isPendingApproval && !t.isRejected)
        CourtScheduleSection(
          key: ValueKey('schedule-${t.status}-$_scheduleRevision'),
          tournament: t,
          manage: t.isOrganizer,
          onHeldCourts: (names) {
            if (mounted && names.length != _heldCourts.length) setState(() => _heldCourts = names);
          },
        ),
      if (t.isOrganizer && !t.isOpen && !t.isPendingApproval && !t.isRejected) ...[
        TournamentStandingsSection(key: ValueKey('standings-${t.status}'), tournamentId: t.id),
        MatchComplaintsSection(tournament: t, onChanged: _load),
      ],
      if (t.isOrganizer) TournamentStaffSection(tournament: t),
      if (t.isOrganizer && t.canEditFee) ...[
        const SizedBox(height: 12),
        _card([
          const Text(OrganizerStrings.editFee, style: TextStyle(fontWeight: FontWeight.bold)),
          const Text(OrganizerStrings.editFeeHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fee,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: Formatters.currency(t.entryFee),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _busy ? null : _saveFee, child: const Text(OrganizerStrings.saveFee)),
            ],
          ),
        ]),
      ],
      if (t.isOrganizer) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!t.isClosed)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _edit(t),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(OrganizerStrings.editInfo),
              ),
            if (!t.isClosed)
              OutlinedButton(
                onPressed: _busy || !canCancel ? null : () => _cancel(t),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC2410C)),
                child: Text(canCancel ? OrganizerStrings.cancel : OrganizerStrings.cancelLocked),
              ),
            if (t.canDelete)
              OutlinedButton(
                onPressed: _busy ? null : () => _delete(t),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text(OrganizerStrings.delete),
              ),
          ],
        ),
        if (!t.isClosed && !canCancel)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              OrganizerStrings.cancelLockedReason,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    ];
  }

  Widget _banner(String text, Color bg, Color fg) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
          ),
        ),
      ],
    ),
  );
}

/// Sửa thông tin giải: tên, ngày, ảnh bìa, giới thiệu. Luật ngày mới chỉ áp cho ô vừa đổi (như Web).
class EditTournamentInfoScreen extends StatefulWidget {
  final OrganizedTournament tournament;
  final DateTime Function()? now;
  final Future<String?> Function()? pickImage;

  const EditTournamentInfoScreen({super.key, required this.tournament, this.now, this.pickImage});

  @override
  State<EditTournamentInfoScreen> createState() => _EditTournamentInfoScreenState();
}

class _EditTournamentInfoScreenState extends State<EditTournamentInfoScreen> {
  late final _name = TextEditingController(text: widget.tournament.name);
  late final _description = TextEditingController(text: widget.tournament.description);
  late DateTime? _start = widget.tournament.start;
  late DateTime? _end = widget.tournament.end;
  late DateTime? _deadline = widget.tournament.deadline;
  late String _imageUrl = widget.tournament.imageUrl;
  bool _uploading = false;
  bool _busy = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  static bool _sameDay(DateTime? a, DateTime? b) =>
      (a == null && b == null) || (a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day);

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));

  Future<void> _pickDate(DateTime? current, void Function(DateTime) set) async {
    final today = _now();
    final first = DateTime(today.year, today.month, today.day);
    var initial = current ?? first;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => set(picked));
  }

  Future<void> _pickImage() async {
    final path =
        await (widget.pickImage ??
            () async => (await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600))?.path)();
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await AppRepositories.hostTournament.uploadImage(path);
      if (mounted) setState(() => _imageUrl = url);
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final t = widget.tournament;
    if (_name.text.trim().isEmpty) {
      _toast(OrganizerStrings.nameRequired);
      return;
    }
    final changed = <String>{
      if (!_sameDay(_start, t.start)) 'start',
      if (!_sameDay(_end, t.end)) 'end',
      if (!_sameDay(_deadline, t.deadline)) 'deadline',
    };
    final error = TournamentRules.validateDates(
      start: _start,
      end: _end,
      deadline: _deadline,
      today: _now(),
      requireDates: false,
      changed: changed,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppRepositories.hostTournament.updateInfo(
        t.id,
        TournamentInfoUpdate(
          name: _name.text,
          start: _start,
          end: _end,
          deadline: _deadline,
          imageUrl: _imageUrl.isEmpty ? null : _imageUrl,
          description: _description.text,
        ),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(OrganizerStrings.saved)));
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget dateRow(String label, DateTime? value, void Function(DateTime) set) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(value, set),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(value == null ? OrganizerStrings.pickDate : Formatters.date(value)),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OrganizerStrings.editInfo,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(OrganizerStrings.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: 200,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            dateRow(OrganizerStrings.start, _start, (d) => _start = d),
            dateRow(OrganizerStrings.end, _end, (d) => _end = d),
            dateRow(OrganizerStrings.deadline, _deadline, (d) => _deadline = d),
            const SizedBox(height: 14),
            const Text(OrganizerStrings.image, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: AppColors.cardBorder),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_uploading ? OrganizerStrings.uploading : OrganizerStrings.pickImage),
              ),
            ),
            const SizedBox(height: 8),
            const Text(OrganizerStrings.description, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLines: 5,
              maxLength: 4000,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy || _uploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(OrganizerStrings.save, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
