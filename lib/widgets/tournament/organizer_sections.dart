import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/tournament_rules.dart';
import '../../core/strings/match_strings.dart';
import '../../core/strings/organizer_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/organized_tournament.dart';
import '../../models/tournament_listing.dart';
import '../../models/tournament_management.dart';
import '../../screens/tournament/tournament_bracket_screen.dart';
import '../../theme/app_colors.dart';
import 'organizer_match_sections.dart';

// Các mục quản lý giải của BTC (giải đấu đợt 3, như CreateTournament.jsx / TournamentManagePanel.jsx của Web).

void _toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
}

Future<bool> _confirm(BuildContext context, String text, {String? action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(OrganizerStrings.keep)),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(action ?? OrganizerStrings.confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Chạy một thao tác: báo thành công / câu lỗi của BE. Trả về true nếu xong.
Future<bool> _run(BuildContext context, Future<void> Function() action, String success) async {
  try {
    await action();
    if (context.mounted) _toast(context, success);
    return true;
  } on TournamentException catch (e) {
    if (context.mounted) _toast(context, e.message, error: true);
    return false;
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color color;

  const _Card({required this.children, this.color = AppColors.white});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

const TextStyle _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain);
const TextStyle _mutedStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);

InputDecoration _input(String hint) => InputDecoration(
  hintText: hint,
  isDense: true,
  filled: true,
  fillColor: AppColors.white,
  counterText: '',
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
);

// ======================= Quyết định khi thiếu người =======================

/// Quá hạn đăng ký mà chưa đủ 4 người / đội: chọn vẫn thi đấu hoặc hủy (hoàn 100%). Không có gia hạn.
class RegistrationDecisionCard extends StatefulWidget {
  final OrganizedTournament tournament;
  final VoidCallback onDone;

  const RegistrationDecisionCard({super.key, required this.tournament, required this.onDone});

  @override
  State<RegistrationDecisionCard> createState() => _RegistrationDecisionCardState();
}

class _RegistrationDecisionCardState extends State<RegistrationDecisionCard> {
  bool _proceed = true;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_proceed && !await _confirm(context, OrganizerStrings.cancelRefundConfirm)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await _run(
      context,
      () => AppRepositories.hostTournament.decideRegistration(
        widget.tournament.id,
        proceed: _proceed,
        reason: _reason.text,
      ),
      OrganizerStrings.decided,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) => _Card(
    color: const Color(0xFFEFF6FF),
    children: [
      const Text(OrganizerStrings.shortTitle, style: _titleStyle),
      const SizedBox(height: 4),
      const Text(OrganizerStrings.shortBody, style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A))),
      RadioGroup<bool>(
        groupValue: _proceed,
        onChanged: (v) => setState(() => _proceed = v ?? true),
        // RadioListTile cần Material riêng vì thẻ có màu nền.
        child: const Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              RadioListTile<bool>(
                value: true,
                title: Text(OrganizerStrings.keepPlaying),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                value: false,
                title: Text(OrganizerStrings.cancelRefund),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      TextField(controller: _reason, maxLength: 500, decoration: _input(OrganizerStrings.reasonOptional)),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(onPressed: _busy ? null : _submit, child: const Text(OrganizerStrings.confirm)),
      ),
    ],
  );
}

// ======================= Người tham gia + mời + sơ đồ =======================

/// Người / đội tham gia (điểm danh, xóa), mời vào giải nội bộ, chốt danh sách & sinh sơ đồ, xem sơ đồ.
class OrganizerCompetitionPanel extends StatefulWidget {
  final OrganizedTournament tournament;

  /// Gọi khi số người / trạng thái giải có thể đã đổi (tải lại giải).
  final VoidCallback onChanged;

  const OrganizerCompetitionPanel({super.key, required this.tournament, required this.onChanged});

  @override
  State<OrganizerCompetitionPanel> createState() => _OrganizerCompetitionPanelState();
}

class _OrganizerCompetitionPanelState extends State<OrganizerCompetitionPanel> {
  List<OrganizerParticipant>? _participants;
  List<OrganizerInvitation> _invitations = const [];
  List<BracketMatch> _bracket = const [];
  String? _error;
  bool _busy = false;
  final _phone = TextEditingController();
  final _teamQuery = TextEditingController();
  List<TeamOption>? _teams;
  int _searchToken = 0;

  OrganizedTournament get _t => widget.tournament;
  bool get _team => _t.type == DivisionType.premadeTeams;
  bool get _internal => _t.purpose == TournamentPurpose.internal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OrganizerCompetitionPanel old) {
    super.didUpdateWidget(old);
    if (old.tournament.status != _t.status) _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _teamQuery.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = AppRepositories.hostTournament;
    try {
      final participants = await repo.getParticipants(_t.id);
      final invitations = _internal && _t.isOpen ? await repo.getInvitations(_t.id) : const <OrganizerInvitation>[];
      var bracket = const <BracketMatch>[];
      if (!_t.isOpen) {
        try {
          bracket = await repo.getBracket(_t.id);
        } on TournamentException {
          // Chưa có sơ đồ.
        }
      }
      if (!mounted) return;
      setState(() {
        _participants = participants;
        _invitations = invitations;
        _bracket = bracket;
        _error = null;
      });
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _act(Future<void> Function() action, String success, {bool reloadTournament = false}) async {
    setState(() => _busy = true);
    final ok = await _run(context, action, success);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await _load();
      if (reloadTournament) widget.onChanged();
    }
  }

  Future<void> _remove(OrganizerParticipant p) async {
    if (!await _confirm(context, OrganizerStrings.removeConfirm(p.displayName), action: OrganizerStrings.remove)) {
      return;
    }
    await _act(
      () => AppRepositories.hostTournament.removeParticipant(_t.id, p.participantId),
      OrganizerStrings.removed(p.displayName),
      reloadTournament: true,
    );
  }

  Future<void> _generate() async {
    if (!await _confirm(context, OrganizerStrings.generateConfirm, action: OrganizerStrings.generate)) return;
    await _act(
      () => AppRepositories.hostTournament.generateBracket(_t.id, _t.format),
      OrganizerStrings.generated,
      reloadTournament: true,
    );
  }

  Future<void> _searchTeams(String text) async {
    final token = ++_searchToken;
    if (text.trim().length < 2) {
      setState(() => _teams = null);
      return;
    }
    try {
      final teams = await AppRepositories.hostTournament.searchTeams(text, categoryId: _t.categoryId);
      if (mounted && token == _searchToken) setState(() => _teams = teams);
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    }
  }

  Future<void> _inviteTeam(TeamOption team) async {
    await _act(() => AppRepositories.hostTournament.invite(_t.id, teamId: team.id), OrganizerStrings.invitedTeam);
    if (!mounted) return;
    _teamQuery.clear();
    setState(() => _teams = null);
  }

  Future<void> _invitePhone() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;
    await _act(() => AppRepositories.hostTournament.invite(_t.id, phone: phone), OrganizerStrings.invitedPlayer);
    if (mounted) _phone.clear();
  }

  @override
  Widget build(BuildContext context) {
    final participants = _participants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          children: [
            Text(
              OrganizerStrings.participantsTitle(_team, participants?.length ?? _t.registeredCount, _t.maxParticipants),
              style: _titleStyle,
            ),
            if (_t.isOpen && participants != null) ..._generateControls(participants.length),
            if (_t.isOpen && _internal) ..._inviteControls(),
            if (_t.isOpen && !_internal)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(OrganizerStrings.publicNote, style: _mutedStyle),
              ),
            const SizedBox(height: 8),
            if (_error != null && participants == null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (participants == null)
              const Center(
                child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
              )
            else if (participants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: Text(OrganizerStrings.noParticipants, style: _mutedStyle)),
              )
            else
              for (final p in participants) _participantRow(p),
          ],
        ),
        ?championBanner(_t, _bracket),
        if (!_t.isOpen && !_t.isPendingApproval && !_t.isRejected) _bracketCard(participants ?? const []),
      ],
    );
  }

  List<Widget> _generateControls(int n) {
    final format = _t.format ?? TournamentRules.suggestFormat(n);
    final error = n < 2 ? OrganizerStrings.needTwo : TournamentRules.formatError(format, n);
    final warning = error == null ? TournamentRules.formatWarning(format, n) : null;
    return [
      const SizedBox(height: 8),
      if (n >= 2)
        Text(
          OrganizerStrings.formatSummary(format.label, n, _team, TournamentRules.estimateMatches(format, n)),
          style: _mutedStyle,
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '✕ $error${n >= 2 && _t.format != null ? OrganizerStrings.formatLockedWait : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
          ),
        )
      else if (warning != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '⚠ $warning',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
          ),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_t.type == DivisionType.randomDoubles)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _act(() => AppRepositories.hostTournament.randomPairing(_t.id), OrganizerStrings.paired),
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: const Text(OrganizerStrings.pairing),
            ),
          ElevatedButton(
            onPressed: _busy || error != null ? null : _generate,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text(OrganizerStrings.generate),
          ),
        ],
      ),
    ];
  }

  List<Widget> _inviteControls() {
    final pending = _invitations;
    return [
      const SizedBox(height: 10),
      if (_team) ...[
        TextField(
          controller: _teamQuery,
          decoration: _input(OrganizerStrings.inviteTeamHint).copyWith(prefixIcon: const Icon(Icons.search)),
          onChanged: _searchTeams,
        ),
        if (_teams != null)
          Material(
            color: AppColors.white,
            child: _teams!.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(OrganizerStrings.noTeams, style: _mutedStyle),
                  )
                : Column(
                    children: [
                      for (final team in _teams!)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(team.name),
                          subtitle: Text(OrganizerStrings.teamSubtitle(team.captainName, team.totalMembers)),
                          trailing: TextButton(
                            onPressed: _busy ? null : () => _inviteTeam(team),
                            child: const Text(OrganizerStrings.invite),
                          ),
                        ),
                    ],
                  ),
          ),
      ] else
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _input(OrganizerStrings.invitePhoneHint),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _busy ? null : _invitePhone, child: const Text(OrganizerStrings.invite)),
          ],
        ),
      if (pending.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          OrganizerStrings.sentInvitations(pending.length),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        for (final inv in pending)
          Row(
            children: [
              Expanded(child: Text(inv.displayName, style: const TextStyle(fontSize: 13))),
              Text(inv.status.label, style: _mutedStyle),
              if (inv.status == TournamentInvitationStatus.pending)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => AppRepositories.hostTournament.cancelInvitation(inv.id),
                          OrganizerStrings.revoked,
                        ),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text(OrganizerStrings.revoke),
                ),
            ],
          ),
      ],
    ];
  }

  Widget _participantRow(OrganizerParticipant p) {
    final closed = _t.isClosed;
    final sub = [
      if (p.teamName != null && p.members.isNotEmpty)
        p.members.join(', ')
      else if (p.username.isNotEmpty)
        '@${p.username}',
      if (p.paymentLabel.isNotEmpty) p.paymentLabel,
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.isCheckedIn ? const Color(0xFFF0FDF4) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.cardBorder,
            child: Text(
              p.displayName.isEmpty ? '?' : p.displayName.characters.first,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (sub.isNotEmpty) Text(sub, style: _mutedStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (p.isCheckedIn)
                  const Text(
                    OrganizerStrings.checkedIn,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                  )
                // Nút nằm dưới tên để máy nhỏ / chữ to không tràn.
                else if (!closed)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => AppRepositories.hostTournament.checkIn(_t.id, p.participantId),
                            OrganizerStrings.checkedInDone(p.displayName),
                          ),
                    icon: const Icon(Icons.how_to_reg, size: 16),
                    label: const Text(OrganizerStrings.checkIn),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF15803D),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          if (_t.isOpen)
            IconButton(
              tooltip: OrganizerStrings.remove,
              onPressed: _busy ? null : () => _remove(p),
              icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _bracketCard(List<OrganizerParticipant> participants) {
    final absent = {
      for (final p in participants)
        if (!p.isCheckedIn) p.displayName,
    };
    return _Card(
      children: [
        const Text(OrganizerStrings.bracketTitle, style: _titleStyle),
        const SizedBox(height: 4),
        if (_bracket.isEmpty)
          const Text(OrganizerStrings.bracketEmpty, style: _mutedStyle)
        else ...[
          if (_canScore) const Text(MatchStrings.tapToScore, style: _mutedStyle),
          for (final round in groupBracketRounds(_bracket)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(round.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            for (final m in round.matches)
              BracketMatchCard(
                match: m,
                absent: absent,
                onTap: _canScore && _hasBothSides(m) && !_busy ? () => _score(m) : null,
              ),
          ],
        ],
      ],
    );
  }

  /// BTC nhập / sửa tỉ số khi giải đang thi đấu.
  bool get _canScore => _t.status.toUpperCase() == 'IN_PROGRESS';

  static bool _hasBothSides(BracketMatch m) =>
      m.sideA != BracketMatch.unknownSide && m.sideB != BracketMatch.unknownSide;

  Future<void> _score(BracketMatch m) async {
    if (await openOrganizerScore(context, m)) {
      await _load();
      widget.onChanged();
    }
  }
}

// ======================= Nhân sự =======================

/// Nhân sự giải: trọng tài / ghi điểm (phải có tài khoản, tìm theo SĐT) / khác. Khóa khi giải đã kết thúc / hủy.
class TournamentStaffSection extends StatefulWidget {
  final OrganizedTournament tournament;

  const TournamentStaffSection({super.key, required this.tournament});

  @override
  State<TournamentStaffSection> createState() => _TournamentStaffSectionState();
}

class _TournamentStaffSectionState extends State<TournamentStaffSection> {
  List<TournamentStaffMember>? _staff;
  String? _error;
  StaffRole _role = StaffRole.referee;
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  String? _accountId;
  String? _editingId;
  bool _looking = false;
  bool _busy = false;

  bool get _closed => widget.tournament.isClosed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final staff = await AppRepositories.hostTournament.getStaff(widget.tournament.id);
      if (mounted) setState(() => _staff = staff);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _reset() {
    _phone.clear();
    _name.clear();
    _note.clear();
    setState(() {
      _role = StaffRole.referee;
      _accountId = null;
      _editingId = null;
    });
  }

  void _startEdit(TournamentStaffMember m) {
    _phone.text = m.phone;
    _name.text = m.fullName;
    _note.text = m.note;
    setState(() {
      _role = m.role;
      _accountId = m.accountId;
      _editingId = m.id;
    });
  }

  Future<void> _find() async {
    setState(() => _looking = true);
    try {
      final account = await AppRepositories.hostTournament.lookupAccount(_phone.text);
      if (!mounted) return;
      if (account == null) {
        setState(() => _accountId = null);
        _toast(context, OrganizerStrings.accountNotFound, error: true);
      } else {
        setState(() => _accountId = account.id);
        if (account.fullName.isNotEmpty) _name.text = account.fullName;
      }
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _submit() async {
    if (_role.needsAccount && _accountId == null) {
      _toast(context, OrganizerStrings.staffNeedAccount, error: true);
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      _toast(context, OrganizerStrings.staffNeedNamePhone, error: true);
      return;
    }
    final draft = StaffDraft(
      fullName: _name.text,
      phone: _phone.text,
      role: _role,
      accountId: _accountId,
      note: _note.text,
    );
    final editing = _editingId;
    setState(() => _busy = true);
    final ok = await _run(
      context,
      () => editing == null
          ? AppRepositories.hostTournament.addStaff(widget.tournament.id, draft)
          : AppRepositories.hostTournament.updateStaff(widget.tournament.id, editing, draft),
      editing == null ? OrganizerStrings.staffAdded : OrganizerStrings.staffUpdated,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _reset();
      await _load();
    }
  }

  Future<void> _remove(TournamentStaffMember m) async {
    if (!await _confirm(context, OrganizerStrings.staffRemoveConfirm(m.fullName), action: OrganizerStrings.remove)) {
      return;
    }
    if (!mounted) return;
    final ok = await _run(
      context,
      () => AppRepositories.hostTournament.removeStaff(widget.tournament.id, m.id),
      OrganizerStrings.staffRemoved,
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    return _Card(
      children: [
        Text(OrganizerStrings.staffTitle(staff?.length ?? 0), style: _titleStyle),
        const SizedBox(height: 6),
        if (_error != null && staff == null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else if (staff == null)
          const Center(child: CircularProgressIndicator())
        else
          for (final m in staff)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(m.role.label, style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8))),
                            ),
                          ],
                        ),
                        Text(
                          [
                            if (m.phone.isNotEmpty) m.phone,
                            if (m.accountId != null) OrganizerStrings.hasAccount,
                            if (m.note.isNotEmpty) m.note,
                          ].join(' · '),
                          style: _mutedStyle,
                        ),
                      ],
                    ),
                  ),
                  if (!_closed) ...[
                    TextButton(onPressed: _busy ? null : () => _startEdit(m), child: const Text(OrganizerStrings.edit)),
                    IconButton(
                      tooltip: OrganizerStrings.remove,
                      onPressed: _busy ? null : () => _remove(m),
                      icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
        if (!_closed) ..._form(),
      ],
    );
  }

  List<Widget> _form() => [
    const SizedBox(height: 6),
    DropdownButtonFormField<StaffRole>(
      key: ValueKey('role-$_editingId-${_role.name}'),
      initialValue: _role,
      isExpanded: true,
      decoration: _input('').copyWith(labelText: OrganizerStrings.role),
      items: [for (final r in StaffRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
      onChanged: (v) => setState(() => _role = v ?? StaffRole.referee),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 15,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _input('').copyWith(labelText: OrganizerStrings.phone),
            // Đổi số điện thoại thì phải tìm lại tài khoản (và bật / tắt nút Tìm).
            onChanged: (_) => setState(() => _accountId = null),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _looking || _phone.text.trim().isEmpty ? null : _find,
          child: Text(_looking ? OrganizerStrings.finding : OrganizerStrings.find),
        ),
      ],
    ),
    if (_accountId != null)
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          OrganizerStrings.accountLinked,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
        ),
      )
    else if (_role.needsAccount)
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(OrganizerStrings.accountNeeded, style: _mutedStyle),
      ),
    const SizedBox(height: 8),
    TextField(
      controller: _name,
      maxLength: 100,
      readOnly: _accountId != null,
      decoration: _input(_role.needsAccount ? OrganizerStrings.fullNameAuto : '')
          .copyWith(labelText: OrganizerStrings.fullName),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _note,
      maxLength: 200,
      decoration: _input('').copyWith(labelText: OrganizerStrings.note),
    ),
    const SizedBox(height: 8),
    Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      children: [
        if (_editingId != null)
          TextButton(onPressed: _busy ? null : _reset, child: const Text(OrganizerStrings.cancelEdit)),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(_editingId != null ? OrganizerStrings.save : OrganizerStrings.addStaff),
        ),
      ],
    ),
  ];
}
