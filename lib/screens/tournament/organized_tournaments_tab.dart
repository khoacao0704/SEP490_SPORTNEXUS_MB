import 'package:flutter/material.dart';

import '../../core/constants/tournament_rules.dart';
import '../../core/strings/organizer_strings.dart';
import '../../core/strings/player_tournament_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/identity_verification.dart';
import '../../models/organized_tournament.dart';
import '../../theme/app_colors.dart';
import '../profile/identity_verification_screen.dart';
import 'create_tournament_screen.dart';
import 'organized_tournament_screen.dart';

/// Tab "Giải tôi tổ chức": nút tạo giải (khóa khi Fair Play < 90 hoặc CCCD chưa duyệt), lọc theo nhóm, danh sách.
/// Chủ sân dùng lại tab này: [ownerMode] bỏ điều kiện Fair Play / CCCD, tạo giải tại [ownerFacility] (cơ sở đang quản lý);
/// [facilityScope] = giải người khác tổ chức tại cơ sở của tôi (chỉ xem và giữ ca, không có nút tạo).
class OrganizedTournamentsTab extends StatefulWidget {
  final bool ownerMode;
  final FacilityOption? ownerFacility;
  final bool facilityScope;

  const OrganizedTournamentsTab({super.key, this.ownerMode = false, this.ownerFacility, this.facilityScope = false});

  @override
  State<OrganizedTournamentsTab> createState() => _OrganizedTournamentsTabState();
}

class _OrganizedTournamentsTabState extends State<OrganizedTournamentsTab> with AutomaticKeepAliveClientMixin {
  List<OrganizedTournament>? _items;
  String? _error;
  OrganizedGroup? _filter;
  String? _fairPlayBlock;
  IdentityStatus? _kyc;
  bool _kycKnown = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadEligibility();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await AppRepositories.hostTournament.getMine(facilityScope: widget.facilityScope);
      if (mounted) setState(() => _items = items);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = OrganizerStrings.loadError);
    }
  }

  /// Chưa tải được điểm / hồ sơ thì không chặn, để BE quyết (như Web).
  Future<void> _loadEligibility() async {
    if (widget.ownerMode) return; // Chủ sân: chỉ cần cơ sở đã duyệt.
    try {
      final user = await AppRepositories.auth.getCurrentUser();
      if (mounted) setState(() => _fairPlayBlock = TournamentRules.fairPlayBlock(user?.fairPlayScore));
    } catch (_) {}
    try {
      final v = await AppRepositories.identity.getMyVerification();
      if (mounted) {
        setState(() {
          _kyc = v?.status;
          _kycKnown = true;
        });
      }
    } catch (_) {}
  }

  String? get _kycBlock {
    if (!_kycKnown || _kyc == IdentityStatus.approved) return null;
    return _kyc == IdentityStatus.pending ? OrganizerStrings.kycPending : OrganizerStrings.kycRequired;
  }

  bool get _blocked => widget.ownerMode ? widget.ownerFacility == null : _fairPlayBlock != null || _kycBlock != null;

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateTournamentScreen(fixedFacility: widget.ownerFacility)),
    );
    if (created == true) _load();
  }

  Future<void> _open(OrganizedTournament t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrganizedTournamentScreen(tournamentId: t.id, ownerMode: widget.ownerMode)),
    );
    _load();
  }

  Future<void> _verify() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()));
    _loadEligibility();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _items;
    final shown = items == null
        ? const <OrganizedTournament>[]
        : [
            for (final t in items)
              if (_filter == null || t.group == _filter) t,
          ];
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), _loadEligibility()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!widget.facilityScope)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _blocked ? null : _create,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(OrganizerStrings.createNew),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_blocked && !widget.facilityScope) ...[
            const SizedBox(height: 12),
            widget.ownerMode ? _ownerBanner() : _blockBanner(),
          ],
          const SizedBox(height: 12),
          if (items != null && items.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(null, OrganizerStrings.all, items.length),
                for (final g in OrganizedGroup.values) _chip(g, g.label, items.where((t) => t.group == g).length),
              ],
            ),
          const SizedBox(height: 12),
          if (_error != null && items == null)
            _message(_error!, retry: true)
          else if (items == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            _message(widget.facilityScope ? OrganizerStrings.emptyAtFacility : OrganizerStrings.empty)
          else
            for (final t in shown) _OrganizedCard(tournament: t, onTap: () => _open(t)),
        ],
      ),
    );
  }

  Widget _chip(OrganizedGroup? group, String label, int count) {
    final selected = _filter == group;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: count == 0 && group != null ? null : (_) => setState(() => _filter = group),
      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.primaryGreen : AppColors.textMain,
      ),
    );
  }

  Widget _ownerBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
    child: const Text(OrganizerStrings.noFacility, style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A))),
  );

  Widget _blockBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF1D4ED8), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  if (_fairPlayBlock != null) '$_fairPlayBlock ${OrganizerStrings.fairPlayHint}',
                  ?_kycBlock,
                  OrganizerStrings.stillManage,
                ].join(' '),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
        if (_kycBlock != null && _kyc != IdentityStatus.pending)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _verify, child: const Text(OrganizerStrings.verifyNow)),
          ),
      ],
    ),
  );

  Widget _message(String text, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (retry) TextButton(onPressed: _load, child: const Text(OrganizerStrings.retry)),
      ],
    ),
  );
}

/// Nhãn trạng thái giải tôi tổ chức (theo duyệt trước).
class OrganizedStatusChip extends StatelessWidget {
  final OrganizedTournament tournament;

  const OrganizedStatusChip({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final (bg, fg) = switch (t.group) {
      OrganizedGroup.cancelled => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      OrganizedGroup.finished => (const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
      OrganizedGroup.pending =>
        t.isRejected
            ? (const Color(0xFFFEE2E2), const Color(0xFFB91C1C))
            : (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      OrganizedGroup.inProgress => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      OrganizedGroup.open => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        t.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _OrganizedCard extends StatelessWidget {
  final OrganizedTournament tournament;
  final VoidCallback onTap;

  const _OrganizedCard({required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 6),
                OrganizedStatusChip(tournament: t),
                const SizedBox(height: 6),
                Text(
                  [
                    if (t.sportName.isNotEmpty) t.sportName,
                    if (t.facilityName.isNotEmpty) t.facilityName,
                    if (t.start != null) PlayerTournamentStrings.dateRange(t.start!, t.end ?? t.start!),
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.type.label} • ${t.registeredCount}/${t.maxParticipants} • ${PlayerTournamentStrings.fee(t.entryFee)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
                if (t.isRejected && t.approvalNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    OrganizerStrings.rejectedBanner(t.approvalNote),
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
