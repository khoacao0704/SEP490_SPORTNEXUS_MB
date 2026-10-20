import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/strings/auth_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import 'reset_password_screen.dart';

/// Xác thực OTP 6 số, dùng chung cho đăng ký và quên mật khẩu.
/// Pop về `true` khi toàn bộ luồng (kể cả đặt lại mật khẩu) hoàn tất.
class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final OtpPurpose purpose;

  /// Mã OTP máy chủ thử nghiệm trả về (chưa có SMS thật); `null` thì không hiện.
  final String? devOtp;

  const OtpVerificationScreen({super.key, required this.phone, required this.purpose, this.devOtp});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;
  static const int _resendCooldownSeconds = 60;

  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  Timer? _resendTimer;
  int _resendSecondsLeft = _resendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _devOtp;

  @override
  void initState() {
    super.initState();
    _devOtp = widget.devOtp;
    _startResendCooldown();
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
      }
      setState(() => _resendSecondsLeft--);
    });
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      final devOtp = await AppRepositories.auth.resendOtp(widget.phone, widget.purpose);
      if (!mounted) return;
      _devOtp = devOtp;
      _otpController.clear();
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AuthStrings.otpResent)));
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text;
    if (otp.length != _otpLength) {
      showAuthError(context, AuthStrings.otpIncomplete);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      if (widget.purpose == OtpPurpose.register) {
        await AppRepositories.auth.verifyRegisterOtp(widget.phone, otp);
        if (mounted) Navigator.pop(context, true);
      } else {
        final token = await AppRepositories.auth.verifyResetOtp(widget.phone, otp);
        if (!mounted) return;
        setState(() => _isVerifying = false);
        final done = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(phone: widget.phone, resetToken: token),
          ),
        );
        if (done == true && mounted) Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _otpController.clear();
      showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScaffold(
      title: AuthStrings.otpTitle,
      subtitle: AuthStrings.otpSubtitle(widget.phone),
      icon: Icons.sms_outlined,
      showBackButton: true,
      child: Column(
        children: [
          _buildOtpInput(),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: AuthStrings.otpVerifyButton,
            isLoading: _isVerifying,
            onPressed: _handleVerify,
            trailingIcon: null,
          ),
          const SizedBox(height: 20),
          _buildResendRow(),
          if (_devOtp != null) ...[
            const SizedBox(height: 12),
            Text(AuthStrings.devOtpHint(_devOtp!), style: const TextStyle(fontSize: 13, color: AppColors.authSubtle)),
          ],
        ],
      ),
    );
  }

  /// Một TextField ẩn nhận bàn phím, 6 ô phía trên chỉ để hiển thị.
  /// Cách này hỗ trợ dán mã và tự điền OTP tốt hơn so với 6 TextField riêng.
  Widget _buildOtpInput() {
    final otp = _otpController.text;

    return GestureDetector(
      onTap: () => _otpFocusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_otpLength),
              ],
              onChanged: (value) {
                if (value.length == _otpLength) _handleVerify();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_otpLength, (index) {
              final isFilled = index < otp.length;
              final isActive = index == otp.length && _otpFocusNode.hasFocus;
              return Container(
                width: 44,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.lightGreen : AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive || isFilled ? AppColors.authPrimary : AppColors.authBorder,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Text(
                  isFilled ? otp[index] : '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.authTitle),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildResendRow() {
    final canResend = _resendSecondsLeft <= 0 && !_isResending;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(AuthStrings.otpNotReceived, style: TextStyle(fontSize: 13, color: AppColors.authSubtle)),
        GestureDetector(
          onTap: canResend ? _handleResend : null,
          child: Text(
            _resendSecondsLeft > 0 ? AuthStrings.otpResendIn(_resendSecondsLeft) : AuthStrings.otpResend,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: canResend ? AppColors.authPrimary : AppColors.authHint,
            ),
          ),
        ),
      ],
    );
  }
}
