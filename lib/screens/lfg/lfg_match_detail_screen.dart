import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
import '../../models/lfg_match.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/lfg/lfg_actions.dart';
import '../../widgets/lfg/lfg_match_card.dart';

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
    final reopens = !m.locked;
    if (!await _confirm(LfgStrings.confirmLeaveTitle, LfgStrings.confirmLeaveMessage(m.depositPerSlot, reopens), LfgStrings.leave)) {
      return;
    }
    await _run(() async {
      final lost = await AppRepositories.lfg.leaveMatch(m.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LfgStrings.leftMessage(lost))));
    });
  }

  Future<void> _cancel() async {
    final m = _match!;
    final others = m.members.where((x) => !x.isHost).length;
    if (!await _confirm(
      LfgStrings.confirmCancelTitle,
      LfgStrings.confirmCancelMessage(m.depositPerSlot, others),
      LfgStrings.cancelMatch,
    )) {
      return;
    }
    await _run(() async {
      await AppRepositories.lfg.cancelMatch(m.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(LfgStrings.cancelledMessage)));
      }
    });
  }

  Future<void> _simulateJoin() => _run(() async {
        await (AppRepositories.lfg as SandboxLfgSimulator).simulatePlayerJoined(_match!.id);
      });

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
                  if (_myId != null && m.isMember(_myId!) && _hasActiveTicket(m, now)) ...[
                    const SizedBox(height: 14),
                    _buildTicket(m),
                  ],
                  const SizedBox(height: 14),
                  _section(
                    LfgStrings.rulesTitle,
                    Text(
                      LfgStrings.rules(m.depositPerSlot, m.format.isTeam),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: m == null ? null : _buildBottomBar(m, now, isHost),
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
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textMain)),
          ],
        ),
      );

  Widget _buildHeader(LfgMatch m, DateTime now) {
    return _section(
      '${m.sport.label} • ${m.format.label}',
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
                    Text(m.facilityName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    Text('${m.district}, ${m.city}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
    final code = m.ticketCode(_myId!);
    return _section(
      LfgStrings.yourTicket,
      Column(
        children: [
          Center(child: QrImageView(data: code, size: 180, backgroundColor: Colors.white)),
          const SizedBox(height: 6),
          SelectableText(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
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

  Widget? _buildBottomBar(LfgMatch m, DateTime now, bool isHost) {
    final isMember = _myId != null && m.isMember(_myId!);
    final active = _hasActiveTicket(m, now);

    Widget? button;
    if (!isMember && m.isClaimable(now)) {
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
    } else if (isMember && active) {
      button = OutlinedButton(
        onPressed: _isBusy ? null : (isHost ? _cancel : _leave),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(isHost ? LfgStrings.cancelMatch : LfgStrings.leave, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
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
}
