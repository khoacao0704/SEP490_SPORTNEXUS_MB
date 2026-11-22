import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/identity_rules.dart';
import '../../core/strings/identity_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/identity_repository.dart';
import '../../models/identity_verification.dart';
import '../../theme/app_colors.dart';

/// 3 ảnh của hồ sơ eKYC.
enum IdentityPhoto {
  idFront(IdentityStrings.idFront, Icons.badge_outlined),
  idBack(IdentityStrings.idBack, Icons.credit_card),
  selfie(IdentityStrings.selfie, Icons.face_retouching_natural);

  final String label;
  final IconData icon;

  const IdentityPhoto(this.label, this.icon);
}

/// Chọn ảnh cho [photo]: trả đường dẫn file trong máy, `null` khi người dùng bỏ.
typedef IdentityPhotoPicker = Future<String?> Function(BuildContext context, IdentityPhoto photo);

/// Xác minh danh tính (eKYC): xem trạng thái; chưa gửi / bị từ chối thì nhập thông tin CCCD + chụp 3 ảnh rồi gửi.
/// Pop về `true` nếu vừa gửi hồ sơ.
class IdentityVerificationScreen extends StatefulWidget {
  /// Thay bộ chọn ảnh (test). Mặc định: hỏi chụp / thư viện rồi mở image_picker.
  final IdentityPhotoPicker? pickPhoto;

  const IdentityVerificationScreen({super.key, this.pickPhoto});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _PhotoSlot {
  String? localPath;
  String? url;
  bool uploading = false;
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _idNumber = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;
  String? _dobError;
  String? _photoError;
  final Map<IdentityPhoto, _PhotoSlot> _photos = {for (final p in IdentityPhoto.values) p: _PhotoSlot()};

  IdentityVerification? _current;
  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  bool _submitted = false;

  bool get _showForm => _current == null || _current!.canResubmit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _idNumber.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final current = await AppRepositories.identity.getMyVerification();
      if (!mounted) return;
      setState(() {
        _current = current;
        _loading = false;
        // Bị từ chối: điền lại thông tin cũ để sửa (ảnh phải chụp lại).
        if (current != null && current.canResubmit) {
          _name.text = current.fullName;
          _idNumber.text = current.idNumber;
          _address.text = current.address;
          _dob = current.dateOfBirth;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is IdentityException ? e.message : IdentityStrings.loadError;
      });
    }
  }

  Future<String?> _defaultPick(BuildContext context, IdentityPhoto photo) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(IdentityStrings.takePhoto),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(IdentityStrings.fromGallery),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    // Nén nhẹ để ảnh dưới 5MB (image_picker xuất JPEG khi có imageQuality).
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
      preferredCameraDevice: photo == IdentityPhoto.selfie ? CameraDevice.front : CameraDevice.rear,
    );
    return picked?.path;
  }

  Future<void> _pick(IdentityPhoto photo) async {
    final slot = _photos[photo]!;
    if (slot.uploading) return;
    String? path;
    try {
      path = await (widget.pickPhoto ?? _defaultPick)(context, photo);
    } catch (_) {
      _snack(IdentityStrings.pickError, error: true);
      return;
    }
    if (path == null || !mounted) return;
    setState(() {
      slot.localPath = path;
      slot.url = null;
      slot.uploading = true;
      _photoError = null;
    });
    try {
      final url = await AppRepositories.identity.uploadImage(path);
      if (mounted) setState(() => slot.url = url);
    } on IdentityException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack(IdentityStrings.uploadError, error: true);
    } finally {
      if (mounted) setState(() => slot.uploading = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - IdentityRules.minAge, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? latest,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: IdentityStrings.pickDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _dobError = null;
    });
  }

  String? _validateDob() {
    final dob = _dob;
    if (dob == null) return IdentityStrings.required;
    if (!IdentityRules.isAdult(dob, DateTime.now())) return IdentityStrings.underAge;
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    final dobError = _validateDob();
    final missing = _photos.values.any((s) => s.url == null);
    setState(() {
      _dobError = dobError;
      _photoError = missing ? IdentityStrings.missingPhoto : null;
    });
    if (!formOk || dobError != null || missing || _photos.values.any((s) => s.uploading)) return;

    setState(() => _submitting = true);
    try {
      final result = await AppRepositories.identity.submit(IdentitySubmission(
        fullName: _name.text,
        idNumber: _idNumber.text,
        dateOfBirth: _dob!,
        address: _address.text,
        idFrontImageUrl: _photos[IdentityPhoto.idFront]!.url!,
        idBackImageUrl: _photos[IdentityPhoto.idBack]!.url!,
        selfieImageUrl: _photos[IdentityPhoto.selfie]!.url!,
      ));
      if (!mounted) return;
      setState(() {
        _current = result;
        _submitted = true;
      });
      _snack(IdentityStrings.submitted);
    } on IdentityException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _submitted);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(
            IdentityStrings.title,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                          TextButton(onPressed: _load, child: const Text(IdentityStrings.retry)),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _statusCard(),
                      if (_showForm) ...[const SizedBox(height: 16), _form()],
                    ],
                  ),
        bottomNavigationBar: !_loading && _loadError == null && _showForm
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _current == null ? IdentityStrings.submit : IdentityStrings.resubmit,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _statusCard() {
    final c = _current;
    final (IconData icon, Color color, String title, String note) = switch (c?.status) {
      null => (Icons.shield_outlined, AppColors.textSecondary, IdentityStrings.statusNone, IdentityStrings.intro),
      IdentityStatus.pending => (Icons.hourglass_top, AppColors.tagOrangeText, IdentityStrings.statusPending, IdentityStrings.pendingNote),
      IdentityStatus.approved => (Icons.verified, AppColors.primaryGreen, IdentityStrings.statusApproved, IdentityStrings.approvedNote),
      IdentityStatus.rejected => (Icons.error_outline, Colors.red, IdentityStrings.statusRejected, IdentityStrings.rejectedNote(c?.rejectReason ?? '')),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c == null ? AppColors.cardBorder : color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4)),
                if (c != null && !c.canResubmit && c.idNumber.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${c.fullName} • ${c.maskedIdNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                if (c?.submittedAt case final at?) ...[
                  const SizedBox(height: 2),
                  Text(
                    IdentityStrings.submittedAt('${Formatters.dayMonth(at)}/${at.year} ${Formatters.time(at)}'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? errorText}) => InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _form() {
    final dob = _dob;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(IdentityStrings.fullName),
            validator: (v) => (v ?? '').trim().isEmpty ? IdentityStrings.required : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _idNumber,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(IdentityRules.idNumberLength),
            ],
            decoration: _decoration(IdentityStrings.idNumber),
            validator: (v) => IdentityRules.isValidIdNumber(v ?? '') ? null : IdentityStrings.invalidIdNumber,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _decoration(IdentityStrings.dateOfBirth, errorText: _dobError).copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              isEmpty: dob == null,
              child: Text(dob == null ? '' : '${Formatters.dayMonth(dob)}/${dob.year}'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: _decoration(IdentityStrings.address)),
          const SizedBox(height: 20),
          const Text(
            IdentityStrings.photosTitle,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          for (final p in IdentityPhoto.values) _photoRow(p),
          if (_photoError != null)
            Text(_photoError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _photoRow(IdentityPhoto photo) {
    final slot = _photos[photo]!;
    final local = slot.localPath;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slot.url != null ? AppColors.primaryGreen : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 54,
              child: local == null
                  ? ColoredBox(color: AppColors.lightGreen, child: Icon(photo.icon, color: AppColors.primaryGreen))
                  : Image.file(
                      File(local),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: AppColors.lightGreen, child: Icon(photo.icon, color: AppColors.primaryGreen)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Tên ảnh + nút chụp xếp dọc: máy hẹp / chữ to không tràn ngang.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        photo.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain),
                      ),
                    ),
                    if (slot.url != null && !slot.uploading) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen),
                    ],
                  ],
                ),
                if (slot.uploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(IdentityStrings.uploading, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _pick(photo),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(local == null ? IdentityStrings.takePhoto : IdentityStrings.retake),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
