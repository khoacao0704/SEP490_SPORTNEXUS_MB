import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_booking.dart';
import '../../theme/app_colors.dart';
import 'owner_badges.dart';
import 'owner_cancel_dialog.dart';

/// Danh sách đơn của cơ sở (ListView ở trang Đơn đặt sân của Web): lọc từ–đến ngày, trạng thái,
/// tìm theo tên / SĐT khách, phân trang 15 đơn, số liệu tổng và nút Chi tiết / Hủy đơn.
class OwnerBookingList extends StatefulWidget {
  final String facilityId;
  final int revision;
  final ValueChanged<String> onOpen;

  /// Gọi sau khi hủy đơn ngay trên danh sách.
  final VoidCallback onChanged;

  const OwnerBookingList({
    super.key,
    required this.facilityId,
    required this.revision,
    required this.onOpen,
    required this.onChanged,
  });

  @override
  State<OwnerBookingList> createState() => _OwnerBookingListState();
}

class _OwnerBookingListState extends State<OwnerBookingList> {
  static const int _pageSize = 15;

  late DateTime _from = _today().subtract(const Duration(days: 7));
  late DateTime _to = _today().add(const Duration(days: 7));
  String _status = '';
  String _search = '';
  int _page = 1;
  final _keyword = TextEditingController();

  OwnerBookingPage _data = OwnerBookingPage.empty;
  bool _loading = true;
  String? _error;
  int _seq = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OwnerBookingList old) {
    super.didUpdateWidget(old);
    if (old.facilityId != widget.facilityId || old.revision != widget.revision) _load();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AppRepositories.owner.getBookings(
        facilityId: widget.facilityId,
        from: _from,
        to: _to,
        status: _status,
        search: _search,
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted && seq == _seq) {
        setState(() {
          _data = data;
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

  void _reset(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _reset(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked.isBefore(_from) ? _from : picked;
      }
    });
  }

  Future<void> _cancel(OwnerBooking b) async {
    if (await showOwnerCancelDialog(context, OwnerCancelTarget.fromBooking(b))) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat(OwnerStrings.statCount, '${d.total}'),
              _stat(OwnerStrings.statActiveRevenue, Formatters.vnd(d.revenue)),
              _stat(OwnerStrings.statPaid, '${d.paidCount}'),
              _stat(OwnerStrings.statChecked, '${d.checkedInCount}'),
              _stat(OwnerStrings.statCancelled, '${d.cancelledCount}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(OwnerStrings.dateFrom, style: TextStyle(color: AppColors.textSecondary)),
              _dateButton(_from, () => _pickDate(from: true)),
              const Text(OwnerStrings.dateTo, style: TextStyle(color: AppColors.textSecondary)),
              _dateButton(_to, () => _pickDate(from: false)),
              DropdownButton<String>(
                value: _status,
                underline: const SizedBox.shrink(),
                items: [
                  for (final e in OwnerStrings.statusFilters.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => _reset(() => _status = v ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyword,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _reset(() => _search = _keyword.text.trim()),
                  decoration: InputDecoration(
                    hintText: OwnerStrings.searchHint,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _reset(() => _search = _keyword.text.trim()),
                child: const Text(OwnerStrings.search),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading && d.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(OwnerStrings.listLoading, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            )
          else if (d.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 40, color: AppColors.cardBorder),
                  SizedBox(height: 8),
                  Text(OwnerStrings.listEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            for (final b in d.items) _row(b),
          if (d.totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _page <= 1 ? null : () => _goTo(_page - 1),
                    child: const Text(OwnerStrings.prevPage),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(OwnerStrings.pageOf(_page, d.totalPages), style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                  OutlinedButton(
                    onPressed: _page >= d.totalPages ? null : () => _goTo(_page + 1),
                    child: const Text(OwnerStrings.nextPage),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(OwnerBooking b) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.customerName ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      Text(
                        '${b.customerPhone ?? ''}${b.isWalkIn ? OwnerStrings.walkInTag : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      BookingStatusBadge(b.status),
                      if (b.isNoShow) const OwnerBadge(OwnerStrings.noShowBadge, tone: BadgeTone.red),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${b.courtName}${b.sportName.isEmpty ? '' : ' • ${b.sportName}'}',
              style: const TextStyle(color: AppColors.textMain),
            ),
            Text(
              '${Formatters.dateTime(b.start)} ${OwnerStrings.until(Formatters.time(b.end))}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    OwnerStrings.listCheckedIn(b.checkedInCount, b.participantCount),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                Text(Formatters.vnd(b.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(onPressed: () => widget.onOpen(b.id), child: const Text(OwnerStrings.detail)),
                if (b.canCancel)
                  OutlinedButton(
                    onPressed: () => _cancel(b),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text(OwnerStrings.cancelBooking),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _stat(String label, String value) => Container(
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
          ],
        ),
      );

  Widget _dateButton(DateTime d, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_today, size: 16),
        label: Text(Formatters.date(d)),
      );
}
