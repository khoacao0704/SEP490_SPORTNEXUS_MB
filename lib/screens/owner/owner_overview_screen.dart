import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';
import '../../widgets/owner/stat_grid.dart';
import 'listing_fee_screen.dart';
import 'owner_booking_detail_screen.dart';

/// Tổng quan hôm nay của cơ sở đang chọn: số đơn, chờ check-in, đã check-in, doanh thu dự kiến
/// và "Khách đặt sân hôm nay" (đơn PAID / CHECKED_IN). Đợt 5 làm lại đủ như Dashboard Web.
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
  OwnerBookingPage _today = OwnerBookingPage.empty;
  bool _loading = true;
  String? _error;
  int _seq = 0;

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

  Future<void> _load() async {
    final facilityId = widget.facilityId;
    if (facilityId == null) {
      setState(() => _loading = false);
      return;
    }
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppRepositories.owner.getBookings(facilityId: facilityId, date: DateTime.now(), pageSize: 100);
      if (mounted && seq == _seq) {
        setState(() {
          _today = page;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() {
          _loading = false;
          _error = ownerErrorMessage(e);
        });
      }
    }
  }

  Future<void> _open(OwnerBooking b) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerBookingDetailScreen(bookingId: b.id, onOpenSchedule: widget.onOpenSchedule)),
    );
    if (changed == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = _today.items;
    final waiting = items.where((b) => b.status == OwnerBookingStatus.paid).length;
    final checked = items.where((b) => b.status == OwnerBookingStatus.checkedIn).length;
    final customers = items
        .where((b) => b.status == OwnerBookingStatus.paid || b.status == OwnerBookingStatus.checkedIn)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

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
            if (widget.facilityId == null)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Text(OwnerStrings.noFacilityHint, textAlign: TextAlign.center),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              )
            else ...[
              StatGrid(
                children: [
                  _stat(Icons.event_note, OwnerStrings.statToday, '${_today.total}'),
                  _stat(Icons.hourglass_top, OwnerStrings.statWaiting, '$waiting'),
                  _stat(Icons.how_to_reg, OwnerStrings.statCheckedIn, '$checked'),
                  _stat(Icons.account_balance_wallet_outlined, OwnerStrings.statExpected, Formatters.vnd(_today.revenue)),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                OwnerStrings.todayCustomers,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 10),
              if (customers.isEmpty)
                const Text(OwnerStrings.noTodayCustomers, style: TextStyle(color: AppColors.textSecondary))
              else
                for (final b in customers)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: ListTile(
                      onTap: () => _open(b),
                      title: Text(
                        '${b.customerName ?? '—'}${b.isWalkIn ? OwnerStrings.walkInShort : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${b.courtName} • ${Formatters.timeRange(b.start, b.end)}'),
                      trailing: BookingStatusBadge(b.status),
                    ),
                  ),
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
                  child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            ),
          ],
        ),
      );
}
