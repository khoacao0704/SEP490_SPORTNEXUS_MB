import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings/profile_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/session_store.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/profile/profile_actions.dart';
import '../../widgets/profile/user_avatar.dart';
import 'change_phone_screen.dart';

enum _AvatarAction { camera, gallery, remove }

/// Sửa hồ sơ: ảnh đại diện, họ tên, tên đăng nhập, giới thiệu; đổi SĐT qua màn riêng (xác thực SMS).
/// Email chỉ xem. Cuối màn có nút xóa tài khoản.
class EditProfileScreen extends StatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.fullName);
  late final _usernameController = TextEditingController(text: widget.user.username);
  late final _bioController = TextEditingController(text: widget.user.bio);
  late AppUser _user = widget.user;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _changePhone() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ChangePhoneScreen(currentPhone: _user.phone)),
    );
    if (changed != true || !mounted) return;
    final user = await SessionStore.readUser();
    if (!mounted) return;
    if (user != null) setState(() => _user = user);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(ProfileStrings.phoneChanged)));
  }

  String? _validateName(String? value) {
    final error = Validators.required(value);
    if (error != null) return error;
    if (value!.trim().length > 100) return ProfileStrings.nameTooLong;
    return null;
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim() == _user.fullName &&
        _usernameController.text.trim() == _user.username &&
        _bioController.text.trim() == _user.bio) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      _user = await AppRepositories.auth.updateProfile(
        fullName: _nameController.text,
        username: _usernameController.text,
        bio: _bioController.text,
      );
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
      // BE có thể ghi đè ảnh cùng URL: xóa bản cũ trong bộ nhớ đệm để ảnh mới hiện ngay.
      final url = updated.avatarUrl;
      if (url != null && url.startsWith('http')) await NetworkImage(url).evict();
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
    } catch (e) {
      // Lỗi ngoài dự kiến (đọc file, dữ liệu BE lạ...): không để vòng xoay quay mãi.
      debugPrint('[EditProfile] avatar error: $e');
      if (!mounted) return;
      setState(() => _uploading = false);
      showProfileError(context, ProfileStrings.avatarUploadFailed);
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: ProfileStrings.usernameLabel,
                hint: ProfileStrings.usernameLabel,
                controller: _usernameController,
                validator: Validators.username,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(ProfileStrings.usernameNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                maxLength: ProfileStrings.bioMaxLength,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: ProfileStrings.bioLabel,
                  hintText: ProfileStrings.bioHint,
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              _readOnly(
                ProfileStrings.phoneLabel,
                _user.phone,
                Icons.phone_outlined,
                action: TextButton(
                  onPressed: _saving || _uploading ? null : _changePhone,
                  child: const Text(ProfileStrings.changePhone),
                ),
              ),
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

  Widget _readOnly(String label, String value, IconData icon, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          suffixIcon: action,
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
