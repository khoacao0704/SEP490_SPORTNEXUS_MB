import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/court_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/session_card.dart';
import 'listing_fee_screen.dart';
import 'owner_session_detail_screen.dart';

/// Tổng quan hôm nay: số liệu nhanh, lượt sân cần xử lý (chờ check-in / chờ check-out), lượt sắp tới.
class OwnerOverviewScreen extends StatefulWidget {
  final String ownerName;
  final String? facilityId;
  final int revision;
  final Widget facilitySelector;
  final VoidCallback onChanged;
  final VoidCallback onOpenSchedule;

  /// Chuông thông báo trên AppBar.
  final Widget? notificationBell;

  const OwnerOverviewScreen({
    super.key,
    required this.ownerName,
    required this.facilityId,
    required this.revision,
    required this.facilitySelector,
    required this.onChanged,
    required this.onOpenSchedule,
    this.notificationBell,
  });

  @override
  State<OwnerOverviewScreen> createState() => _OwnerOverviewScreenState();
}

class _OwnerOverviewScreenState extends State<OwnerOverviewScreen> {
  List<CourtSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OwnerOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityId != widget.facilityId || oldWidget.revision != widget.revision) _load();
  }

  /// Chỉ nhận kết quả của lần tải mới nhất (đổi cơ sở / ngày / tháng liên tục).
  int _loadSeq = 0;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await AppRepositories.owner.getSessions(day: DateTime.now(), facilityId: widget.facilityId);
      if (mounted && seq == _loadSeq) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _loadSeq) {
        setState(() {
          _loading = false;
          _error = OwnerStrings.loadError;
        });
      }
    }
  }

  Future<void> _open(CourtSession s) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerSessionDetailScreen(session: s)),
    );
    if (changed == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = _sessions.where((s) => s.status(now) != SessionStatus.cancelled).toList();
    int count(SessionStatus st) => active.where((s) => s.status(now) == st).length;
    final disbursed = active
        .where((s) => s.status(now) == SessionStatus.completed)
        .fold(0, (sum, s) => sum + s.paidViaApp);
    final needAction = active
        .where((s) => s.status(now) == SessionStatus.waitingCheckIn || s.isOverdueCheckOut(now))
        .toList();
    final nextUp = active.where((s) => s.status(now) == SessionStatus.upcoming).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: widget.facilitySelector,
        actions: [?widget.notificationBell],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              OwnerStrings.greeting(widget.ownerName),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 2),
            Text(
              '${OwnerStrings.today} • ${Formatters.weekdayDayMonth(now)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListingFeeBanner(revision: widget.revision),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  _stat(Icons.event_note, OwnerStrings.statSessions, '${active.length}'),
                  _stat(Icons.hourglass_top, OwnerStrings.statWaiting, '${count(SessionStatus.waitingCheckIn)}'),
                  _stat(Icons.sports, OwnerStrings.statPlaying, '${count(SessionStatus.playing)}'),
                  _stat(Icons.account_balance_wallet_outlined, OwnerStrings.statDisbursed, Formatters.vnd(disbursed)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                OwnerStrings.revenueComingSoon,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _header(OwnerStrings.needAction),
              if (needAction.isEmpty)
                _empty(OwnerStrings.noAction)
              else
                for (final s in needAction)
                  SessionCard(session: s, now: now, showFacility: widget.facilityId == null, onTap: () => _open(s)),
              const SizedBox(height: 12),
              _header(OwnerStrings.nextUp),
              if (nextUp.isEmpty)
                _empty(OwnerStrings.noNextUp)
              else
                for (final s in nextUp)
                  SessionCard(session: s, now: now, showFacility: widget.facilityId == null, onTap: () => _open(s)),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: widget.onOpenSchedule,
                  icon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
                  label: const Text(
                    OwnerStrings.viewSchedule,
                    style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
        ),
      ],
    ),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
    ),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
  );
}
