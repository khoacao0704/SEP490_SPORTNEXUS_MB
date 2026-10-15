import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
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
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const OwnerScanScreen()));
    if (changed == true) {
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
                  _infoRow(Icons.grid_view, s.assignedCourt ?? OwnerStrings.noCourtYet),
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
                      Text(
                        OwnerStrings.checkedInCount(s.checkedInCount, s.players.length),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
        Text(
          Formatters.vnd(amount),
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: AppColors.textMain),
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
          trailing,
        ],
      ),
    );
  }
}
