import 'package:flutter/material.dart';

import '../../core/constants/owner_rules.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/court_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/owner/owner_actions.dart';
import '../../widgets/owner/session_card.dart';
import 'owner_scan_screen.dart';

/// Chi tiết một lượt sân: người chơi + trạng thái check-in, sân con, tiền, nút check-out.
/// Pop trả về `true` nếu đã có thay đổi để màn trước tải lại.
class OwnerSessionDetailScreen extends StatefulWidget {
  final CourtSession session;

  const OwnerSessionDetailScreen({super.key, required this.session});

  @override
  State<OwnerSessionDetailScreen> createState() => _OwnerSessionDetailScreenState();
}

class _OwnerSessionDetailScreenState extends State<OwnerSessionDetailScreen> {
  late CourtSession _session = widget.session;
  bool _changed = false;
  bool _checkingOut = false;
  bool _cancelling = false;

  Future<void> _reload() async {
    try {
      final s = await AppRepositories.owner.getSession(_session.id);
      if (mounted) setState(() => _session = s);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(OwnerStrings.loadError), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkIn(SessionPlayer p) async {
    final updated = await checkInPlayer(context, _session, p);
    if (updated != null && mounted) {
      setState(() {
        _session = updated;
        _changed = true;
      });
    }
  }

  Future<void> _scan() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerScanScreen(
          facilityId: _session.facilityId,
        ),
      ),
    );

    if (changed == true && mounted) {
      _changed = true;
      await _reload();
    }
  }

  Future<void> _checkOut() async {
    setState(() => _checkingOut = true);
    final updated = await checkOutSession(context, _session);
    if (!mounted) return;
    setState(() {
      _checkingOut = false;
      if (updated != null) {
        _session = updated;
        _changed = true;
      }
    });
  }

  /// Chủ sân hủy đơn: cảnh báo rõ Điểm phạt (tính trước theo luật BE), xác nhận rồi mới gọi BE.
  Future<void> _cancelBooking() async {
    final s = _session;
    final choice = await showDialog<({String reason, bool lockSlot})>(
      context: context,
      builder: (_) => _OwnerCancelDialog(session: s, now: DateTime.now()),
    );
    if (choice == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final result = await AppRepositories.owner.cancelBooking(s.id, reason: choice.reason, lockSlot: choice.lockSlot);
      if (!mounted) return;
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(OwnerStrings.cancelledMessage(result))));
      await _reload();
    } on OwnerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(OwnerStrings.loadError), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _cancelling = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final now = DateTime.now();
    final status = s.status(now);
    final canScan = status != SessionStatus.cancelled && status != SessionStatus.completed && s.isCheckInWindow(now);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(
            OwnerStrings.detailTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                children: [
                  Row(
                    children: [
                      Icon(sportIcon(s.sport), color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.sportLabel,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                      ),
                      SessionStatusChip(session: s, now: now),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoRow(Icons.storefront_outlined, s.facilityName),
                  _infoRow(Icons.schedule, Formatters.slotLabel(s.start, s.end)),
                  _infoRow(Icons.grid_view, s.assignedCourt),
                  _infoRow(
                    s.kind == SessionKind.lfg ? Icons.groups_outlined : Icons.receipt_long_outlined,
                    s.kind == SessionKind.lfg ? OwnerStrings.kindLfg : OwnerStrings.kindBooking,
                  ),
                  if (status == SessionStatus.upcoming || status == SessionStatus.waitingCheckIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        OwnerStrings.checkInWindow(
                          Formatters.time(s.checkInOpensAt),
                          Formatters.time(s.checkInClosesAt),
                        ),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          OwnerStrings.players,
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain, fontSize: 15),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          OwnerStrings.checkedInCount(s.checkedInCount, s.players.length),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < s.players.length; i++) _playerRow(s, s.players[i], i == 0, now),
                  if (s.players.any((p) => s.isAbsent(p, now)))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        OwnerStrings.absentNote,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                children: [
                  const Text(
                    OwnerStrings.money,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _moneyRow(OwnerStrings.totalPrice, s.totalPrice, bold: true),
                  _moneyRow(OwnerStrings.paidViaApp, s.paidViaApp),
                  if (s.remainingToCollect > 0) _moneyRow(OwnerStrings.remainingToCollect, s.remainingToCollect),
                  if (status == SessionStatus.completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        OwnerStrings.disbursed(s.paidViaApp),
                        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              if (s.canOwnerCancel) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelBooking,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text(OwnerStrings.cancelBooking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: (canScan || s.canCheckOut(now))
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (canScan)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _scan,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text(OwnerStrings.scanToCheckIn),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(color: AppColors.primaryGreen),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      if (canScan && s.canCheckOut(now)) const SizedBox(width: 12),
                      if (s.canCheckOut(now))
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checkingOut ? null : _checkOut,
                            icon: const Icon(Icons.logout),
                            label: const Text(OwnerStrings.checkOut),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _section({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.textMain)),
        ),
      ],
    ),
  );

  Widget _moneyRow(String label, int amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            Formatters.vnd(amount),
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: AppColors.textMain),
          ),
        ),
      ],
    ),
  );

  Widget _playerRow(CourtSession s, SessionPlayer p, bool isLeader, DateTime now) {
    final absent = s.isAbsent(p, now);
    final Widget trailing;
    if (p.isCheckedIn) {
      trailing = Text(
        OwnerStrings.checkedInAt(Formatters.time(p.checkedInAt!)),
        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600, fontSize: 12),
      );
    } else if (absent) {
      trailing = Text(
        OwnerStrings.absent,
        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12),
      );
    } else if (s.canCheckIn(p, now)) {
      trailing = TextButton(
        onPressed: () => _checkIn(p),
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
        child: const Text(OwnerStrings.checkIn),
      );
    } else {
      trailing = const Text(OwnerStrings.notCheckedIn, style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: p.isCheckedIn ? AppColors.lightGreen : AppColors.divider,
            child: Icon(
              p.isCheckedIn ? Icons.check : Icons.person_outline,
              size: 18,
              color: p.isCheckedIn ? AppColors.primaryGreen : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
                Text(
                  isLeader ? (s.kind == SessionKind.lfg ? OwnerStrings.host : OwnerStrings.booker) : p.ticketCode,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

/// Hộp thoại cảnh báo khi Chủ sân hủy đơn: Điểm phạt (và Fair Play nếu dưới 48h) hiện nổi bật,
/// kèm lý do (không bắt buộc) và tùy chọn khóa ca sân. Trả về lựa chọn khi bấm "Đồng ý Hủy".
class _OwnerCancelDialog extends StatefulWidget {
  final CourtSession session;
  final DateTime now;

  const _OwnerCancelDialog({required this.session, required this.now});

  @override
  State<_OwnerCancelDialog> createState() => _OwnerCancelDialogState();
}

class _OwnerCancelDialogState extends State<_OwnerCancelDialog> {
  final _reason = TextEditingController();
  bool _lockSlot = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Widget _row(String label, String value, {String? detail}) => Padding(
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

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final late = s.isLateOwnerCancel(widget.now);
    final percent = late ? OwnerCancelRules.latePenaltyPercent : OwnerCancelRules.earlyPenaltyPercent;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 44),
      title: const Text(
        OwnerStrings.cancelBookingTitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              late ? OwnerStrings.cancelLateWarning : OwnerStrings.cancelEarlyWarning,
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
                  _row(
                    OwnerStrings.cancelPenaltyLabel,
                    '−${Formatters.vnd(s.ownerCancelPenalty(widget.now))}',
                    detail: OwnerStrings.cancelPenaltyDetail(percent, s.totalPrice),
                  ),
                  if (late)
                    _row(OwnerStrings.cancelFairPlayLabel, OwnerStrings.cancelFairPlay(OwnerCancelRules.lateFairPlayPenalty)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(OwnerStrings.cancelWalletNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              OwnerStrings.cancelCustomerNote(OwnerCancelRules.customerVoucherPercent),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (s.kind == SessionKind.lfg) ...[
              const SizedBox(height: 4),
              const Text(OwnerStrings.cancelLfgNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: OwnerStrings.cancelReasonHint,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            CheckboxListTile(
              value: _lockSlot,
              onChanged: (v) => setState(() => _lockSlot = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text(OwnerStrings.cancelLockSlot, style: TextStyle(fontSize: 13)),
              subtitle: const Text(OwnerStrings.cancelLockSlotHint, style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerStrings.cancelBack)),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (reason: _reason.text.trim(), lockSlot: _lockSlot)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text(OwnerStrings.cancelConfirm),
        ),
      ],
    );
  }
}
