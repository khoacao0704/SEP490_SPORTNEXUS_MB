import 'package:flutter/material.dart';

import '../../core/strings/owner_review_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';

enum _Filter { all, unreplied, low }

/// Đánh giá ẩn danh của người chơi: điểm trung bình, phân bố sao, trả lời công khai, báo cáo vi phạm.
class OwnerReviewsScreen extends StatefulWidget {
  const OwnerReviewsScreen({super.key});

  @override
  State<OwnerReviewsScreen> createState() => _OwnerReviewsScreenState();
}

class _OwnerReviewsScreenState extends State<OwnerReviewsScreen> {
  List<Facility> _facilities = [];
  List<FacilityReview> _reviews = [];
  String? _facilityId;
  _Filter _filter = _Filter.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final facilities = await AppRepositories.owner.getMyFacilities();
      final reviews = await AppRepositories.owner.getFacilityReviews(facilityId: _facilityId);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _facilities = facilities;
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _error = OwnerReviewStrings.loadError;
      });
    }
  }

  void _replace(FacilityReview updated) =>
      setState(() => _reviews = [for (final r in _reviews) r.id == updated.id ? updated : r]);

  List<FacilityReview> get _filtered => switch (_filter) {
    _Filter.all => _reviews,
    _Filter.unreplied => _reviews.where((r) => r.reply == null && !r.isHidden).toList(),
    _Filter.low => _reviews.where((r) => r.stars <= 2).toList(),
  };

  Future<void> _reply(FacilityReview r) async {
    final updated = await showModalBottomSheet<FacilityReview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReplySheet(review: r),
    );
    if (updated != null && mounted) {
      _replace(updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerReviewStrings.replySaved)));
    }
  }

  Future<void> _report(FacilityReview r) async {
    final updated = await showModalBottomSheet<FacilityReview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportSheet(review: r),
    );
    if (updated != null && mounted) {
      _replace(updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerReviewStrings.reportSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ReviewSummary(_reviews);
    final items = _filtered;
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
            if (_facilities.length > 1)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip(OwnerStrings.allFacilities, _facilityId == null, () {
                    setState(() => _facilityId = null);
                    _load();
                  }),
                  for (final f in _facilities)
                    _chip(f.name, _facilityId == f.id, () {
                      setState(() => _facilityId = f.id);
                      _load();
                    }),
                ],
              ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary))
            else if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Text(
                  OwnerReviewStrings.empty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else ...[
              _SummaryCard(summary: summary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _chip(
                    OwnerReviewStrings.filterAll,
                    _filter == _Filter.all,
                    () => setState(() => _filter = _Filter.all),
                  ),
                  _chip(
                    summary.unreplied > 0
                        ? '${OwnerReviewStrings.filterUnreplied} (${summary.unreplied})'
                        : OwnerReviewStrings.filterUnreplied,
                    _filter == _Filter.unreplied,
                    () => setState(() => _filter = _Filter.unreplied),
                  ),
                  _chip(
                    OwnerReviewStrings.filterLow,
                    _filter == _Filter.low,
                    () => setState(() => _filter = _Filter.low),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    OwnerReviewStrings.emptyFilter,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                for (final r in items)
                  _ReviewCard(
                    review: r,
                    showFacility: _facilityId == null,
                    onReply: () => _reply(r),
                    onReport: () => _report(r),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    selectedColor: AppColors.lightGreen,
    labelStyle: TextStyle(color: selected ? AppColors.darkGreen : AppColors.textMain, fontWeight: FontWeight.w600),
    onSelected: (_) => onTap(),
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
          color: i <= value ? Colors.amber : AppColors.cardBorder,
        ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  final ReviewSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dist = summary.distribution;
    final maxCount = dist.fold(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              _Stars(summary.average.round()),
              const SizedBox(height: 4),
              Text(
                OwnerReviewStrings.reviewCount(summary.count),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (summary.unreplied > 0)
                Text(
                  OwnerReviewStrings.unreplied(summary.unreplied),
                  style: const TextStyle(fontSize: 12, color: AppColors.tagOrangeText),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 14, child: Text('$star', style: const TextStyle(fontSize: 12))),
                        const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxCount == 0 ? 0 : dist[star - 1] / maxCount,
                              minHeight: 6,
                              backgroundColor: AppColors.divider,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${dist[star - 1]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final FacilityReview review;
  final bool showFacility;
  final VoidCallback onReply;
  final VoidCallback onReport;

  const _ReviewCard({required this.review, required this.showFacility, required this.onReply, required this.onReport});

  @override
  Widget build(BuildContext context) {
    final r = review;
    final report = r.report;
    return Opacity(
      opacity: r.isHidden ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.divider,
                  child: Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        OwnerReviewStrings.anonymous,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        Formatters.timeAgo(r.createdAt, DateTime.now()),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _Stars(r.stars),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(sportIcon(r.sport), size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    showFacility ? '${r.sport.label} • ${r.facilityName}' : r.sport.label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.comment, style: const TextStyle(color: AppColors.textMain, height: 1.4)),
            ],
            if (r.reply != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      OwnerReviewStrings.yourReply,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                    ),
                    const SizedBox(height: 2),
                    Text(r.reply!.text, style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
                  ],
                ),
              ),
            if (report != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 14,
                      color: report.status == ReportStatus.hidden ? Colors.red.shade700 : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        switch (report.status) {
                          ReportStatus.pending => OwnerReviewStrings.reportPending,
                          ReportStatus.kept => OwnerReviewStrings.reportKept,
                          ReportStatus.hidden => OwnerReviewStrings.reportHidden,
                        },
                        style: TextStyle(
                          fontSize: 12,
                          color: report.status == ReportStatus.hidden ? Colors.red.shade700 : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (r.canReport)
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text(OwnerReviewStrings.report),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  ),
                if (r.canReply)
                  TextButton.icon(
                    onPressed: onReply,
                    icon: Icon(r.reply == null ? Icons.reply : Icons.edit_outlined, size: 16),
                    label: Text(r.reply == null ? OwnerReviewStrings.reply : OwnerReviewStrings.editReply),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final FacilityReview review;

  const _ReplySheet({required this.review});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final _controller = TextEditingController(text: widget.review.reply?.text);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await AppRepositories.owner.replyToReview(widget.review.id, _controller.text);
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                OwnerReviewStrings.replyTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 4),
              const Text(OwnerReviewStrings.replyHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (widget.review.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('"${widget.review.comment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: OwnerReviewStrings.replyMaxLength,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: OwnerReviewStrings.replyPlaceholder,
                  errorText: _error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(OwnerReviewStrings.send, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
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
        child: Padding(
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
