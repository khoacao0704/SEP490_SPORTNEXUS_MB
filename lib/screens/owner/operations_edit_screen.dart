import 'package:flutter/material.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_form.dart';
import '../../widgets/owner/photo_picker.dart';

/// Sửa thông tin vận hành (không cần Admin duyệt lại). Pop trả về [OwnerFacility] sau khi lưu.
class OperationsEditScreen extends StatefulWidget {
  final OwnerFacility facility;

  const OperationsEditScreen({super.key, required this.facility});

  @override
  State<OperationsEditScreen> createState() => _OperationsEditScreenState();
}

class _OperationsEditScreenState extends State<OperationsEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FacilityOperations _o = widget.facility.operations;
  late final _phone = TextEditingController(text: _o.phone);
  late final _description = TextEditingController(text: _o.description);
  late int _open = _o.openMinutes;
  late int _close = _o.closeMinutes;
  late List<String> _amenities = [..._o.amenities];
  late List<String> _rules = [..._o.rules];
  late List<String> _photos = [..._o.images];
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<String?> _ask(String title) => showTextPrompt(
    context,
    title: title,
    confirmLabel: OwnerFacilityStrings.add,
    cancelLabel: OwnerFacilityStrings.cancel,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_close <= _open || _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_close <= _open ? OwnerFacilityStrings.invalidHours : OwnerFacilityStrings.missingPhoto),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await AppRepositories.owner.updateOperations(
        widget.facility.id,
        FacilityOperations(
          phone: _phone.text.trim(),
          openMinutes: _open,
          closeMinutes: _close,
          description: _description.text.trim(),
          amenities: _amenities,
          rules: _rules,
          images: _photos,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.saved)));
      Navigator.pop(context, updated);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerFacilityStrings.operationsTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormSection(
              title: OwnerFacilityStrings.sectionOperations,
              children: [
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.phone),
                  validator: (v) => isFacilityPhone(v ?? '') ? null : OwnerFacilityStrings.invalidPhone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TimeField(
                        label: OwnerFacilityStrings.openTime,
                        minutes: _open,
                        onChanged: (m) => setState(() => _open = m),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TimeField(
                        label: OwnerFacilityStrings.closeTime,
                        minutes: _close,
                        onChanged: (m) => setState(() => _close = m),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.description),
                ),
              ],
            ),
            FormSection(
              title: OwnerFacilityStrings.amenities,
              trailing: TextButton.icon(
                onPressed: () async {
                  final v = await _ask(OwnerFacilityStrings.addAmenity);
                  if (v != null) setState(() => _amenities = [..._amenities, v]);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text(OwnerFacilityStrings.add),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
              ),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in _amenities)
                      Chip(
                        label: Text(a),
                        backgroundColor: AppColors.lightGreen,
                        onDeleted: () => setState(() => _amenities = _amenities.where((x) => x != a).toList()),
                      ),
                  ],
                ),
              ],
            ),
            FormSection(
              title: OwnerFacilityStrings.rules,
              trailing: TextButton.icon(
                onPressed: () async {
                  final v = await _ask(OwnerFacilityStrings.addRule);
                  if (v != null) setState(() => _rules = [..._rules, v]);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text(OwnerFacilityStrings.add),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
              ),
              children: [
                for (var i = 0; i < _rules.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('${i + 1}.', style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_rules[i])),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _rules = [..._rules]..removeAt(i)),
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
            FormSection(
              title: OwnerFacilityStrings.formPhotos,
              children: [PhotoPickerGrid(photos: _photos, onChanged: (p) => setState(() => _photos = p))],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SubmitBar(label: OwnerFacilityStrings.save, busy: _saving, onPressed: _save),
    );
  }
}
