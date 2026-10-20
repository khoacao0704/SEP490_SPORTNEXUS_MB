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

  Future<void> _leave() async {
    final m = _match!;
    final isHost = m.isHostedBy(_myId!);
    final others = m.members.where((x) => x.userId != _myId).toList()..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final message = LfgStrings.confirmLeaveMessage(
      m.depositPerSlot,
      isHost: isHost,
      nextHost: others.firstOrNull?.name,
    );
    final alone = others.isEmpty;
    if (!await _confirm(
      alone ? LfgStrings.confirmCancelTitle : LfgStrings.confirmLeaveTitle,
      message,
      alone ? LfgStrings.cancelMatch : LfgStrings.leave,
    )) {
      return;
    }
    await _run(() async {
      final refund = await AppRepositories.lfg.leaveMatch(m.id);
      _snack(LfgStrings.leftMessage(refund));
    });
  }

  /// Host không rời được (BE): hủy kèo, mọi người được hoàn 100%.
  Future<void> _hostCancel() async {
    final m = _match!;
    if (!await _confirm(LfgStrings.confirmCancelTitle, LfgStrings.hostCancelMessage(m.courtPrice), LfgStrings.cancelMatch)) {
      return;
    }
    await _run(() async {
      await AppRepositories.lfg.cancelMatch(m.id);
      _snack(LfgStrings.hostCancelledMessage);
    });
  }

  /// Rút yêu cầu vào kèo đang chờ chủ kèo duyệt (chưa trừ tiền).
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

  Future<void> _requestCancel() async {
    final m = _match!;
    final deadline = '${Formatters.time(m.cancelRequestDeadline)} ${Formatters.weekdayDayMonth(m.cancelRequestDeadline)}';
    final ok = await _confirm(
      LfgStrings.confirmRequestTitle,
      LfgStrings.confirmRequestMessage(m.members.length - 1, deadline),
      LfgStrings.sendRequest,
    );
    if (!ok) return;
    await _run(() async {
      await AppRepositories.lfg.requestCancel(m.id);
      _snack(LfgStrings.requestSent);
    });
  }

  Future<void> _respond(bool approve) => _run(() async {
        final updated = await AppRepositories.lfg.respondCancel(_match!.id, approve: approve);
        _snack(approve
            ? (updated.cancelReason != null ? LfgStrings.mutualCancelledMessage : LfgStrings.waitingOthers)
            : LfgStrings.rejectedMessage);
      });

  Future<void> _simulateRespond(bool approve) => _run(() async {
        final updated =
            await (AppRepositories.lfg as SandboxLfgSimulator).simulateOthersRespond(_match!.id, approve: approve);
        if (updated.cancelReason != null) _snack(LfgStrings.mutualCancelledMessage);
      });

  Future<void> _simulateJoin() => _run(() async {
        await (AppRepositories.lfg as SandboxLfgSimulator).simulatePlayerJoined(_match!.id);
      });

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                  if (_myId != null && m.isMember(_myId!) && m.activeCancelRequest(now) != null) ...[
                    const SizedBox(height: 14),
                    _buildCancelRequest(m, m.activeCancelRequest(now)!),
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
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
      '${m.sport.label} • ${m.formatLabel}',
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LfgStatusChip(match: m, now: now),
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

  Widget _buildMembers(LfgMatch m) {
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
            child: Text(
              member.name.characters.first.toUpperCase(),
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

  Widget _buildCancelRequest(LfgMatch m, LfgCancelRequest request) {
    final iApproved = request.hasApproved(_myId!);
    final approvedCount = m.members.where((x) => request.hasApproved(x.userId)).length;
    final deadline = '${Formatters.time(m.cancelRequestDeadline)} ${Formatters.weekdayDayMonth(m.cancelRequestDeadline)}';
    final isSandbox = AppRepositories.lfg is SandboxLfgSimulator;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tagOrangeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tagOrangeText),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote_outlined, color: AppColors.tagOrangeText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LfgStrings.cancelRequestBy(
                    request.requestedBy == _myId ? '${request.requestedByName} ${LfgStrings.you}' : request.requestedByName,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ),
              Text(
                LfgStrings.approvalsCount(approvedCount, m.members.length),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final member in m.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    request.hasApproved(member.userId) ? Icons.check_circle : Icons.schedule,
                    size: 16,
                    color: request.hasApproved(member.userId) ? AppColors.primaryGreen : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${member.name}${member.userId == _myId ? ' ${LfgStrings.you}' : ''}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                    ),
                  ),
                  Text(
                    request.hasApproved(member.userId) ? LfgStrings.approved : LfgStrings.notAnswered,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            LfgStrings.cancelRequestDeadline(deadline),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (iApproved)
            const Text(
              LfgStrings.waitingOthers,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : () => _respond(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMain,
                      side: const BorderSide(color: AppColors.cardBorder),
                      backgroundColor: AppColors.white,
                    ),
                    child: const Text(LfgStrings.reject),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : () => _respond(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text(LfgStrings.approve),
                  ),
                ),
              ],
            ),
          if (isSandbox) ...[
            const Divider(height: 20),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: _isBusy ? null : () => _simulateRespond(true),
                  child: const Text(LfgStrings.simulateApprove, style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: _isBusy ? null : () => _simulateRespond(false),
                  child: const Text(LfgStrings.simulateReject, style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
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
    } else if (isMember && active && m.isHostedBy(_myId!) && !repo.hostCanLeave) {
      // Host (BE): không rời được; trước T−48h hủy kèo, sau đó như mọi người.
      button = now.isBefore(m.leaveDeadline)
          ? _redButton(LfgStrings.cancelMatch, _hostCancel)
          : _lateActions(m, now, status);
    } else if (!isMember && m.isClaimable(now)) {
      button = ElevatedButton.icon(
        onPressed: _isBusy ? null : _claim,
        icon: const Icon(Icons.flash_on, color: Colors.white),
        label: Text('${LfgStrings.flashClaim} • ${Formatters.vnd(m.depositPerSlot)}',
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
      button = _lateActions(m, now, status);
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

  /// Sau T−48h: từ T−48h tới T−24h kèo đã chốt chỉ hủy được khi tất cả đồng ý; sau T−24h không hủy được.
  Widget _lateActions(LfgMatch m, DateTime now, LfgStatus status) {
    final canRequest = status == LfgStatus.confirmed && now.isBefore(m.cancelRequestDeadline);
    final hasRequest = m.activeCancelRequest(now) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          canRequest ? LfgStrings.confirmedNote : LfgStrings.tooLateNote,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (canRequest && !hasRequest) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _redButton(LfgStrings.requestCancel, _requestCancel)),
        ],
      ],
    );
  }

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
