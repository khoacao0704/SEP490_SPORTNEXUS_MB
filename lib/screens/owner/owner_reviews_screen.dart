import 'package:flutter/material.dart';

import '../../core/strings/owner_review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart' show ownerErrorMessage;
import '../../widgets/owner/slot_pickers.dart' show confirmOwner, showOwnerSnack;
import '../../widgets/owner/stat_grid.dart';

/// Đánh giá của khách (như Web: OwnerReviews.jsx): thống kê, phân bố sao, lọc theo cơ sở / số sao / phản hồi,
/// gửi - sửa - xóa phản hồi, phân trang. Mobile giữ thêm nút báo cáo đánh giá vi phạm.
class OwnerReviewsScreen extends StatefulWidget {
  const OwnerReviewsScreen({super.key});

  @override
  State<OwnerReviewsScreen> createState() => _OwnerReviewsScreenState();
}

class _OwnerReviewsScreenState extends State<OwnerReviewsScreen> {
  static const int _pageSize = 10;

  List<Facility> _facilities = [];
  String? _facilityId;
  int? _rating;
  bool? _replied;
  int _page = 1;

  ReviewStats? _stats;
  String? _statsError;
  ReviewPage _list = ReviewPage.empty;
  String? _listError;
  bool _loading = true;

  /// Chỉ nhận kết quả của lần tải mới nhất (đổi bộ lọc liên tục).
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
    _load();
  }

  Future<void> _loadFacilities() async {
    try {
      final list = await AppRepositories.owner.getMyFacilities();
      if (mounted) setState(() => _facilities = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final repo = AppRepositories.owner;
    ReviewStats? stats;
    String? statsError;
    ReviewPage list = ReviewPage.empty;
    String? listError;
    await Future.wait([
      repo.getReviewStats(facilityId: _facilityId).then<void>((v) => stats = v, onError: (Object e) => statsError = ownerErrorMessage(e)),
      repo
          .getFacilityReviews(facilityId: _facilityId, rating: _rating, replied: _replied, page: _page, pageSize: _pageSize)
          .then<void>((v) => list = v, onError: (Object e) => listError = ownerErrorMessage(e)),
    ]);
    if (!mounted || seq != _seq) return;
    setState(() {
      _stats = stats;
      _statsError = statsError;
      _list = list;
      _listError = listError;
      _loading = false;
    });
  }

  void _setFilter(VoidCallback change) {
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

  @override
  Widget build(BuildContext context) {
    final items = _list.items;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerReviewStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(OwnerReviewStrings.subtitle, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (_statsError != null) _ErrorBox(_statsError!),
            _StatsGrid(stats: _stats),
            const SizedBox(height: 12),
            _DistributionCard(stats: _stats),
            const SizedBox(height: 16),
            _filters(),
            const SizedBox(height: 12),
            if (_listError != null) _ErrorBox(_listError!),
            if (_loading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(OwnerReviewStrings.loading, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              )
            else if (items.isEmpty)
              const _Empty()
            else
              for (final r in items)
                _ReviewItem(key: ValueKey('${r.id}|${r.ownerReply ?? ''}|${r.report?.status}'), review: r, onChanged: _load),
            if (_list.totalPages > 1) _pager(),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );
    final facility = DropdownButtonFormField<String?>(
      key: ValueKey('f-$_facilityId-${_facilities.length}'),
      initialValue: _facilityId,
      isExpanded: true,
      decoration: deco(OwnerReviewStrings.filterFacility),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text(OwnerReviewStrings.allFacilities)),
        for (final f in _facilities)
          DropdownMenuItem<String?>(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => _setFilter(() => _facilityId = v),
    );
    final rating = DropdownButtonFormField<int?>(
      initialValue: _rating,
      isExpanded: true,
      decoration: deco(OwnerReviewStrings.filterRating),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text(OwnerReviewStrings.allRatings, overflow: TextOverflow.ellipsis)),
        for (final n in [5, 4, 3, 2, 1]) DropdownMenuItem<int?>(value: n, child: Text(OwnerReviewStrings.stars(n))),
      ],
      onChanged: (v) => _setFilter(() => _rating = v),
    );
    final replied = DropdownButtonFormField<bool?>(
      initialValue: _replied,
      isExpanded: true,
      decoration: deco(OwnerReviewStrings.filterReplied),
      items: const [
        DropdownMenuItem<bool?>(value: null, child: Text(OwnerReviewStrings.allReplied, overflow: TextOverflow.ellipsis)),
        DropdownMenuItem<bool?>(value: false, child: Text(OwnerReviewStrings.unreplied, overflow: TextOverflow.ellipsis)),
        DropdownMenuItem<bool?>(value: true, child: Text(OwnerReviewStrings.replied, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => _setFilter(() => _replied = v),
    );
    return Column(
      children: [
        facility,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: rating),
            const SizedBox(width: 10),
            Expanded(child: replied),
          ],
        ),
      ],
    );
  }

  Widget _pager() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton(onPressed: _page <= 1 ? null : () => _goPage(_page - 1), child: const Text(OwnerReviewStrings.prev)),
            Text(OwnerReviewStrings.pageOf(_page, _list.totalPages), style: const TextStyle(color: AppColors.textSecondary)),
            OutlinedButton(
              onPressed: _page >= _list.totalPages ? null : () => _goPage(_page + 1),
              child: const Text(OwnerReviewStrings.next),
            ),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: BadgeTone.red.background, borderRadius: BorderRadius.circular(10)),
        child: Text(message, style: TextStyle(color: BadgeTone.red.foreground)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 40, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text(OwnerReviewStrings.empty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _Stars extends StatelessWidget {
  final int value;

  const _Stars(this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 16,
              color: i <= value ? const Color(0xFFF59E0B) : const Color(0xFFD6DCDA),
            ),
        ],
      );
}

class _StatsGrid extends StatelessWidget {
  final ReviewStats? stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    const dash = OwnerReviewStrings.dash;
    return StatGrid(
      children: [
        _tile(OwnerReviewStrings.statAverage, s?.averageRating == null ? dash : '${s!.averageRating!.toStringAsFixed(1)} / 5'),
        _tile(OwnerReviewStrings.statTotal, s == null ? dash : '${s.totalReviews}'),
        _tile(OwnerReviewStrings.statUnreplied, s == null ? dash : '${s.unrepliedCount}'),
        _tile(OwnerReviewStrings.statReplyRate, s?.replyPercent == null ? dash : '${s!.replyPercent}%'),
        _tile(OwnerReviewStrings.statNew30, s == null ? dash : '${s.newLast30Days}'),
      ],
    );
  }

  Widget _tile(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

class _DistributionCard extends StatelessWidget {
  final ReviewStats? stats;

  const _DistributionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats?.totalReviews ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            OwnerReviewStrings.distributionTitle,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 10),
          for (final star in [5, 4, 3, 2, 1])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text('$star ★', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (stats!.countOf(star) / total),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEEF2F1),
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${stats?.countOf(star) ?? 0}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Một đánh giá + phản hồi (như ReviewItem của Web) + báo cáo (mobile).
class _ReviewItem extends StatefulWidget {
  final FacilityReview review;
  final VoidCallback onChanged;

  const _ReviewItem({super.key, required this.review, required this.onChanged});

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  late final TextEditingController _text = TextEditingController(text: widget.review.ownerReply ?? '');
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final r = widget.review;
    if (_text.text.trim().isEmpty) {
      showOwnerSnack(context, OwnerReviewStrings.replyEmpty, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppRepositories.owner.replyToReview(r.id, _text.text, edit: r.hasReply);
      if (!mounted) return;
      showOwnerSnack(context, r.hasReply ? OwnerReviewStrings.replyEdited : OwnerReviewStrings.replySent);
      setState(() => _editing = false);
      widget.onChanged();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (!await confirmOwner(context, OwnerReviewStrings.deleteConfirm)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await AppRepositories.owner.deleteReviewReply(widget.review.id);
      if (!mounted) return;
      showOwnerSnack(context, OwnerReviewStrings.replyDeleted);
      _text.clear();
      widget.onChanged();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final updated = await showModalBottomSheet<FacilityReview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportSheet(review: widget.review),
    );
    if (updated != null && mounted) {
      showOwnerSnack(context, OwnerReviewStrings.reportSent);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final name = r.userName.isEmpty ? OwnerReviewStrings.guest : r.userName;
    final avatar = r.userAvatarUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.lightGreen,
            foregroundImage: avatar == null ? null : NetworkImage(avatar),
            child: Text(name.characters.first, style: const TextStyle(color: AppColors.darkGreen, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    _Stars(r.rating),
                    if (r.isHidden) const OwnerBadge(OwnerReviewStrings.hidden, tone: BadgeTone.gray),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.facilityName} • ${Formatters.dateTime(r.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (r.isHidden && r.hiddenReason != null)
                  Text(r.hiddenReason!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                r.comment.isEmpty
                    ? const Text(
                        OwnerReviewStrings.noComment,
                        style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      )
                    : Text(r.comment, style: const TextStyle(color: AppColors.textMain)),
                if (r.hasReply && !_editing) _replyBox(r),
                if (!r.hasReply || _editing) _replyForm(r),
                _reportLine(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyBox(FacilityReview r) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
        decoration: BoxDecoration(color: const Color(0xFFF1F7F3), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text(OwnerReviewStrings.yourReply, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (r.repliedAt != null)
                  Text(Formatters.dateTime(r.repliedAt!), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _text.text = r.ownerReply ?? '';
                            _editing = true;
                          }),
                  child: const Text(OwnerReviewStrings.edit),
                ),
                TextButton(onPressed: _busy ? null : _remove, child: const Text(OwnerReviewStrings.delete)),
              ],
            ),
            Text(r.ownerReply ?? '', style: const TextStyle(color: AppColors.textMain)),
          ],
        ),
      );

  Widget _replyForm(FacilityReview r) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 5,
              maxLength: OwnerReviewStrings.replyMaxLength,
              decoration: InputDecoration(
                hintText: OwnerReviewStrings.replyHint,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (_editing)
                  TextButton(onPressed: () => setState(() => _editing = false), child: const Text(OwnerReviewStrings.cancel)),
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                  child: Text(r.hasReply ? OwnerReviewStrings.saveReply : OwnerReviewStrings.sendReply),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _reportLine(FacilityReview r) {
    final report = r.report;
    if (report == null) {
      if (!r.canReport) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy ? null : _report,
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, padding: EdgeInsets.zero),
          icon: const Icon(Icons.flag_outlined, size: 16),
          label: const Text(OwnerReviewStrings.report),
        ),
      );
    }
    final text = switch (report.status) {
      ReportStatus.pending => OwnerReviewStrings.reportPending,
      ReportStatus.kept => OwnerReviewStrings.reportKept,
      ReportStatus.hidden => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final FacilityReview review;

  const _ReportSheet({required this.review});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _note = TextEditingController();
  ReportReason _reason = ReportReason.offensive;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await AppRepositories.owner.reportReview(widget.review.id, _reason, note: _note.text);
      if (mounted) Navigator.pop(context, updated);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                OwnerReviewStrings.reportTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 4),
              const Text(OwnerReviewStrings.reportHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v ?? _reason),
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: r,
                        title: Text(r.label),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primaryGreen,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: OwnerReviewStrings.reportNote,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(OwnerReviewStrings.sendReport, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
