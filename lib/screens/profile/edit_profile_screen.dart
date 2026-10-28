import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings/profile_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/profile/profile_actions.dart';
import '../../widgets/profile/user_avatar.dart';

enum _AvatarAction { camera, gallery, remove }

/// Sửa hồ sơ: đổi ảnh đại diện và họ tên. Tên đăng nhập / SĐT / email chỉ xem (BE chưa cho đổi).
/// Cuối màn có nút xóa tài khoản.
class EditProfileScreen extends StatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.fullName);
  late AppUser _user = widget.user;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final error = Validators.required(value);
    if (error != null) return error;
    if (value!.trim().length > 100) return ProfileStrings.nameTooLong;
    return null;
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim() == _user.fullName) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      _user = await AppRepositories.auth.updateFullName(_nameController.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showProfileError(context, e.message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(ProfileStrings.saved)));
    Navigator.pop(context);
  }

  Future<void> _changeAvatar() async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(ProfileStrings.takePhoto),
              onTap: () => Navigator.pop(sheetContext, _AvatarAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(ProfileStrings.fromGallery),
              onTap: () => Navigator.pop(sheetContext, _AvatarAction.gallery),
            ),
            if (_user.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(ProfileStrings.removeAvatar, style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(sheetContext, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == _AvatarAction.remove) {
      await _runAvatar(AppRepositories.auth.removeAvatar, ProfileStrings.avatarRemoved);
      return;
    }

    final XFile? picked;
    try {
      // Nén nhẹ để ảnh luôn dưới giới hạn 5MB của BE (image_picker xuất JPEG khi có imageQuality).
      picked = await ImagePicker().pickImage(
        source: action == _AvatarAction.camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (_) {
      if (mounted) showProfileError(context, ProfileStrings.pickPhotoError);
      return;
    }
    if (picked == null || !mounted) return;
    await _runAvatar(() => AppRepositories.auth.uploadAvatar(picked!.path), ProfileStrings.avatarUpdated);
  }

  Future<void> _runAvatar(Future<AppUser> Function() request, String successMessage) async {
    setState(() => _uploading = true);
    try {
      final updated = await request();
      if (!mounted) return;
      setState(() {
        _user = updated;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showProfileError(context, e.message);
    }
  }

  Future<void> _deleteAccount() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ProfileStrings.deleteWarningTitle),
        content: const Text(ProfileStrings.deleteWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(ProfileStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(ProfileStrings.deleteContinue, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(requirePassword: _user.hasPassword),
    );
    if (deleted == true && mounted) goToLogin(context, ProfileStrings.deleted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(ProfileStrings.editTitle, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildAvatar()),
              const SizedBox(height: 24),
              AuthTextField(
                label: ProfileStrings.fullNameLabel,
                hint: ProfileStrings.fullNameLabel,
                controller: _nameController,
                validator: _validateName,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
                onFieldSubmitted: (_) => _saveName(),
              ),
              const SizedBox(height: 16),
              _readOnly(ProfileStrings.usernameLabel, _user.username, Icons.alternate_email),
              _readOnly(ProfileStrings.phoneLabel, _user.phone, Icons.phone_outlined),
              _readOnly(ProfileStrings.emailLabel, _user.email, Icons.email_outlined),
              const Text(
                ProfileStrings.lockedFieldsNote,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: ProfileStrings.save,
                isLoading: _saving,
                trailingIcon: null,
                onPressed: _saveName,
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton.icon(
                  onPressed: _saving || _uploading ? null : _deleteAccount,
                  icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                  label: const Text(ProfileStrings.deleteAccount, style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        Stack(
          children: [
            UserAvatar(user: _user, radius: 48),
            if (_uploading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: AppColors.primaryGreen,
                shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
                child: IconButton(
                  tooltip: ProfileStrings.changeAvatar,
                  icon: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
                  onPressed: _uploading ? null : _changeAvatar,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(ProfileStrings.avatarRule, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _readOnly(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.divider,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

/// Hộp xác nhận cuối: nhập mật khẩu (+ lý do) rồi gọi BE. Tự giữ controller; pop `true` khi đã xóa.
/// Tài khoản Google / Facebook chưa có mật khẩu ([requirePassword] = false) thì chỉ hỏi lý do.
class _DeleteAccountDialog extends StatefulWidget {
  final bool requirePassword;

  const _DeleteAccountDialog({required this.requirePassword});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _obscured = true;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (widget.requirePassword && _passwordController.text.isEmpty) {
      setState(() => _error = Validators.required(''));
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await AppRepositories.auth.deleteAccount(
        password: widget.requirePassword ? _passwordController.text : null,
        reason: _reasonController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(ProfileStrings.deleteConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.requirePassword) ...[
              TextField(
                controller: _passwordController,
                obscureText: _obscured,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: ProfileStrings.deletePasswordLabel,
                  suffixIcon: IconButton(
                    icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _reasonController,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(labelText: ProfileStrings.deleteReasonLabel),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context, false),
          child: const Text(ProfileStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _deleting ? null : _delete,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: _deleting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text(ProfileStrings.deleteButton),
        ),
      ],
    );
  }
}
