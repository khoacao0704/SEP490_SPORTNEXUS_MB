import 'package:flutter/material.dart';

import '../../core/constants/vietnam_cities.dart';
import '../../core/strings/owner_facility_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/court_type.dart';
import '../../models/geo_point.dart';
import '../../models/owner_facility.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_form.dart';
import '../../widgets/owner/photo_picker.dart';
import 'location_picker_screen.dart';

enum FacilityFormMode {
  /// Đăng cơ sở mới.
  create,

  /// Sửa hồ sơ bị từ chối và nộp lại.
  resubmit,

  /// Cơ sở đã duyệt xin đổi tên / địa chỉ / giấy phép.
  change,
}

/// Form hồ sơ cơ sở gửi Admin duyệt. Pop trả về [OwnerFacility] sau khi gửi thành công.
class FacilityFormScreen extends StatefulWidget {
  final FacilityFormMode mode;
  final OwnerFacility? facility;

  const FacilityFormScreen({super.key, this.mode = FacilityFormMode.create, this.facility})
    : assert(mode == FacilityFormMode.create || facility != null);

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FacilityProfile? _p = widget.mode == FacilityFormMode.change
      ? (widget.facility!.change?.profile ?? widget.facility!.profile)
      : widget.facility?.profile;
  late final FacilityOperations? _o = widget.facility?.operations;

  late final _name = TextEditingController(text: _p?.name);
  late final _ward = TextEditingController(text: _p?.ward);
  late final _address = TextEditingController(text: _p?.address);
  late final _license = TextEditingController(text: _p?.licenseNumber);
  late final _phone = TextEditingController(text: _o?.phone);
  late final _description = TextEditingController(text: _o?.description);

  late String _city = _p?.city ?? VietnamCities.hoChiMinh.name;
  late GeoPoint? _location = _p?.location;
  late List<String> _licenseImages = [...?_p?.licenseImages];
  late List<String> _photos = [...?_o?.images];
  late int _open = _o?.openMinutes ?? 6 * 60;
  late int _close = _o?.closeMinutes ?? 22 * 60;
  late List<CourtConfig> _courts = [...?widget.facility?.courts];

  bool _submitting = false;

  /// Bật sau lần bấm gửi đầu tiên để hiện lỗi ảnh / vị trí / loại sân.
  bool _showErrors = false;

  bool get _profileOnly => widget.mode == FacilityFormMode.change;

  @override
  void dispose() {
    for (final c in [_name, _ward, _address, _license, _phone, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _title => switch (widget.mode) {
    FacilityFormMode.create => OwnerFacilityStrings.registerTitle,
    FacilityFormMode.resubmit => OwnerFacilityStrings.resubmitTitle,
    FacilityFormMode.change => OwnerFacilityStrings.changeTitle,
  };

  String? get _locationError => _showErrors && _location == null ? OwnerFacilityStrings.missingLocation : null;
  String? get _licenseError => _showErrors && _licenseImages.isEmpty ? OwnerFacilityStrings.missingLicenseImage : null;
  String? get _photoError => _showErrors && _photos.isEmpty ? OwnerFacilityStrings.missingPhoto : null;
  String? get _courtError {
    if (!_showErrors) return null;
    if (_courts.isEmpty) return OwnerFacilityStrings.missingCourt;
    final kinds = _courts.map((c) => '${c.sport.name}/${c.courtType.name}').toSet();
    return kinds.length == _courts.length ? null : OwnerFacilityStrings.duplicateCourt;
  }

  String? get _hoursError => _showErrors && _close <= _open ? OwnerFacilityStrings.invalidHours : null;

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialCenter: VietnamCities.byName(_city).center, initial: _location),
      ),
    );
    if (picked != null) setState(() => _location = picked);
  }

  void _addCourt() {
    // Gợi ý loại sân chưa có trong danh sách.
    for (final sport in Sport.values) {
      for (final type in CourtType.forSport(sport)) {
        if (!_courts.any((c) => c.sameKind(sport, type))) {
          setState(() => _courts = [..._courts, CourtConfig(sport: sport, courtType: type, courtCount: 1)]);
          return;
        }
      }
    }
  }

  void _updateCourt(int i, CourtConfig c) => setState(() => _courts = [..._courts]..[i] = c);

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    final formOk = _formKey.currentState!.validate();
    final extrasOk =
        _locationError == null &&
        _licenseError == null &&
        (_profileOnly || (_photoError == null && _courtError == null && _hoursError == null));
    if (!formOk || !extrasOk) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.missingInfo), backgroundColor: Colors.red));
      return;
    }

    final profile = FacilityProfile(
      name: _name.text.trim(),
      city: _city,
      ward: _ward.text.trim(),
      address: _address.text.trim(),
      location: _location!,
      licenseNumber: _license.text.trim(),
      licenseImages: _licenseImages,
    );
    setState(() => _submitting = true);
    try {
      final repo = AppRepositories.owner;
      final OwnerFacility result;
      if (_profileOnly) {
        result = await repo.requestProfileChange(widget.facility!.id, profile);
      } else {
        final submission = FacilitySubmission(
          profile: profile,
          operations: FacilityOperations(
            phone: _phone.text.trim(),
            openMinutes: _open,
            closeMinutes: _close,
            description: _description.text.trim(),
            amenities: _o?.amenities ?? const [],
            rules: _o?.rules ?? const [],
            images: _photos,
          ),
          courts: _courts,
        );
        result = widget.mode == FacilityFormMode.resubmit
            ? await repo.resubmitFacility(widget.facility!.id, submission)
            : await repo.submitFacility(submission);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_profileOnly ? OwnerFacilityStrings.changeSubmitted : OwnerFacilityStrings.submitted)),
      );
      Navigator.pop(context, result);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? OwnerFacilityStrings.required : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          _title,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_profileOnly)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  OwnerFacilityStrings.changePendingBanner,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            FormSection(
              title: OwnerFacilityStrings.formBasic,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.name),
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _city,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.city),
                  items: [for (final c in VietnamCities.all) DropdownMenuItem(value: c.name, child: Text(c.name))],
                  onChanged: (v) => setState(() => _city = v ?? _city),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ward,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.ward),
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.address),
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: Icon(_location == null ? Icons.add_location_alt_outlined : Icons.check_circle),
                  label: Text(
                    _location == null ? OwnerFacilityStrings.pickLocation : OwnerFacilityStrings.locationPicked,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: BorderSide(color: _locationError != null ? Colors.red : AppColors.primaryGreen),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
                if (_location != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_locationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                if (!_profileOnly) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: ownerInputDecoration(OwnerFacilityStrings.phone),
                    validator: (v) => _required(v) ?? (isFacilityPhone(v!) ? null : OwnerFacilityStrings.invalidPhone),
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
                  if (_hoursError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_hoursError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: ownerInputDecoration(OwnerFacilityStrings.description),
                  ),
                ],
              ],
            ),
            if (!_profileOnly) ...[
              FormSection(
                title: OwnerFacilityStrings.formCourts,
                hint: OwnerFacilityStrings.formCourtsHint,
                trailing: TextButton.icon(
                  onPressed: _addCourt,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(OwnerFacilityStrings.add),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                ),
                children: [
                  for (var i = 0; i < _courts.length; i++) _courtRow(i),
                  if (_courtError != null) Text(_courtError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
              FormSection(
                title: OwnerFacilityStrings.formPhotos,
                children: [
                  PhotoPickerGrid(
                    photos: _photos,
                    errorText: _photoError,
                    onChanged: (p) => setState(() => _photos = p),
                  ),
                ],
              ),
            ],
            FormSection(
              title: OwnerFacilityStrings.formLicense,
              hint: OwnerFacilityStrings.licenseHint,
              children: [
                TextFormField(
                  controller: _license,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.licenseNumber),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                PhotoPickerGrid(
                  photos: _licenseImages,
                  errorText: _licenseError,
                  onChanged: (p) => setState(() => _licenseImages = p),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SubmitBar(
        label: _profileOnly ? OwnerFacilityStrings.submitChange : OwnerFacilityStrings.submit,
        busy: _submitting,
        onPressed: _submit,
      ),
    );
  }

  Widget _courtRow(int i) {
    final c = _courts[i];
    final types = CourtType.forSport(c.sport);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Sport>(
                  isExpanded: true,
                  initialValue: c.sport,
                  decoration: ownerInputDecoration(OwnerFacilityStrings.sport),
                  items: [for (final s in Sport.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (s) {
                    if (s == null) return;
                    _updateCourt(
                      i,
                      CourtConfig(sport: s, courtType: CourtType.forSport(s).first, courtCount: c.courtCount),
                    );
                  },
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _courts = [..._courts]..removeAt(i)),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: types.length == 1
                    ? Text(types.first.label, style: const TextStyle(color: AppColors.textSecondary))
                    : DropdownButtonFormField<CourtType>(
                        isExpanded: true,
                        key: ValueKey('type-$i-${c.sport.name}'),
                        initialValue: c.courtType,
                        decoration: ownerInputDecoration(OwnerFacilityStrings.courtType),
                        items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t.label))],
                        onChanged: (t) {
                          if (t != null) {
                            _updateCourt(i, CourtConfig(sport: c.sport, courtType: t, courtCount: c.courtCount));
                          }
                        },
                      ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    OwnerFacilityStrings.courtCount,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  CountStepper(
                    value: c.courtCount,
                    onChanged: (n) => _updateCourt(i, c.copyWith(courtCount: n)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
