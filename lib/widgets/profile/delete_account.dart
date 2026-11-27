import 'package:flutter/material.dart';

import '../../core/strings/profile_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import 'profile_actions.dart';

/// Xóa tài khoản (mục Bảo mật): cảnh báo → nhập mật khẩu (+ lý do) → về Đăng nhập.
/// [hasPassword] = false (tài khoản Google / Facebook chưa có mật khẩu) thì chỉ hỏi lý do.
Future<void> startDeleteAccount(BuildContext context, {required bool hasPassword}) async {
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
  if (proceed != true || !context.mounted) return;

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteAccountDialog(requirePassword: hasPassword),
  );
  if (deleted == true && context.mounted) goToLogin(context, ProfileStrings.deleted);
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
