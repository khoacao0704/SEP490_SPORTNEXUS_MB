import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/review.dart';
import '../../theme/app_colors.dart';
import '../../widgets/review/star_rating.dart';

/// Đánh giá một buổi chơi: sân (mọi buổi) + từng người chơi cùng (chỉ trận LFG).
/// Pop về `true` khi gửi thành công.
class SubmitReviewScreen extends StatefulWidget {
  final PendingReview session;

  const SubmitReviewScreen({super.key, required this.session});

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _PlayerDraft {
  int stars = 0;
  final Set<ReviewTag> tags = {};
  final TextEditingController comment = TextEditingController();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  int _facilityStars = 0;
  final TextEditingController _facilityComment = TextEditingController();
  late final Map<String, _PlayerDraft> _players = {
    for (final p in widget.session.players) p.userId: _PlayerDraft(),
  };
  bool _isSubmitting = false;

  PendingReview get _session => widget.session;

  bool get _hasAnyRating => _facilityStars > 0 || _players.values.any((d) => d.stars > 0);

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
      await AppRepositories.review.submitReview(
        _session.sessionId,
        facility: _facilityStars == 0
            ? null
            : FacilityReviewInput(stars: _facilityStars, comment: _facilityComment.text.trim()),
        players: [
          for (final entry in _players.entries)
            if (entry.value.stars > 0)
              PlayerReviewInput(
                playerId: entry.key,
                stars: entry.value.stars,
                tags: entry.value.tags,
                comment: entry.value.comment.text.trim(),
              ),
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } on ReviewException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
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
          const SizedBox(height: 16),
          _sectionTitle(ReviewStrings.facilitySection),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_session.facilityName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StarRating(value: _facilityStars, onChanged: (v) => setState(() => _facilityStars = v)),
                const SizedBox(height: 8),
                _commentField(_facilityComment),
              ],
            ),
          ),
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
              onPressed: _hasAnyRating && !_isSubmitting ? _submit : null,
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
                  '${_session.type == SessionType.lfg ? ReviewStrings.lfgMatch : ReviewStrings.booking} • ${_session.sport.label}',
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
                  child: Text(
                    player.name.characters.first.toUpperCase(),
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
                if (draft.stars == 0)
                  const Text(ReviewStrings.skipped, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            StarRating(
              value: draft.stars,
              size: 28,
              onChanged: (v) => setState(() => draft.stars = v),
            ),
            if (draft.stars > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ReviewTag.values.map((tag) {
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
          ],
        ),
      ),
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

  Widget _commentField(TextEditingController controller) => TextField(
        controller: controller,
        maxLines: 2,
        maxLength: 300,
        decoration: InputDecoration(
          hintText: ReviewStrings.commentHint,
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      );
}
