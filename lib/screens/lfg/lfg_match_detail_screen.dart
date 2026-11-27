import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
import '../../models/lfg_match.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/lfg/lfg_actions.dart';
import '../../widgets/lfg/lfg_match_card.dart';
import '../../widgets/lfg/lfg_ticket_qr.dart';
import '../../widgets/lfg/lfg_approval.dart';
import 'edit_lfg_match_screen.dart';
import '../../core/strings/community_strings.dart';
import '../../data/repositories/community_repository.dart';
import '../community/community_screen.dart';

class LfgMatchDetailScreen extends StatefulWidget {
  final String matchId;

  /// Dữ liệu có sẵn từ danh sách để hiện ngay trong lúc tải lại.
  final LfgMatch? initial;

  const LfgMatchDetailScreen({super.key, required this.matchId, this.initial});

  @override
  State<LfgMatchDetailScreen> createState() => _LfgMatchDetailScreenState();
}

class _LfgMatchDetailScreenState extends State<LfgMatchDetailScreen> {
  LfgMatch? _match;
  String? _myId;
  String? _error;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _match = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final match = await AppRepositories.lfg.getMatch(widget.matchId);
      final user = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _match = match;
        _myId = user?.id;
        _error = null;
      });
    } on LfgException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = LfgStrings.loadError);
    }
  }

  Future<void> _claim() async {
    final joined = await flashClaimMatch(context, _match!);
    if (joined != null) _load();
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(LfgStrings.keep)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Trước T−48h: hoàn 100%. Từ T−48h (chỉ khi [LfgRepository.lateLeaveAllowed]) là bùng kèo: không hoàn,
  /// cọc chuyển cho chủ kèo, −10 Fair Play → popup cảnh báo đỏ.
  Future<void> _leave() async {
    final m = _match!;
    final late = m.isLateLeave(DateTime.now());
    final isHost = m.isHostedBy(_myId!);
    final others = m.members.where((x) => x.userId != _myId).toList()..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final alone = others.isEmpty;
    final String? reason;
    if (late) {
      reason = await confirmLfgWithReason(
        context,
        title: LfgStrings.lateLeaveTitle,
        warning: LfgStrings.lateLeaveWarning,
        message: LfgStrings.confirmLateLeaveMessage(m.depositPerSlot),
        action: LfgStrings.lateLeaveConfirm,
      );
    } else {
      reason = await confirmLfgWithReason(
        context,
        title: alone ? LfgStrings.confirmCancelTitle : LfgStrings.confirmLeaveTitle,
        message: LfgStrings.confirmLeaveMessage(m.depositPerSlot, isHost: isHost, nextHost: others.firstOrNull?.name),
        action: alone ? LfgStrings.cancelMatch : LfgStrings.leave,
      );
    }
    if (reason == null) return;
    await _run(() async {
      final refund = await AppRepositories.lfg.leaveMatch(m.id, reason: reason);
      _snack(late && refund == 0 ? LfgStrings.lateLeftMessage : LfgStrings.leftMessage(refund));
    });
  }

  /// Host không rời được (BE), chỉ hủy kèo tới giờ chơi. Mọi người luôn được hoàn 100%.
  /// Dưới 48h (hủy đơn phương): cảnh báo gắt số giá sân bị trừ để bồi thường và −20 Fair Play.
  Future<void> _hostCancel() async {
    final m = _match!;
    final late = m.isLateHostCancel(DateTime.now());
    final ok = late
        ? await _confirmLateCancel(m)
        : await _confirm(LfgStrings.confirmCancelTitle, LfgStrings.hostCancelMessage(m.courtPrice), LfgStrings.cancelMatch);
    if (!ok) return;
    await _run(() async {
      await AppRepositories.lfg.cancelMatch(m.id);
      _snack(late ? LfgStrings.lateCancelledMessage(m.hostLateCancelLoss) : LfgStrings.hostCancelledMessage);
    });
  }

  Future<bool> _confirmLateCancel(LfgMatch m) async {
    final hasJoiners = m.joinerCount > 0;
    Widget row(String label, String value, {String? detail}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
                    if (detail != null)
                      Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red),
                ),
              ),
            ],
          ),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 44),
        title: const Text(
          LfgStrings.lateCancelTitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasJoiners ? LfgStrings.lateCancelWarning : LfgStrings.lateCancelWarningNoJoiner,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    if (hasJoiners) ...[
                      row(
                        LfgStrings.lateCancelLossLabel,
                        '−${Formatters.vnd(m.hostLateCancelLoss)}',
                        detail: LfgStrings.lateCancelLossDetail(m.courtPrice),
                      ),
                      row(
                        LfgStrings.lateCancelCompensation(m.joinerCount),
                        Formatters.vnd(m.lateCancelCompensationPerJoiner),
                      ),
                    ],
                    row(LfgStrings.lateCancelFairPlayLabel, LfgStrings.lateCancelFairPlay),
                  ],
                ),
              ),
              if (hasJoiners) ...[
                const SizedBox(height: 10),
                const Text(
                  LfgStrings.lateCancelRefundNote,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(LfgStrings.lateCancelBack)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(LfgStrings.lateCancelConfirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Rút yêu cầu vào kèo đang chờ chủ kèo duyệt (chưa trừ Điểm).
  Future<void> _withdraw() => _run(() async {
        await AppRepositories.lfg.leaveMatch(_match!.id);
        _snack(LfgStrings.withdrawnMessage);
      });

  Future<void> _acceptInvite() => _run(() async {
        await AppRepositories.lfg.acceptInvitation(_match!.id);
        _snack(LfgStrings.joinSuccess);
      });

  Future<void> _declineInvite() => _run(() async {
        await AppRepositories.lfg.declineInvitation(_match!.id);
        _snack(LfgStrings.declinedMessage);
      });

  // ---- Chủ kèo: duyệt / từ chối / loại người, sửa kèo ----

  Future<void> _approve(LfgMember p) => _run(() async {
        await AppRepositories.lfg.approveRequest(_match!.id, p.userId);
        _snack(LfgStrings.approvedMessage(p.name));
      });

  Future<void> _reject(LfgMember p) => _run(() async {
        await AppRepositories.lfg.rejectRequest(_match!.id, p.userId);
        _snack(LfgStrings.rejectedMessage(p.name));
      });

  Future<void> _remove(LfgMember p) async {
    if (!await _confirm(LfgStrings.removeTitle, LfgStrings.removeMessage(p.name), LfgStrings.remove)) return;
    await _run(() async {
      await AppRepositories.lfg.removeMember(_match!.id, p.userId);
      _snack(LfgStrings.removedMessage(p.name));
    });
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<LfgMatch>(
      context,
      MaterialPageRoute(builder: (_) => EditLfgMatchScreen(match: _match!)),
    );
    if (updated == null || !mounted) return;
    setState(() => _match = updated);
    _snack(LfgStrings.editSaved);
    _load();
  }

  /// Soạn sẵn câu như Web, hỏi xác nhận rồi đăng bài kèm thẻ kèo.
  Future<void> _shareToFeed() async {
    final m = _match!;
    final place = [?m.courtName, m.facilityName].where((s) => s.isNotEmpty).join(' - ');
    final when = '${Formatters.time(m.start)} ngày ${Formatters.date(m.start)}';
    final content = CommunityStrings.shareLfgContent(m.sport.label, m.slotsLeft, place, when);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(CommunityStrings.shareLfgTitle),
        content: Text('“$content”'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(CommunityStrings.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text(CommunityStrings.post),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await AppRepositories.community.createPost(content: content, lfgCardId: m.id, sport: m.sport);
      messenger.showSnackBar(SnackBar(
        content: const Text(CommunityStrings.shared),
        action: SnackBarAction(
          label: CommunityStrings.viewFeed,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
        ),
      ));
    } on CommunityException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(CommunityStrings.shareError), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _simulateJoin() => _run(() async {
        await (AppRepositories.lfg as SandboxLfgSimulator).simulatePlayerJoined(_match!.id);
      });

  /// Thông báo mới thay ngay thông báo cũ (chủ kèo duyệt / từ chối nhiều người liền tay).
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } on LfgException catch (e) {
      if (mounted) showLfgError(context, e.message);
    } catch (_) {
      if (mounted) showLfgError(context, LfgStrings.loadError);
    }
    await _load();
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    final now = DateTime.now();
    final isHost = m != null && _myId != null && m.isHostedBy(_myId!);
    final canSimulate =
        m != null && AppRepositories.lfg is SandboxLfgSimulator && isHost && m.status(now) == LfgStatus.open;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          LfgStrings.detailTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (canSimulate)
            IconButton(
              tooltip: LfgStrings.simulateJoin,
              onPressed: _isBusy ? null : _simulateJoin,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
        ],
      ),
      body: m == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                        TextButton(onPressed: _load, child: const Text(LfgStrings.retry)),
                      ],
                    ),
            )
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(m, now),
                  const SizedBox(height: 14),
                  _buildMembers(m),
                  if (_buildRequests(m) case final requests?) ...[
                    const SizedBox(height: 14),
                    requests,
                  ],
                  if (_myId != null && m.isMember(_myId!) && _hasActiveTicket(m, now)) ...[
                    const SizedBox(height: 14),
                    _buildTicket(m),
                  ],
                  const SizedBox(height: 14),
                  _section(
                    LfgStrings.rulesTitle,
                    Text(
                      LfgStrings.rules(
                        m.depositPerSlot,
                        m.format.isTeam,
                        hostPaysCourt: AppRepositories.lfg.hostPaysCourt,
                        hostCanLeave: AppRepositories.lfg.hostCanLeave,
                        lateLeave: AppRepositories.lfg.lateLeaveAllowed,
                      ),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: m == null ? null : _buildBottomBar(m, now),
    );
  }

  static bool _hasActiveTicket(LfgMatch m, DateTime now) =>
      m.status(now) != LfgStatus.cancelled && m.status(now) != LfgStatus.completed;

  Widget _section(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _kv(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            const SizedBox(width: 12),
            // Giá trị dài (vd. hạn đủ người) xuống dòng thay vì tràn ra ngoài màn hình hẹp.
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textMain),
              ),
            ),
          ],
        ),
      );

  Widget _buildHeader(LfgMatch m, DateTime now) {
    return _section(
      [m.sport.label, m.formatLabel, if (m.skillLevel != null) LfgStrings.skillTag(m.skillLevel!.label)].join(' • '),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lightGreen,
                child: Icon(sportIcon(m.sport), color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.facilityCourtLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    Text(m.city.isEmpty ? m.district : '${m.district}, ${m.city}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      Formatters.slotLabel(m.start, m.end),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                    ),
                    if (m.isTeamMatch)
                      Text(
                        m.challengerTeam == null
                            ? '${m.hostTeam!.name} • ${LfgStrings.waitingTeam}'
                            : LfgStrings.teamVs(m.hostTeam!.name, m.challengerTeam!.name),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LfgStatusChip(match: m, now: now),
              if (m.requireApproval) const LfgApprovalChip(),
            ],
          ),
          // Như Web: chủ kèo đăng kèo còn suất lên Bảng tin cộng đồng.
          if (_isHostOf(m) && m.canManage(now) && m.slotsLeft > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isBusy ? null : _shareToFeed,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text(CommunityStrings.shareLfg),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen, visualDensity: VisualDensity.compact),
              ),
            ),
          const Divider(height: 20, color: AppColors.divider),
          _kv(LfgStrings.courtPrice, Formatters.vnd(m.courtPrice)),
          _kv(LfgStrings.depositPerSlot, Formatters.vnd(m.depositPerSlot), color: AppColors.primaryGreen),
          _kv(LfgStrings.fillDeadline, '${Formatters.weekdayDayMonth(m.fillDeadline)} • ${Formatters.time(m.fillDeadline)}'),
          if (m.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(LfgStrings.hostNote, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(m.note, style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
          ],
        ],
      ),
    );
  }

  bool _isHostOf(LfgMatch m) => _myId != null && m.isHostedBy(_myId!);

  /// Chủ kèo quản lý người được: kèo chưa hủy, chưa tới giờ chơi. Kèo Đội vs Đội vào / rời theo cả đội nên không có.
  bool _canManagePeople(LfgMatch m) => _isHostOf(m) && !m.isTeamMatch && m.canManage(DateTime.now());

  Widget _smallButton(String label, IconData icon, Color color, VoidCallback onPressed, {bool filled = false}) {
    final style = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(filled ? Colors.white : color),
      backgroundColor: filled ? WidgetStatePropertyAll(color) : null,
      side: filled ? null : WidgetStatePropertyAll(BorderSide(color: color)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
    final onTap = _isBusy ? null : onPressed;
    return filled
        ? ElevatedButton(onPressed: onTap, style: style, child: child)
        : OutlinedButton(onPressed: onTap, style: style, child: child);
  }

  /// Chủ kèo: người đang chờ duyệt (Duyệt / Từ chối) và người đã rời / bị loại / bị từ chối (chỉ xem).
  Widget? _buildRequests(LfgMatch m) {
    if (!_isHostOf(m) || (m.pendingMembers.isEmpty && m.pastMembers.isEmpty)) return null;
    final manage = _canManagePeople(m);
    Widget person(LfgMember p, {required bool pending}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: pending ? AppColors.tagOrangeBg : AppColors.background,
                    child: Text(
                      p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: pending ? AppColors.tagOrangeText : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isEmpty ? LfgStrings.unnamedMember : p.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: pending ? AppColors.textMain : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${LfgStrings.fairPlay(p.fairPlayScore)} • ${LfgStrings.memberStatus(p.status)}',
                          style: TextStyle(fontSize: 12, color: pending ? AppColors.tagOrangeText : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (pending && manage)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 48),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _smallButton(LfgStrings.approve, Icons.check, AppColors.primaryGreen, () => _approve(p), filled: true),
                      _smallButton(LfgStrings.reject, Icons.close, AppColors.textSecondary, () => _reject(p)),
                    ],
                  ),
                ),
            ],
          ),
        );

    return _section(
      m.pendingMembers.isEmpty ? LfgStrings.pastSection : '${LfgStrings.pendingSection} (${m.pendingMembers.length})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in m.pendingMembers) person(p, pending: true),
          if (m.pendingMembers.isNotEmpty && m.pastMembers.isNotEmpty) ...[
            const Divider(height: 24, color: AppColors.divider),
            const Text(
              LfgStrings.pastSection,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ],
          for (final p in m.pastMembers) person(p, pending: false),
        ],
      ),
    );
  }

  Widget _buildMembers(LfgMatch m) {
    if (m.isTeamMatch) return _buildTeamMembers(m);
    final manage = _canManagePeople(m);
    final rows = <Widget>[];
    for (var i = 0; i < m.totalSlots; i++) {
      if (i < m.members.length) {
        final member = m.members[i];
        final isMe = member.userId == _myId;
        rows.add(ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            backgroundColor: member.isHost ? AppColors.primaryGreen : AppColors.lightGreen,
            // BE không trả danh sách người chơi thì chỗ đã có người không có tên.
            child: Text(
              member.name.isEmpty ? '?' : member.name.characters.first.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: member.isHost ? Colors.white : AppColors.primaryGreen),
            ),
          ),
          title: Text(
            '${member.name.isEmpty ? LfgStrings.unnamedMember : member.name}${isMe ? ' ${LfgStrings.you}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          subtitle: member.name.isEmpty ? null : Text(LfgStrings.fairPlay(member.fairPlayScore)),
          trailing: member.isHost
              ? const Text(LfgStrings.host, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen))
              : manage && member.userId.isNotEmpty
                  ? _smallButton(LfgStrings.remove, Icons.person_remove_outlined, Colors.red, () => _remove(member))
                  : null,
        ));
      } else {
        final held = i < m.members.length + m.heldSlots;
        rows.add(ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            backgroundColor: held ? AppColors.tagOrangeBg : AppColors.background,
            child: Icon(held ? Icons.hourglass_top : Icons.person_outline,
                color: held ? AppColors.tagOrangeText : AppColors.textSecondary),
          ),
          title: Text(
            held ? LfgStrings.heldSlot : LfgStrings.emptySlot,
            style: TextStyle(color: held ? AppColors.tagOrangeText : AppColors.textSecondary),
          ),
        ));
      }
    }
    return _section(
      '${LfgStrings.members} (${LfgStrings.slotsFilled(m.members.length, m.totalSlots, m.format.isTeam)})',
      Column(children: rows),
    );
  }

  /// Kèo Đội vs Đội: người chơi chia theo phe (A = đội chủ kèo, B = đội nhận kèo).
  Widget _buildTeamMembers(LfgMatch m) {
    Widget sideHeader(String side, String? team) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            '$side • ${team ?? LfgStrings.waitingTeam}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        );
    Widget row(LfgMember member) {
      final isMe = member.userId == _myId;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: CircleAvatar(
          backgroundColor: member.isHost ? AppColors.primaryGreen : AppColors.lightGreen,
          child: Text(
            member.name.isEmpty ? '?' : member.name.characters.first.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: member.isHost ? Colors.white : AppColors.primaryGreen),
          ),
        ),
        title: Text(
          '${member.name}${isMe ? ' ${LfgStrings.you}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        subtitle: Text(LfgStrings.fairPlay(member.fairPlayScore)),
        trailing: member.isHost
            ? const Text(LfgStrings.host, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen))
            : null,
      );
    }

    final sideA = m.members.where((x) => x.isHost || x.side != 'B').toList();
    final sideB = m.members.where((x) => !x.isHost && x.side == 'B').toList();
    return _section(
      '${LfgStrings.members} (${LfgStrings.slotsFilled(m.members.length, m.totalSlots, false)})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sideHeader(LfgStrings.sideA, m.hostTeam?.name),
          ...sideA.map(row),
          sideHeader(LfgStrings.sideB, m.challengerTeam?.name),
          ...sideB.map(row),
        ],
      ),
    );
  }

  Widget _buildTicket(LfgMatch m) {
    return _section(
      LfgStrings.yourTicket,
      Column(
        children: [
          LfgTicketQr(match: m, userId: _myId!),
          const SizedBox(height: 6),
          const Text(
            LfgStrings.ticketNote,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(LfgMatch m, DateTime now) {
    final isMember = _myId != null && m.isMember(_myId!);
    final status = m.status(now);

    final active = (status == LfgStatus.open || status == LfgStatus.confirmed) && now.isBefore(m.start);
    final repo = AppRepositories.lfg;

    Widget? button;
    if (m.myStatus == LfgMyStatus.invited && active) {
      button = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(LfgStrings.invitedNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _redButton(LfgStrings.declineInvite, _declineInvite)),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBusy ? null : _acceptInvite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.authPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(LfgStrings.acceptInvite(m.depositPerSlot), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (m.myStatus == LfgMyStatus.pendingApproval && active) {
      button = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(LfgStrings.pendingApprovalNote,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _redButton(LfgStrings.withdrawRequest, _withdraw)),
        ],
      );
    } else if (isMember && active && m.isHostedBy(_myId!)) {
      final Widget? exit;
      if (!repo.hostCanLeave) {
        // Host (BE): không rời được, hủy kèo được tới giờ chơi; dưới 48h là hủy đơn phương (bị phạt, xem _hostCancel).
        exit = m.canHostCancel(now) ? _redButton(LfgStrings.cancelMatch, _hostCancel) : null;
      } else if (now.isBefore(m.leaveDeadline)) {
        // Bản giả lập: host rời thì chuyển quyền host; còn một mình thì rời là hủy kèo.
        exit = _redButton(m.members.length == 1 ? LfgStrings.cancelMatch : LfgStrings.leave, _leave);
      } else {
        exit = _lateActions(m, now);
      }
      // Sửa kèo cùng điều kiện với Web: kèo chưa hủy, chưa tới giờ chơi.
      final edit = m.canManage(now) ? _editButton() : null;
      button = exit != null && edit != null
          ? Row(
              children: [
                Expanded(child: edit),
                const SizedBox(width: 10),
                Expanded(child: exit),
              ],
            )
          : exit ?? edit;
    } else if (!isMember && m.myStatus == null && m.isClaimable(now)) {
      final asks = m.requireApproval && !m.isTeamMatch;
      button = ElevatedButton.icon(
        onPressed: _isBusy ? null : _claim,
        icon: Icon(asks ? Icons.send : Icons.flash_on, color: Colors.white),
        label: Text(
            asks ? LfgStrings.sendRequestLong : '${LfgStrings.flashClaim} • ${Formatters.vnd(m.depositPerSlot)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.authPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (isMember && active && now.isBefore(m.leaveDeadline)) {
      // Trước T−48h ai cũng rời được (hoàn 100%). Host còn một mình: rời cũng là hủy kèo.
      final alone = m.members.length == 1;
      button = _redButton(alone ? LfgStrings.cancelMatch : LfgStrings.leave, _leave);
    } else if (isMember && active) {
      button = _lateActions(m, now);
    }
    if (button == null) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.divider))),
        child: SizedBox(width: double.infinity, child: button),
      ),
    );
  }

  /// Sau T−48h (người tham gia): BE vẫn cho rời tới giờ chơi nhưng không hoàn; bản giả lập không cho rời.
  Widget _lateActions(LfgMatch m, DateTime now) {
    final canLateLeave = AppRepositories.lfg.lateLeaveAllowed && !m.isHostedBy(_myId!) && now.isBefore(m.start);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          canLateLeave ? LfgStrings.lateLeaveNote : LfgStrings.tooLateNote,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (canLateLeave) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _redButton(LfgStrings.leave, _leave)),
        ],
      ],
    );
  }

  Widget _editButton() => OutlinedButton.icon(
        onPressed: _isBusy ? null : _edit,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text(LfgStrings.editMatch, style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _redButton(String label, VoidCallback onPressed) => OutlinedButton(
        onPressed: _isBusy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
