import 'package:flutter/material.dart';

import '../../core/strings/owner_review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/facility.dart';
import '../../models/owner_complaint.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart' show ownerErrorMessage;
import '../../widgets/owner/photo_picker.dart';
import '../../widgets/owner/slot_pickers.dart' show confirmOwner, showOwnerSnack;
import '../../widgets/owner/stat_grid.dart';

BadgeTone _tone(ComplaintStatus s) => switch (s) {
      ComplaintStatus.pending => BadgeTone.amber,
      ComplaintStatus.ownerResponded => BadgeTone.blue,
      ComplaintStatus.resolvedRefunded => BadgeTone.green,
      _ => BadgeTone.gray,
    };

String _dt(DateTime? d) => d == null ? '—' : Formatters.dateTime(d);
String _money(int? v) => v == null ? '—' : Formatters.vnd(v);

/// Khiếu nại của khách (như Web: OwnerReports.jsx): tab trạng thái có số đếm, lọc cơ sở, tìm kiếm, phân trang.
class OwnerComplaintsScreen extends StatefulWidget {
  const OwnerComplaintsScreen({super.key});

  @override
  State<OwnerComplaintsScreen> createState() => _OwnerComplaintsScreenState();
}

class _OwnerComplaintsScreenState extends State<OwnerComplaintsScreen> {
  static const int _pageSize = 10;

  final _keyword = TextEditingController();
  List<Facility> _facilities = [];
  ComplaintTab _tab = ComplaintTab.all;
  String? _facilityId;
  String _search = '';
  int _page = 1;

  ComplaintPage _data = ComplaintPage.empty;
  bool _loading = true;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    AppRepositories.owner.getMyFacilities().then((v) {
      if (mounted) setState(() => _facilities = v);
    }, onError: (_) {});
    _load();
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
      final data = await AppRepositories.owner.getComplaints(
        status: _tab.status,
        facilityId: _facilityId,
        keyword: _search,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = ownerErrorMessage(e);
      });
    }
  }

  void _reset(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  void _goPage(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _open(OwnerComplaint c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerComplaintDetailScreen(complaintId: c.id)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _data.items;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerComplaintStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(OwnerComplaintStrings.subtitle, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in ComplaintTab.values)
                  ChoiceChip(
                    label: Text(_tabLabel(t)),
                    selected: _tab == t,
                    selectedColor: AppColors.lightGreen,
                    labelStyle: TextStyle(
                      color: _tab == t ? AppColors.darkGreen : AppColors.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => _reset(() => _tab = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('f-$_facilityId-${_facilities.length}'),
              initialValue: _facilityId,
              isExpanded: true,
              decoration: _deco(OwnerReviewStrings.filterFacility),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text(OwnerReviewStrings.allFacilities)),
                for (final f in _facilities)
                  DropdownMenuItem<String?>(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => _reset(() => _facilityId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyword,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reset(() => _search = _keyword.text.trim()),
                    decoration: _deco(null).copyWith(hintText: OwnerComplaintStrings.searchHint, prefixIcon: const Icon(Icons.search)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _reset(() => _search = _keyword.text.trim()),
                  child: const Text(OwnerComplaintStrings.search),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: BadgeTone.red.background, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: TextStyle(color: BadgeTone.red.foreground)),
              ),
            if (_loading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(OwnerComplaintStrings.loading, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.verified_outlined, size: 40, color: AppColors.textSecondary),
                    SizedBox(height: 8),
                    Text(OwnerComplaintStrings.empty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            else
              for (final c in items) _ComplaintCard(complaint: c, onOpen: () => _open(c)),
            if (_data.totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _page <= 1 ? null : () => _goPage(_page - 1),
                      child: const Text(OwnerReviewStrings.prev),
                    ),
                    Text(OwnerReviewStrings.pageOf(_page, _data.totalPages), style: const TextStyle(color: AppColors.textSecondary)),
                    OutlinedButton(
                      onPressed: _page >= _data.totalPages ? null : () => _goPage(_page + 1),
                      child: const Text(OwnerReviewStrings.next),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(ComplaintTab t) {
    final n = _data.counts.of(t);
    return n != null && n > 0 ? '${t.label} ($n)' : t.label;
  }
}

InputDecoration _deco(String? label) => InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

class _ComplaintCard extends StatelessWidget {
  final OwnerComplaint complaint;
  final VoidCallback onOpen;

  const _ComplaintCard({required this.complaint, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    const muted = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(c.reporterName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
              OwnerBadge(c.status.label, tone: _tone(c.status)),
            ],
          ),
          Text(_dt(c.createdAt), style: muted),
          const SizedBox(height: 8),
          Text(c.courtName.isEmpty ? c.facilityName : '${c.facilityName} • ${c.courtName}'),
          const SizedBox(height: 2),
          Text(c.reason, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${_dt(c.bookingStartTime)} • ${_money(c.bookingTotalAmount)}', style: muted),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onOpen,
              child: Text(c.status == ComplaintStatus.pending ? OwnerComplaintStrings.handle : OwnerComplaintStrings.view),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chi tiết + xử lý khiếu nại (ReportDetailModal của Web). Pop `true` khi đã gửi giải trình / hoàn tiền.
class OwnerComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const OwnerComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<OwnerComplaintDetailScreen> createState() => _OwnerComplaintDetailScreenState();
}

enum _Mode { respond, refund }

class _OwnerComplaintDetailScreenState extends State<OwnerComplaintDetailScreen> {
  OwnerComplaint? _c;
  String? _error;

  _Mode _mode = _Mode.respond;
  final _response = TextEditingController();
  final _percent = TextEditingController(text: '100');
  final List<String> _evidence = [];
  bool _lockSlot = false;
  bool _uploading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _response.dispose();
    _percent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await AppRepositories.owner.getComplaint(widget.complaintId);
      if (mounted) setState(() => _c = c);
    } catch (e) {
      if (mounted) setState(() => _error = ownerErrorMessage(e));
    }
  }

  Future<void> _addImages() async {
    final room = OwnerComplaintStrings.maxEvidence - _evidence.length;
    if (room <= 0) return;
    final paths = (await pickPhotoPaths(context)).take(room).toList();
    if (paths.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final urls = await Future.wait(paths.map(AppRepositories.owner.uploadEvidence));
      if (mounted) setState(() => _evidence.addAll(urls));
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final text = _response.text.trim();
    if (text.isEmpty) {
      showOwnerSnack(context, OwnerComplaintStrings.responseEmpty, error: true);
      return;
    }
    final refund = _mode == _Mode.refund;
    final pct = int.tryParse(_percent.text.trim());
    if (refund) {
      if (pct == null || pct < 1 || pct > 100) {
        showOwnerSnack(context, OwnerComplaintStrings.percentError, error: true);
        return;
      }
      if (!await confirmOwner(context, OwnerComplaintStrings.refundConfirm(pct))) return;
      if (!mounted) return;
    }
    setState(() => _busy = true);
    try {
      final repo = AppRepositories.owner;
      if (refund) {
        await repo.acceptComplaintRefund(widget.complaintId,
            response: text, refundPercent: pct!, evidenceUrls: List.of(_evidence), lockSlot: _lockSlot);
      } else {
        await repo.respondComplaint(widget.complaintId, response: text, evidenceUrls: List.of(_evidence));
      }
      if (!mounted) return;
      showOwnerSnack(context, refund ? OwnerComplaintStrings.refundDone : OwnerComplaintStrings.respondDone);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          OwnerComplaintStrings.detailTitle(c?.reporterName ?? '…'),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: c == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)),
            )
          : ListView(padding: const EdgeInsets.all(16), children: _content(c)),
    );
  }

  List<Widget> _content(OwnerComplaint c) {
    const muted = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return [
      Text(
        [c.facilityName, if (c.courtName.isNotEmpty) c.courtName, OwnerComplaintStrings.sentAt(_dt(c.createdAt))].join(' • '),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OwnerBadge(c.status.label, tone: _tone(c.status)),
          if (c.bookingStatus != null) ...[
            const Text(OwnerComplaintStrings.bookingStatus, style: muted),
            BookingStatusBadge(c.bookingStatus!),
          ],
        ],
      ),
      const SizedBox(height: 12),
      StatGrid(
        spacing: 10,
        children: [
          _info(OwnerComplaintStrings.reason, c.reason.isEmpty ? '—' : c.reason),
          _info(OwnerComplaintStrings.slot, _dt(c.bookingStartTime)),
          _info(OwnerComplaintStrings.amount, _money(c.bookingTotalAmount)),
          _info(
            OwnerComplaintStrings.requested,
            c.requestedRefundPercentage == null ? '—' : '${c.requestedRefundPercentage}%',
          ),
          _info(OwnerComplaintStrings.contact, c.contact ?? '—'),
        ],
      ),
      const SizedBox(height: 12),
      const Text(OwnerComplaintStrings.description, style: muted),
      const SizedBox(height: 4),
      Text(c.description.isEmpty ? '—' : c.description),
      _Images(urls: c.evidenceImageUrls),
      if (c.ownerResponse != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F7F3), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  const Text(OwnerComplaintStrings.yourResponse, style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_dt(c.ownerRespondedAt), style: muted),
                ],
              ),
              const SizedBox(height: 4),
              Text(c.ownerResponse!),
              _Images(urls: c.ownerEvidenceUrls),
            ],
          ),
        ),
      if (c.hasAdminResult)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BadgeTone.blue.background, borderRadius: BorderRadius.circular(10)),
          child: Text(
            OwnerComplaintStrings.adminResult(c.resolvedByAdminName ?? '', c.adminNote ?? OwnerComplaintStrings.adminHandled) +
                (c.refundedAmount != null && c.refundedAmount! > 0
                    ? OwnerComplaintStrings.refunded(Formatters.vnd(c.refundedAmount!), c.appliedRefundPercentage ?? 0)
                    : ''),
            style: TextStyle(color: BadgeTone.blue.foreground),
          ),
        ),
      if (c.status.canAct) ..._form(),
    ];
  }

  Widget _info(String label, String value) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
          ],
        ),
      );

  List<Widget> _form() {
    final refund = _mode == _Mode.refund;
    return [
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final m in _Mode.values)
            ChoiceChip(
              label: Text(m == _Mode.respond ? OwnerComplaintStrings.modeRespond : OwnerComplaintStrings.modeRefund),
              selected: _mode == m,
              selectedColor: AppColors.lightGreen,
              labelStyle: TextStyle(color: _mode == m ? AppColors.darkGreen : AppColors.textMain, fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => _mode = m),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _response,
        minLines: 3,
        maxLines: 6,
        maxLength: OwnerComplaintStrings.maxLength,
        decoration: _deco(refund ? OwnerComplaintStrings.fieldRefund : OwnerComplaintStrings.fieldRespond)
            .copyWith(alignLabelWithHint: true),
      ),
      if (refund) ...[
        const SizedBox(height: 4),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _percent,
            keyboardType: TextInputType.number,
            decoration: _deco(OwnerComplaintStrings.refundPercent),
          ),
        ),
        CheckboxListTile(
          value: _lockSlot,
          onChanged: (v) => setState(() => _lockSlot = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primaryGreen,
          title: const Text(OwnerComplaintStrings.lockSlot),
        ),
      ],
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _uploading || _evidence.length >= OwnerComplaintStrings.maxEvidence ? null : _addImages,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(_uploading ? OwnerComplaintStrings.uploading : OwnerComplaintStrings.addEvidence),
          ),
          Text(
            OwnerComplaintStrings.evidenceCount(_evidence.length, OwnerComplaintStrings.maxEvidence),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      if (_evidence.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in _evidence)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(url, width: 84, height: 84)),
                  TextButton(
                    onPressed: () => setState(() => _evidence.remove(url)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text(OwnerComplaintStrings.removeImage),
                  ),
                ],
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerComplaintStrings.close)),
          ElevatedButton(
            onPressed: _busy || _uploading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: refund ? Colors.red.shade600 : AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(refund ? OwnerComplaintStrings.submitRefund : OwnerComplaintStrings.submitRespond),
          ),
        ],
      ),
    ];
  }
}

class _Images extends StatelessWidget {
  final List<String> urls;

  const _Images({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final u in urls)
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(child: InteractiveViewer(child: OwnerImage(u, fit: BoxFit.contain))),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(u, width: 84, height: 84)),
            ),
        ],
      ),
    );
  }
}
