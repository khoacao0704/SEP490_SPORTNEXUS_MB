import 'package:flutter/material.dart';

import '../../core/strings/team_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/team_repository.dart';
import '../../models/team.dart';
import '../../theme/app_colors.dart';

/// Tạo đội mới (kèm mời thành viên bằng SĐT) hoặc sửa tên / giới thiệu đội ([team] khác null).
/// Pop về đội vừa tạo / sửa.
class TeamFormScreen extends StatefulWidget {
  final Team? team;

  const TeamFormScreen({super.key, this.team});

  /// Tách SĐT theo dòng / dấu phẩy / dấu chấm phẩy, bỏ trùng.
  static List<String> parsePhones(String raw) =>
      raw.split(RegExp(r'[\s,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.team?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.team?.description ?? '');
  final TextEditingController _phones = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.team != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phones.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(TeamStrings.nameRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = AppRepositories.team;
      final team = _isEdit
          ? await repo.updateTeam(widget.team!.id, name: _name.text, description: _description.text)
          : await repo.createTeam(
              name: _name.text,
              description: _description.text,
              invitePhones: TeamFormScreen.parsePhones(_phones.text),
            );
      if (mounted) Navigator.pop(context, team);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          _isEdit ? TeamStrings.editTeam : TeamStrings.createTeam,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, maxLength: 100, decoration: _decoration(TeamStrings.teamName)),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLength: 1000,
            maxLines: 3,
            decoration: _decoration(TeamStrings.teamDescription),
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _phones,
              maxLines: 3,
              keyboardType: TextInputType.phone,
              decoration: _decoration(TeamStrings.invitePhonesLabel, hint: TeamStrings.invitePhonesHint),
            ),
            const SizedBox(height: 6),
            const Text(TeamStrings.inviteNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.authPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                  : Text(
                      _isEdit ? TeamStrings.save : TeamStrings.create,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
