import 'package:flutter/material.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import 'owner_form.dart';

/// Mở sheet tạm đóng cả cơ sở hoặc một loại sân. Trả về [OwnerFacility] sau khi đóng thành công.
Future<OwnerFacility?> showClosureSheet(BuildContext context, OwnerFacility facility) =>
    showModalBottomSheet<OwnerFacility>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClosureSheet(facility: facility),
    );

class _ClosureSheet extends StatefulWidget {
  final OwnerFacility facility;

  const _ClosureSheet({required this.facility});

  @override
  State<_ClosureSheet> createState() => _ClosureSheetState();
}

class _ClosureSheetState extends State<_ClosureSheet> {
  final _reason = TextEditingController();

  /// `null` = cả cơ sở.
  CourtConfig? _court;
  DateTimeRange? _range;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _save() async {
    final range = _range;
    if (range == null || _reason.text.trim().isEmpty) {
      setState(() => _error = OwnerFacilityStrings.missingInfo);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await AppRepositories.owner.addClosure(
        widget.facility.id,
        sport: _court?.sport,
        courtType: _court?.courtType,
        from: range.start,
        to: range.end,
        reason: _reason.text,
      );
      if (mounted) Navigator.pop(context, updated);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                OwnerFacilityStrings.closureTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CourtConfig?>(
                isExpanded: true,
                initialValue: _court,
                decoration: ownerInputDecoration(OwnerFacilityStrings.closureScope),
                items: [
                  const DropdownMenuItem(value: null, child: Text(OwnerFacilityStrings.wholeFacility)),
                  for (final c in widget.facility.activeCourts) DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) => setState(() => _court = c),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  range == null
                      ? OwnerFacilityStrings.chooseDates
                      : OwnerFacilityStrings.closureRange(
                          Formatters.weekdayDayMonth(range.start),
                          Formatters.weekdayDayMonth(range.end),
                        ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _reason, decoration: ownerInputDecoration(OwnerFacilityStrings.closureReason)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(OwnerFacilityStrings.confirmClosure, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
