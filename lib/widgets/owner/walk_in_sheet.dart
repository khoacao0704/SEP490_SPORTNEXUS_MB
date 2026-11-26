import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_booking.dart';
import '../../theme/app_colors.dart';
import 'owner_cancel_dialog.dart';

/// Một ca trên lưới kèm sân con của nó.
typedef CourtSlot = ({ScheduleCourt court, ScheduleSlot slot});

/// Số ca trống liên tiếp tính từ [slot] trên [court] (để đặt nhiều giờ một lần).
int consecutiveFreeSlots(ScheduleCourt court, ScheduleSlot slot) {
  final list = court.slots;
  var i = list.indexWhere((s) => s.id == slot.id);
  if (i < 0) return 1;
  var count = 0;
  for (; i < list.length; i++) {
    if (list[i].state != SlotCellState.available) break;
    if (count > 0 && list[i - 1].end != list[i].start) break;
    count++;
  }
  return count < 1 ? 1 : count;
}

/// Mở popup "Đặt giữ chỗ nhanh (Khách vãng lai)". [items] một phần tử = bấm một ô trống
/// (có Số ca liên tiếp, Đổi giá, Khóa ca); nhiều phần tử = chọn nhiều ca / nhập giờ thủ công.
/// Trả về `true` nếu lưới cần tải lại (đã tạo đơn, đổi giá hoặc khóa ca).
Future<bool> showWalkInSheet(BuildContext context, {required List<CourtSlot> items, required DateTime date}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _WalkInSheet(items: items, date: date, single: items.length == 1),
  );
  return changed ?? false;
}

class _WalkInSheet extends StatefulWidget {
  final List<CourtSlot> items;
  final DateTime date;
  final bool single;

  const _WalkInSheet({required this.items, required this.date, required this.single});

  @override
  State<_WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<_WalkInSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();
  int _slots = 1;
  bool _autoCheckIn = false;
  bool _editingPrice = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _price.dispose();
    super.dispose();
  }

  CourtSlot get _first => widget.items.first;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = ownerErrorMessage(e);
        });
      }
    }
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = OwnerStrings.walkInNameRequired);
      return;
    }
    final phone = _phone.text.trim();
    final note = _note.text.trim();
    final request = widget.single
        ? WalkInRequest(
            courtSlotId: _first.slot.id,
            numberOfSlots: _slots,
            customerName: name,
            customerPhone: phone.isEmpty ? null : phone,
            note: note.isEmpty ? null : note,
            autoCheckIn: _autoCheckIn,
          )
        : WalkInRequest(
            courtSlotIds: [for (final i in widget.items) i.slot.id],
            customerName: name,
            customerPhone: phone.isEmpty ? null : phone,
            note: note.isEmpty ? null : note,
            autoCheckIn: _autoCheckIn,
          );
    _run(
      () => AppRepositories.owner.createWalkIn(request),
      widget.single
          ? OwnerStrings.walkInDone(name, _first.court.name, Formatters.time(_first.slot.start))
          : OwnerStrings.walkInDoneMulti(widget.items.length, name),
    );
  }

  void _savePrice() {
    final price = int.tryParse(_price.text.trim());
    if (price == null || price < 1000) {
      setState(() => _error = OwnerStrings.priceTooLow);
      return;
    }
    _run(
      () => AppRepositories.owner.setSlotPrice(_first.slot.id, price),
      OwnerStrings.priceChanged(Formatters.time(_first.slot.start), price),
    );
  }

  void _lock() => _run(
        () => AppRepositories.owner.setSlotLocked(_first.slot.id, locked: true),
        OwnerStrings.slotLocked,
      );

  @override
  Widget build(BuildContext context) {
    final dateLabel = Formatters.date(widget.date);
    final maxSlots = widget.single ? consecutiveFreeSlots(_first.court, _first.slot) : 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      OwnerStrings.walkInTitle,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                child: widget.single ? _singleInfo(dateLabel) : _multiInfo(dateLabel),
              ),
              const SizedBox(height: 14),
              _label(OwnerStrings.walkInName),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _input(OwnerStrings.walkInNameHint),
              ),
              const SizedBox(height: 12),
              _label(OwnerStrings.walkInPhone),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                decoration: _input(OwnerStrings.walkInPhoneHint),
              ),
              if (widget.single) ...[
                const SizedBox(height: 12),
                _label(OwnerStrings.walkInSlots),
                DropdownButtonFormField<int>(
                  initialValue: _slots,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: [for (var n = 1; n <= maxSlots; n++) DropdownMenuItem(value: n, child: Text('$n'))],
                  onChanged: _busy ? null : (v) => setState(() => _slots = v ?? 1),
                ),
              ],
              const SizedBox(height: 12),
              _label(OwnerStrings.walkInNote),
              TextField(controller: _note, decoration: _input(OwnerStrings.walkInNoteHint)),
              CheckboxListTile(
                value: _autoCheckIn,
                onChanged: _busy ? null : (v) => setState(() => _autoCheckIn = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text(OwnerStrings.walkInAutoCheckIn, style: TextStyle(fontSize: 14)),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.single)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _lock,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text(OwnerStrings.lockSlot),
                    ),
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(OwnerStrings.close)),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_busy ? OwnerStrings.walkInSubmitting : OwnerStrings.walkInSubmit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _singleInfo(String dateLabel) {
    final slot = _first.slot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_first.court.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain)),
        const SizedBox(height: 2),
        Text(
          '${OwnerStrings.walkInStart(Formatters.time(slot.start), dateLabel)} • ${OwnerStrings.walkInPrice(slot.price)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textMain),
        ),
        if (!_editingPrice)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _editingPrice = true;
                _price.text = '${slot.price}';
              }),
              child: const Text(OwnerStrings.changePrice),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _input(OwnerStrings.newPriceHint),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(onPressed: _busy ? null : _savePrice, child: const Text(OwnerStrings.savePrice)),
              TextButton(
                onPressed: () => setState(() => _editingPrice = false),
                child: const Text(OwnerStrings.cancelEdit),
              ),
            ],
          ),
      ],
    );
  }

  Widget _multiInfo(String dateLabel) {
    final total = widget.items.fold(0, (sum, i) => sum + i.slot.price);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(OwnerStrings.walkInMulti(widget.items.length, dateLabel),
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain)),
        const SizedBox(height: 4),
        for (final i in widget.items)
          Row(
            children: [
              Expanded(
                child: Text('${i.court.name} • ${Formatters.timeRange(i.slot.start, i.slot.end)}',
                    style: const TextStyle(fontSize: 13)),
              ),
              Text(Formatters.vnd(i.slot.price), style: const TextStyle(fontSize: 13)),
            ],
          ),
        const Divider(),
        Row(
          children: [
            const Expanded(child: Text(OwnerStrings.walkInTotal, style: TextStyle(fontWeight: FontWeight.bold))),
            Text(Formatters.vnd(total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}
