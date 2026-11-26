import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/vietnam_cities.dart';
import '../../core/strings/owner_facility_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/geo_point.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';
import '../../widgets/owner/slot_pickers.dart';
import 'location_picker_screen.dart';

/// Tạo cơ sở mới hoặc sửa thông tin cơ sở (FacilityForm của Web).
/// Địa chỉ: chọn tỉnh / phường (lưu bằng mã) + số nhà; tọa độ ghim trên bản đồ hoặc nhập tay.
/// Tạo mới chọn kèm tiện ích; sửa thì tiện ích và ảnh sửa riêng ở chi tiết cơ sở.
/// Pop trả về [OwnerFacility] đã lưu.
class FacilityFormScreen extends StatefulWidget {
  /// null = tạo mới.
  final OwnerFacility? facility;

  const FacilityFormScreen({super.key, this.facility});

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  OwnerFacility? get _f => widget.facility;
  bool get _creating => _f == null;

  late final _name = TextEditingController(text: _f?.profile.name ?? '');
  late final _street = TextEditingController(text: _f?.streetAddress ?? _streetFromAddress(_f));
  late final _phone = TextEditingController(text: _f?.operations.phone ?? '');
  late final _lat = TextEditingController(text: _hasLocation(_f) ? '${_f!.profile.location.latitude}' : '');
  late final _lng = TextEditingController(text: _hasLocation(_f) ? '${_f!.profile.location.longitude}' : '');
  late final _description = TextEditingController(text: _f?.operations.description ?? '');
  late final _rules = TextEditingController(text: _f?.operations.rules.join('\n') ?? '');
  late final _discount = TextEditingController(text: '${_f?.recurringDiscountPercent ?? 10}');
  late String _open = _f == null ? '06:00' : formatMinutes(_f!.operations.openMinutes);
  late String _close = _f == null ? '22:00' : formatMinutes(_f!.operations.closeMinutes);
  late bool _autoSlots = _f?.autoGenerateSlots ?? true;

  List<AreaOption> _provinces = const [];
  List<AreaOption> _wards = const [];
  String? _provinceCode;
  String? _wardCode;
  List<FacilityAmenity> _amenities = const [];
  final Set<String> _amenityIds = {};
  bool _busy = false;
  bool _showErrors = false;
  String? _error;

  static bool _hasLocation(OwnerFacility? f) =>
      f != null && (f.profile.location.latitude != 0 || f.profile.location.longitude != 0);

  /// Cơ sở cũ chỉ có địa chỉ ghép: bỏ phần phường, tỉnh ở cuối để ô số nhà không bị lặp khi lưu lại.
  static String _streetFromAddress(OwnerFacility? f) {
    if (f == null) return '';
    final parts = f.profile.address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    while (parts.isNotEmpty && (parts.last == f.profile.city || parts.last == f.profile.ward)) {
      parts.removeLast();
    }
    return parts.join(', ');
  }

  @override
  void initState() {
    super.initState();
    _loadAreas();
    if (_creating) {
      AppRepositories.owner.getAmenities().then((a) {
        if (mounted) setState(() => _amenities = a);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _street, _phone, _lat, _lng, _description, _rules, _discount]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAreas() async {
    try {
      final provinces = await AppRepositories.owner.getProvinces();
      if (!mounted) return;
      final f = _f;
      final code = f?.provinceCode ?? provinces.where((p) => p.name == f?.profile.city).firstOrNull?.code;
      setState(() {
        _provinces = provinces;
        _provinceCode = provinces.any((p) => p.code == code) ? code : null;
      });
      if (_provinceCode != null) await _loadWards(_provinceCode!, keepWard: true);
    } catch (e) {
      if (mounted) setState(() => _error = ownerErrorMessage(e));
    }
  }

  Future<void> _loadWards(String provinceCode, {bool keepWard = false}) async {
    final wards = await AppRepositories.owner.getWards(provinceCode);
    if (!mounted || provinceCode != _provinceCode) return;
    final f = _f;
    final code = keepWard ? (f?.wardCode ?? wards.where((w) => w.name == f?.profile.ward).firstOrNull?.code) : null;
    setState(() {
      _wards = wards;
      _wardCode = wards.any((w) => w.code == code) ? code : null;
    });
  }

  Future<void> _pickOnMap() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final current = lat != null && lng != null ? GeoPoint(lat, lng) : null;
    final cityName = _provinces.where((p) => p.code == _provinceCode).firstOrNull?.name;
    final center = current ??
        VietnamCities.all.where((c) => c.name == cityName).firstOrNull?.center ??
        VietnamCities.hoChiMinh.center;
    final picked = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialCenter: center, initial: current)),
    );
    if (picked == null) return;
    setState(() {
      _lat.text = picked.latitude.toStringAsFixed(6);
      _lng.text = picked.longitude.toStringAsFixed(6);
    });
  }

  /// Kiểm tra như validateOwnerForm của Web; trả về câu lỗi hoặc null.
  String? _validate() {
    if (_name.text.trim().isEmpty) return OwnerFacilityStrings.errName;
    if (_provinceCode == null || _wardCode == null || _street.text.trim().isEmpty) return OwnerFacilityStrings.errAddress;
    final latText = _lat.text.trim();
    final lngText = _lng.text.trim();
    if (latText.isEmpty != lngText.isEmpty) return OwnerFacilityStrings.errLatLng;
    if (latText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        return OwnerFacilityStrings.errLatLngRange;
      }
    }
    if (parseMinutes(_close) <= parseMinutes(_open)) return OwnerFacilityStrings.errHours;
    final pct = int.tryParse(_discount.text.trim());
    if (pct == null || pct < 0 || pct > 50) return OwnerFacilityStrings.errDiscount;
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    setState(() {
      _showErrors = true;
      _error = error;
    });
    if (error != null) return;
    final description = _description.text.trim();
    final rules = _rules.text.trim();
    final phone = _phone.text.trim();
    final input = FacilityInput(
      name: _name.text.trim(),
      streetAddress: _street.text.trim().replaceAll(RegExp(r',+$'), '').trim(),
      provinceCode: _provinceCode!,
      wardCode: _wardCode!,
      latitude: double.tryParse(_lat.text.trim()),
      longitude: double.tryParse(_lng.text.trim()),
      phone: phone.isEmpty ? null : phone,
      openTime: _open,
      closeTime: _close,
      description: description.isEmpty ? null : description,
      rules: rules.isEmpty ? null : rules,
      autoGenerateSlots: _autoSlots,
      recurringDiscountPercent: int.parse(_discount.text.trim()),
      amenityIds: _amenityIds.toList(),
    );
    setState(() => _busy = true);
    try {
      final saved = _creating
          ? await AppRepositories.owner.createFacility(input)
          : await AppRepositories.owner.updateFacility(_f!.id, input);
      if (!mounted) return;
      showOwnerSnack(context, _creating ? OwnerFacilityStrings.created : OwnerFacilityStrings.infoSaved);
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = ownerErrorMessage(e);
        });
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, bool invalid = false}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        errorText: invalid ? '' : null,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      );

  @override
  Widget build(BuildContext context) {
    final missing = _showErrors;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          _creating ? OwnerFacilityStrings.createTitle : OwnerFacilityStrings.editTitle,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_creating)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(OwnerFacilityStrings.createHint, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          TextField(
            controller: _name,
            maxLength: 200,
            decoration: _dec(OwnerFacilityStrings.fName, invalid: missing && _name.text.trim().isEmpty)
                .copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('p-$_provinceCode-${_provinces.length}'),
            initialValue: _provinceCode,
            isExpanded: true,
            decoration: _dec(OwnerFacilityStrings.fProvince, invalid: missing && _provinceCode == null),
            items: [for (final p in _provinces) DropdownMenuItem(value: p.code, child: Text(p.name))],
            onChanged: (v) {
              setState(() {
                _provinceCode = v;
                _wardCode = null;
                _wards = const [];
              });
              if (v != null) _loadWards(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('w-$_provinceCode-$_wardCode-${_wards.length}'),
            initialValue: _wardCode,
            isExpanded: true,
            decoration: _dec(OwnerFacilityStrings.fWard, invalid: missing && _wardCode == null),
            items: [for (final w in _wards) DropdownMenuItem(value: w.code, child: Text(w.name))],
            onChanged: (v) => setState(() => _wardCode = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _street,
            decoration: _dec(OwnerFacilityStrings.fStreet, invalid: missing && _street.text.trim().isEmpty),
          ),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec(OwnerFacilityStrings.fPhone)),
          const SizedBox(height: 16),
          const Text(OwnerFacilityStrings.fMap, style: TextStyle(fontWeight: FontWeight.w600)),
          const Text(OwnerFacilityStrings.fMapHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(OwnerFacilityStrings.fPickOnMap),
              ),
              if (_lat.text.isNotEmpty || _lng.text.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _lat.clear();
                    _lng.clear();
                  }),
                  child: const Text(OwnerFacilityStrings.fClearPin),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                  decoration: _dec(OwnerFacilityStrings.fLat),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                  decoration: _dec(OwnerFacilityStrings.fLng),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TimeButton(
                  label: OwnerFacilityStrings.fOpen,
                  value: _open,
                  clearable: false,
                  onChanged: (v) => setState(() => _open = v ?? _open),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TimeButton(
                  label: OwnerFacilityStrings.fClose,
                  value: _close,
                  clearable: false,
                  onChanged: (v) => setState(() => _close = v ?? _close),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLength: 2000, minLines: 2, maxLines: 5, decoration: _dec(OwnerFacilityStrings.fDescription)),
          const SizedBox(height: 4),
          TextField(controller: _rules, maxLength: 2000, minLines: 2, maxLines: 5, decoration: _dec(OwnerFacilityStrings.fRules)),
          CheckboxListTile(
            value: _autoSlots,
            onChanged: (v) => setState(() => _autoSlots = v ?? true),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(OwnerFacilityStrings.fAutoSlots, style: TextStyle(fontSize: 14)),
          ),
          TextField(
            controller: _discount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec(OwnerFacilityStrings.fDiscount, hint: '10'),
          ),
          const SizedBox(height: 4),
          const Text(OwnerFacilityStrings.fDiscountHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (_creating && _amenities.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(OwnerFacilityStrings.fAmenities, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in _amenities)
                  FilterChip(
                    label: Text(a.name),
                    selected: _amenityIds.contains(a.id),
                    onSelected: (on) => setState(() => on ? _amenityIds.add(a.id) : _amenityIds.remove(a.id)),
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text(OwnerFacilityStrings.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                  child: Text(_creating ? OwnerFacilityStrings.createSubmit : OwnerFacilityStrings.saveInfo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
