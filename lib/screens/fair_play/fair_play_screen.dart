import 'package:flutter/material.dart';
import '../../core/constants/fair_play_rules.dart';
import '../../core/strings/review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/review.dart';
import '../../theme/app_colors.dart';

class FairPlayScreen extends StatefulWidget {
  const FairPlayScreen({super.key});

  @override
  State<FairPlayScreen> createState() => _FairPlayScreenState();
}

class _FairPlayScreenState extends State<FairPlayScreen> {
  FairPlaySummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final summary = await AppRepositories.review.getFairPlay();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      if (mounted) setState(() => _error = ReviewStrings.loadError);
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
          ReviewStrings.fairPlayTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text(ReviewStrings.retry)),
                ],
              ),
            )
          : _summary == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FairPlayScoreCard(summary: _summary!),
                      const SizedBox(height: 16),
                      _buildRules(),
                      const SizedBox(height: 16),
                      _buildHistory(_summary!.history),
                    ],
                  ),
                ),
    );
  }

  Widget _card({required String title, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _buildRules() {
    return _card(
      title: ReviewStrings.howItWorks,
      child: Column(
        children: [
          for (var i = 0; i < ReviewStrings.rules.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(ReviewStrings.rules[i], style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            ),
            if (i == ReviewStrings.reviewTableAfterRule) _buildReviewTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewTable() {
    return Container(
      margin: const EdgeInsets.only(left: 18, bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ReviewStrings.reviewTable.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(ReviewStrings.reviewTable[i].$1, style: const TextStyle(fontSize: 13))),
                  Text(
                    ReviewStrings.reviewTable[i].$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ReviewStrings.reviewTable[i].$2.startsWith('+')
                          ? AppColors.primaryGreen
                          : ReviewStrings.reviewTable[i].$2 == '0'
                              ? AppColors.textSecondary
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistory(List<FairPlayEvent> history) {
    return _card(
      title: ReviewStrings.history,
      child: history.isEmpty
          ? const Text(ReviewStrings.noHistory, style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: history.map((e) {
                final positive = e.delta >= 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        positive ? Icons.trending_up : Icons.trending_down,
                        color: positive ? AppColors.primaryGreen : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              '${Formatters.dayMonth(e.createdAt)}/${e.createdAt.year}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${positive ? '+' : ''}${e.delta}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: positive ? AppColors.primaryGreen : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Thẻ điểm Fair Play: vòng điểm, trạng thái được/không được ghép LFG, ghi chú hồi phục.
class FairPlayScoreCard extends StatelessWidget {
  final FairPlaySummary summary;

  const FairPlayScoreCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final score = summary.score;
    final ok = summary.canJoinLfg;
    final color = ok ? AppColors.primaryGreen : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / FairPlayRules.maxScore,
                  strokeWidth: 10,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
                      Text(
                        '/ ${FairPlayRules.maxScore}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ok ? Icons.check_circle : Icons.block, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ok ? ReviewStrings.eligible : ReviewStrings.restricted(FairPlayRules.minScoreForLfg),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (FairPlayRules.isRecovering(score)) ...[
            const SizedBox(height: 8),
            Text(
              ReviewStrings.recovering(FairPlayRules.recoveryCap),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
