import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
import '../../models/lfg_match.dart';
import '../../models/player_survey.dart' show SkillLevel;
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/lfg/lfg_actions.dart';
import '../../widgets/lfg/lfg_approval.dart';

/// Chủ kèo sửa kèo (như "Chỉnh Sửa Kèo Ghép" của Web): số người cần tìm, trình độ, ghi chú, chế độ duyệt.
/// Sân, ca, thể thức, giá không đổi được (hiện ở khung khóa phía trên). Lưu xong trả về kèo mới.
class EditLfgMatchScreen extends StatefulWidget {
  final LfgMatch match;

  const EditLfgMatchScreen({super.key, required this.match});

  @override
  State<EditLfgMatchScreen> createState() => _EditLfgMatchScreenState();
}

class _EditLfgMatchScreenState extends State<EditLfgMatchScreen> {
  late final LfgMatch _m = widget.match;
  late int _needed = _m.totalSlots - 1;
  late SkillLevel? _skill = _m.skillLevel;
  late bool _requireApproval = _m.requireApproval;
  late final _noteController = TextEditingController(text: _m.note);
  bool _saving = false;

  /// Kèo Đội vs Đội: số người theo đội, không đổi được.
  bool get _slotsLocked => _m.isTeamMatch;

  /// Không giảm dưới số người đã vào; không tăng quá số người của thể thức lúc tạo.
  int get _minNeeded => math.max(1, _m.joinerCount);
  int get _maxNeeded => math.max(_minNeeded, math.max(_m.format.totalSlots, _m.totalSlots) - 1);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await AppRepositories.lfg.updateMatch(
        _m.id,
        LfgMatchUpdate(
          slotsNeeded: _slotsLocked ? null : _needed,
          skillLevel: _skill,
          note: _noteController.text,
          requireApproval: _slotsLocked ? _m.requireApproval : _requireApproval,
        ),
      );
      if (mounted) Navigator.pop(context, updated);
    } on LfgException catch (e) {
      if (mounted) showLfgError(context, e.message);
    } catch (_) {
      if (mounted) showLfgError(context, LfgStrings.loadError);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(LfgStrings.editTitle, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocked(),
          const SizedBox(height: 18),
          _title(LfgStrings.stepSlotsNeeded),
          if (_slotsLocked)
            const Text(LfgStrings.teamSlotsLocked, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            _buildStepper(),
          const SizedBox(height: 18),
          _title(LfgStrings.stepSkill),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(LfgStrings.anySkill, _skill == null, () => setState(() => _skill = null)),
              for (final l in SkillLevel.values) _chip(l.label, _skill == l, () => setState(() => _skill = l)),
            ],
          ),
          if (!_slotsLocked) ...[
            const SizedBox(height: 18),
            LfgApprovalSwitch(value: _requireApproval, onChanged: (v) => setState(() => _requireApproval = v)),
          ],
          const SizedBox(height: 18),
          _title(LfgStrings.stepNote),
          TextField(
            controller: _noteController,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: LfgStrings.noteHint,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.divider))),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text(LfgStrings.saveEdit, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  /// Thông tin không sửa được: môn, thể thức, sân, ca, giá mỗi người.
  Widget _buildLocked() {
    final m = _m;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                backgroundColor: AppColors.lightGreen,
                child: Icon(sportIcon(m.sport), color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.sport.label} • ${m.formatLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    Text(m.facilityCourtLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      Formatters.slotLabel(m.start, m.end),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                    ),
                    Text(
                      '${LfgStrings.depositPerSlot}: ${Formatters.vnd(m.depositPerSlot)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.divider),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Expanded(
                child: Text(LfgStrings.lockedInfo, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.outlined(
                onPressed: _needed > _minNeeded ? () => setState(() => _needed--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$_needed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton.outlined(
                onPressed: _needed < _maxNeeded ? () => setState(() => _needed++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(LfgStrings.slotsNeededNote(_m.joinerCount),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  static Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
      );

  static Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        showCheckmark: false,
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryGreen,
        backgroundColor: AppColors.white,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMain),
        side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
}
