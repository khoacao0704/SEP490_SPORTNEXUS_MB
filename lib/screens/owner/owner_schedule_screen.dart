import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/court_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/session_card.dart';
import 'owner_session_detail_screen.dart';

/// Lịch đặt theo ngày (hôm qua tới 6 ngày tới) của cơ sở đang chọn.
class OwnerScheduleScreen extends StatefulWidget {
  final String? facilityId;
  final int revision;
  final Widget facilitySelector;
  final VoidCallback onChanged;

  const OwnerScheduleScreen({
    super.key,
    required this.facilityId,
    required this.revision,
    required this.facilitySelector,
    required this.onChanged,
  });

  @override
  State<OwnerScheduleScreen> createState() => _OwnerScheduleScreenState();
}

class _OwnerScheduleScreenState extends State<OwnerScheduleScreen> {
  late DateTime _day = _today();
  List<CourtSession> _sessions = [];
  bool _loading = true;
  String? _error;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OwnerScheduleScreen oldWidget) {
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
      final sessions = await AppRepositories.owner.getSessions(day: _day, facilityId: widget.facilityId);
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
    final today = _today();
    final days = [for (var i = -1; i <= 6; i++) DateTime(today.year, today.month, today.day + i)];
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: widget.facilitySelector,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = days[i];
                final selected = d == _day;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => _day = d);
                    _load();
                  },
                  child: Container(
                    width: 56,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryGreen : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d == today ? OwnerStrings.today : Formatters.weekday(d),
                          style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.dayMonth(d),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    _message(_error!)
                  else if (_sessions.isEmpty)
                    _message(OwnerStrings.emptyDay)
                  else
                    for (final s in _sessions)
                      SessionCard(session: s, now: now, showFacility: widget.facilityId == null, onTap: () => _open(s)),
                ],
              ),
      ),
    );
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.only(top: 80),
    child: Column(
      children: [
        const Icon(Icons.event_busy, size: 48, color: AppColors.cardBorder),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
