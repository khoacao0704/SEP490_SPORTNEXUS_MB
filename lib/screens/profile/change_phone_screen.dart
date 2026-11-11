import 'package:flutter/material.dart';

import '../../core/strings/profile_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/api/api_auth_repository.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/profile/profile_actions.dart';
import '../auth/otp_verification_screen.dart';

/// Đổi sang SĐT mới: gửi SMS xác thực (Firebase) → nhập mã → POST /auth/me/phone. Pop `true` khi đã đổi.
class ChangePhoneScreen extends StatefulWidget {
  final String currentPhone;

  const ChangePhoneScreen({super.key, required this.currentPhone});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final error = Validators.phone(value);
    if (error != null) return error;
    final current = widget.currentPhone.trim();
    if (current.isNotEmpty &&
        ApiAuthRepository.normalizePhone(value!) == ApiAuthRepository.normalizePhone(current)) {
      return ProfileStrings.samePhone;
    }
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    setState(() => _sending = true);
    try {
      final devOtp = await AppRepositories.auth.requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() => _sending = false);
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phone: phone, purpose: OtpPurpose.addPhone, devOtp: devOtp),
        ),
      );
      if (verified == true && mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showProfileError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          ProfileStrings.changePhoneTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(ProfileStrings.changePhoneNote, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
              if (widget.currentPhone.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ProfileStrings.currentPhone(widget.currentPhone),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 20),
              AuthTextField(
                label: ProfileStrings.newPhoneLabel,
                hint: ProfileStrings.newPhoneLabel,
                controller: _phoneController,
                validator: _validate,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                onFieldSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(label: ProfileStrings.sendCode, isLoading: _sending, onPressed: _send),
            ],
          ),
        ),
      ),
    );
  }
}
