import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings/rating_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/rating_repository.dart';
import '../../models/sport.dart';
import '../../models/sport_rating.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/onboarding_required.dart';

/// Khảo sát trình độ toàn diện của một môn (câu hỏi do BE / Admin quản lý) → Elo khởi đầu.
/// Pop kết quả ([SkillAssessment]) khi nộp xong, `null` khi thoát.
class SkillAssessmentScreen extends StatefulWidget {
  final Sport sport;

  const SkillAssessmentScreen({super.key, required this.sport});

  static bool isValidUrl(String url) {
    final u = url.trim();
    return u.length <= RatingStrings.maxUrlLength && (u.startsWith('http://') || u.startsWith('https://'));
  }

  @override
  State<SkillAssessmentScreen> createState() => _SkillAssessmentScreenState();
}

class _SkillAssessmentScreenState extends State<SkillAssessmentScreen> {
  AssessmentForm? _form;
  String? _loadError;
  final Map<String, String> _answers = {};
  final List<TextEditingController> _evidence = [TextEditingController()];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _evidence) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final form = await AppRepositories.rating.getAssessmentForm(widget.sport);
      if (mounted) setState(() => _form = form);
    } on RatingException catch (e) {
      if (!mounted) return;
      if (await handleOnboardingRequired(context, e)) {
        if (mounted) Navigator.pop(context);
        return;
      }
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  /// Chọn ảnh → tải lên → điền link vào ô trống đầu tiên (hoặc thêm ô mới, tối đa 5).
  Future<void> _pickPhoto() async {
    final empty = _evidence.where((c) => c.text.trim().isEmpty).firstOrNull;
    if (empty == null && _evidence.length >= RatingStrings.maxEvidence) {
      return _snack(RatingStrings.evidenceLimit(RatingStrings.maxEvidence));
    }
    final XFile? picked;
    try {
      // Nén nhẹ để ảnh dưới 5MB (image_picker xuất JPEG khi có imageQuality).
      picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
    } catch (_) {
      if (mounted) _snack(RatingStrings.pickPhotoError, error: true);
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await AppRepositories.rating.uploadEvidence(picked.path);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (empty != null) {
          empty.text = url;
        } else {
          _evidence.add(TextEditingController(text: url));
        }
      });
    } on RatingException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack(e.message, error: true);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
  }

  Future<void> _submit() async {
    final form = _form!;
    final missing = form.questions.where((q) => !_answers.containsKey(q.code)).length;
    if (missing > 0) return _snack(RatingStrings.unanswered(missing));
    final urls = _evidence.map((c) => c.text.trim()).where((u) => u.isNotEmpty).toList();
    if (urls.any((u) => !SkillAssessmentScreen.isValidUrl(u))) return _snack(RatingStrings.invalidUrl);

    setState(() => _submitting = true);
    try {
      final result = await AppRepositories.rating.submitAssessment(
        widget.sport,
        answers: {
          for (final q in form.questions)
            if (!q.isScale) q.code: _answers[q.code]!,
        },
        techniques: {
          for (final q in form.questions)
            if (q.isScale) q.code: int.tryParse(_answers[q.code]!) ?? 1,
        },
        evidenceUrls: urls,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(context: context, builder: (_) => AssessmentResultDialog(result: result));
      if (mounted) Navigator.pop(context, result);
    } on RatingException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (await handleOnboardingRequired(context, e)) return;
      _snack(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    final canSubmit = form != null && !form.isBlocked && form.questions.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          RatingStrings.assessmentTitle(widget.sport.label),
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: form == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center),
                          TextButton(onPressed: _load, child: const Text(RatingStrings.retry)),
                        ],
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (form.current != null) ...[
                  _box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(RatingStrings.lastResult, style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        AssessmentResultBody(result: form.current!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (form.isBlocked)
                  _box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          RatingStrings.blockedTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                        ),
                        const SizedBox(height: 4),
                        Text(form.blockedReason!),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    RatingStrings.assessmentIntro,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < form.questions.length; i++) ...[
                    _question(i + 1, form.questions[i]),
                    const SizedBox(height: 10),
                  ],
                  _evidenceBox(),
                ],
              ],
            ),
      bottomNavigationBar: canSubmit
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.authPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                        : const Text(RatingStrings.submit, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _question(int number, AssessmentQuestion q) => _box(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number. ${q.question}', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (q.isScale)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(RatingStrings.scaleHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in q.choices)
              ChoiceChip(
                label: Text(o.label),
                selected: _answers[q.code] == o.value,
                onSelected: _submitting || AssessmentRules.disabledOptions(q, _answers).contains(o.value)
                    ? null
                    : (_) => setState(() {
                        final next = AssessmentRules.answer(_answers, _form!.questions, q.code, o.value);
                        _answers
                          ..clear()
                          ..addAll(next);
                      }),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _evidenceBox() => _box(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(RatingStrings.evidenceTitle, style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(RatingStrings.evidenceHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 8),
        for (final c in _evidence)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: c,
              keyboardType: TextInputType.url,
              maxLength: RatingStrings.maxUrlLength,
              decoration: const InputDecoration(
                labelText: RatingStrings.evidenceLabel,
                hintText: 'https://',
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _uploading || _submitting ? null : _pickPhoto,
              icon: _uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_uploading ? RatingStrings.uploading : RatingStrings.addPhoto),
            ),
            if (_evidence.length < RatingStrings.maxEvidence)
              TextButton.icon(
                onPressed: () => setState(() => _evidence.add(TextEditingController())),
                icon: const Icon(Icons.add_link),
                label: const Text(RatingStrings.addEvidence),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _box(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );
}

/// Nội dung kết quả khảo sát (điểm, Elo, trình độ, bằng chứng, cờ mâu thuẫn).
class AssessmentResultBody extends StatelessWidget {
  final SkillAssessment result;

  const AssessmentResultBody({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RatingStrings.assigned(result.assignedRating),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
        Text(RatingStrings.score(result.score), style: muted),
        if (result.skillLevel != null) Text(RatingStrings.level(result.skillLevel!.label), style: muted),
        if (result.isCapped) Text(RatingStrings.computed(result.computedRating), style: muted),
        if (result.evidenceStatus != EvidenceStatus.none)
          Text(result.evidenceStatus.label, style: const TextStyle(fontSize: 13, color: AppColors.tagOrangeText)),
        if (result.reviewNote.isNotEmpty) Text(RatingStrings.reviewNote(result.reviewNote), style: muted),
        if (result.flags.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text(RatingStrings.flagsTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          for (final f in result.flags) Text('• $f', style: muted),
        ],
      ],
    );
  }
}

class AssessmentResultDialog extends StatelessWidget {
  final SkillAssessment result;

  const AssessmentResultDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(RatingStrings.resultTitle),
    content: SingleChildScrollView(child: AssessmentResultBody(result: result)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text(RatingStrings.done))],
  );
}
