import 'package:flutter/material.dart';
import '../../core/constants/fair_play_rules.dart';
import '../../core/strings/review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/rating_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/review.dart';
import '../../models/sport_rating.dart';
import '../../theme/app_colors.dart';
import '../../widgets/review/star_rating.dart';
import '../../core/strings/report_strings.dart';
import '../report/support_center_screen.dart';

/// Chấm từng người chơi cùng trận, kèm đánh giá sân nếu BE cho phép (đã check-in, chưa đánh giá sân này).
/// Pop về `true` khi gửi thành công.
class SubmitReviewScreen extends StatefulWidget {
  final PendingReview session;

  const SubmitReviewScreen({super.key, required this.session});

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _PlayerDraft {
  int stars = 0;

  /// Nhận xét trình độ (không bắt buộc).
  SkillVerdict? verdict;
  final Set<ReviewTag> tags = {};

  /// Bắt buộc khi chấm thấp ([FairPlayRules.requiresReason]).
  LowRatingReason? reason;
  final TextEditingController comment = TextEditingController();

  bool get needsReason => FairPlayRules.requiresReason(stars);

  /// Chưa chấm, hoặc đã chấm đủ: chấm thấp phải có lý do, lý do "Khác" phải có mô tả.
  bool get isComplete =>
      !needsReason || (reason != null && (!reason!.isOther || comment.text.trim().isNotEmpty));
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  int _facilityStars = 0;
  final TextEditingController _facilityComment = TextEditingController();
  late final Map<String, _PlayerDraft> _players = {
    for (final p in widget.session.players) p.userId: _PlayerDraft(),
  };
  bool _isSubmitting = false;

  /// `null` khi đang tải hoặc không tải được (khi đó ẩn phần đánh giá sân).
  ReviewEligibility? _eligibility;

  PendingReview get _session => widget.session;

  bool get _canReviewFacility => _eligibility?.canReview ?? false;

  bool get _hasAnyRating =>
      (_canReviewFacility && _facilityStars > 0) || _players.values.any((d) => d.stars > 0 || d.verdict != null);

  bool get _canSubmit => _hasAnyRating && _players.values.every((d) => d.isComplete);

  /// `null` khi đang tải; [_reasonsFailed] khi tải lỗi.
  List<LowRatingReason>? _reasons;
  bool _reasonsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
    _loadReasons();
  }

  Future<void> _loadReasons() async {
    if (_reasonsFailed) setState(() => _reasonsFailed = false);
    try {
      final reasons = await AppRepositories.review.getLowRatingReasons();
      if (mounted) setState(() => _reasons = reasons);
    } catch (_) {
      if (mounted) setState(() => _reasonsFailed = true);
    }
  }

  void _setStars(_PlayerDraft draft, int stars) {
    setState(() {
      draft.stars = stars;
      // Chấm thấp chỉ chọn lý do; chấm từ mức trung bình trở lên chỉ có thẻ tốt.
      if (draft.needsReason) {
        draft.tags.clear();
      } else {
        draft.reason = null;
      }
    });
  }

  Future<void> _loadEligibility() async {
    try {
      final eligibility = await AppRepositories.review.getEligibility(_session.facilityId);
      if (mounted) setState(() => _eligibility = eligibility);
    } catch (_) {
      // Không chặn việc chấm người chơi.
    }
  }

  @override
  void dispose() {
    _facilityComment.dispose();
    for (final d in _players.values) {
      d.comment.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final skipped = _players.values.where((d) => d.stars == 0).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ReviewStrings.confirmTitle),
        content: Text(
          skipped > 0 && _session.players.isNotEmpty
              ? '${ReviewStrings.confirmMessage}\n${ReviewStrings.confirmSkipped(skipped)}'
              : ReviewStrings.confirmMessage,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(ReviewStrings.back)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text(ReviewStrings.send),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      if (_canReviewFacility && _facilityStars > 0) {
        final review = await AppRepositories.review.submitFacilityReview(
          _session.facilityId,
          FacilityReviewInput(stars: _facilityStars, comment: _facilityComment.text.trim()),
        );
        // Gửi người chơi lỗi thì lần bấm sau không gửi lại đánh giá sân.
        if (mounted) setState(() => _eligibility = ReviewEligibility(canReview: false, existingReviewId: review.id));
      }
      final players = [
        for (final entry in _players.entries)
          if (entry.value.stars > 0)
            PlayerReviewInput(
              playerId: entry.key,
              stars: entry.value.stars,
              tags: entry.value.tags,
              comment: entry.value.comment.text.trim(),
              reasonId: entry.value.needsReason ? entry.value.reason?.id : null,
            ),
      ];
      if (players.isNotEmpty) await AppRepositories.review.ratePlayers(_session.sessionId, players);
      final feedbackError = await _sendSkillFeedback();
      if (!mounted) return;
      if (feedbackError != null) {
        // Chấm Fair Play đã xong: báo lỗi nhận xét trình độ (vd. Fair Play dưới 50) nhưng vẫn đóng màn.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(feedbackError)));
      }
      Navigator.pop(context, true);
    } on ReviewException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  /// Gửi nhận xét trình độ; trả câu lỗi đầu tiên (nếu có), không chặn việc gửi đánh giá.
  Future<String?> _sendSkillFeedback() async {
    String? error;
    for (final entry in _players.entries) {
      final verdict = entry.value.verdict;
      if (verdict == null) continue;
      try {
        await AppRepositories.rating.sendSkillFeedback(
          revieweeId: entry.key,
          contextId: _session.sessionId,
          verdict: verdict,
        );
      } on RatingException catch (e) {
        error ??= e.message;
        // Fair Play thấp / quá hạn: những người sau cũng sẽ bị từ chối như vậy.
        break;
      }
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          ReviewStrings.reviewTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSessionHeader(),
          if (_canReviewFacility || (_eligibility?.alreadyReviewed ?? false)) ...[
            const SizedBox(height: 16),
            _sectionTitle(ReviewStrings.facilitySection),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_session.facilityName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_canReviewFacility) ...[
                    StarRating(value: _facilityStars, onChanged: (v) => setState(() => _facilityStars = v)),
                    const SizedBox(height: 8),
                    _commentField(_facilityComment, maxLength: 1000),
                    const Text(
                      ReviewStrings.facilityPublicNote,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ] else
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen),
                        SizedBox(width: 6),
                        Text(ReviewStrings.facilityAlreadyReviewed, style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                ],
              ),
            ),
          ],
          if (_session.players.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle(ReviewStrings.playersSection),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                ReviewStrings.anonymousNote,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            ..._session.players.map(_buildPlayerCard),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _canSubmit && !_isSubmitting ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.authPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                  : const Text(ReviewStrings.submit, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionHeader() {
    return _card(
      child: Row(
        children: [
          const Icon(Icons.event_available, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_session.type == SessionType.lfg ? ReviewStrings.lfgMatch : ReviewStrings.booking} • ${_session.sportLabel}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                Text(
                  Formatters.slotLabel(_session.start, _session.end),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(ReviewablePlayer player) {
    final draft = _players[player.userId]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryGreen,
                  backgroundImage: player.avatarUrl == null ? null : NetworkImage(player.avatarUrl!),
                  child: player.avatarUrl != null
                      ? null
                      : Text(
                          player.name.isEmpty ? '?' : player.name.characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (player.isHost)
                        const Text(ReviewStrings.host, style: TextStyle(fontSize: 11, color: AppColors.primaryGreen)),
                    ],
                  ),
                ),
                if (draft.stars == 0) ...[
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      ReviewStrings.skipped,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                // Báo cáo người chơi đặt cạnh từng người như màn đánh giá sau trận của Web.
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportPlayerScreen(userId: player.userId, name: player.name)),
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text(ReportStrings.reportPlayer),
                  style: TextButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StarRating(
              value: draft.stars,
              size: 28,
              onChanged: (v) => _setStars(draft, v),
            ),
            // Chấm 1–2 sao: phần lý do trượt mở ngay dưới hàng sao (trượt đóng khi chấm lại cao hơn).
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: draft.needsReason ? _buildLowRatingSection(draft) : const SizedBox(width: double.infinity),
            ),
            if (!draft.needsReason && draft.stars > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ReviewTag.values.where((t) => t.isPositive).map((tag) {
                  final selected = draft.tags.contains(tag);
                  final color = tag.isPositive ? AppColors.primaryGreen : Colors.red;
                  return FilterChip(
                    label: Text(tag.label),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (on) => setState(() => on ? draft.tags.add(tag) : draft.tags.remove(tag)),
                    selectedColor: color.withValues(alpha: 0.12),
                    backgroundColor: AppColors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : AppColors.textSecondary,
                    ),
                    side: BorderSide(color: selected ? color : AppColors.cardBorder),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              _commentField(draft.comment),
            ],
            const SizedBox(height: 10),
            const Text(ReviewStrings.skillVerdictTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in SkillVerdict.values)
                  ChoiceChip(
                    label: Text(v.label, style: const TextStyle(fontSize: 12)),
                    selected: draft.verdict == v,
                    // Bấm lại lựa chọn đang chọn thì bỏ chọn (không bắt buộc).
                    onSelected: (_) => setState(() => draft.verdict = draft.verdict == v ? null : v),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Lý do (bắt buộc) + nhận xét; "Khác" phải có mô tả.
  Widget _buildLowRatingSection(_PlayerDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildReasons(draft),
        const SizedBox(height: 8),
        _commentField(
          draft.comment,
          hint: draft.reason?.isOther ?? false ? ReviewStrings.otherReasonHint : ReviewStrings.commentHint,
          onChanged: (_) => setState(() {}),
        ),
        if (!draft.isComplete)
          Text(
            draft.reason == null ? ReviewStrings.lowRatingReasonRequired : ReviewStrings.otherReasonRequired,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
      ],
    );
  }

  /// Chọn đúng một lý do chấm thấp (radio, danh sách do BE quản lý).
  Widget _buildReasons(_PlayerDraft draft) {
    final reasons = _reasons;
    if (reasons == null) {
      if (!_reasonsFailed) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
        );
      }
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(ReviewStrings.reasonsLoadError, style: TextStyle(fontSize: 12, color: Colors.red)),
          TextButton(onPressed: _loadReasons, child: const Text(ReviewStrings.retry)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(ReviewStrings.lowRatingReasonTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        RadioGroup<int>(
          groupValue: draft.reason?.id,
          onChanged: (id) => setState(() => draft.reason = reasons.where((r) => r.id == id).firstOrNull),
          // Thẻ người chơi có nền riêng: cần Material để hiệu ứng bấm của radio hiện được.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final r in reasons)
                  RadioListTile<int>(
                    value: r.id,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryGreen,
                    title: Text(r.name, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );

  Widget _commentField(
    TextEditingController controller, {
    int maxLength = 400,
    String hint = ReviewStrings.commentHint,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        maxLines: 2,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      );
}
