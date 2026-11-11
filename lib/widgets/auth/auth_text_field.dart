import 'package:flutter/material.dart';
import '../../core/utils/validators.dart';
import '../../theme/app_colors.dart';

/// Ô nhập có nhãn phía trên, dùng cho các form xác thực.
/// [isPassword] = true sẽ ẩn nội dung và hiện nút con mắt.
///
/// Kiểm tra ngay khi người dùng gõ (sau lần gõ đầu tiên): ô sai có viền đỏ + dòng lỗi nhỏ bên dưới.
/// [showPasswordChecklist] = true: hiện danh sách điều kiện mật khẩu, điều kiện nào đạt chuyển xanh.
/// [revalidateOn]: kiểm tra lại ô này khi giá trị khác đổi (vd. ô "Nhập lại mật khẩu" theo ô mật khẩu).
class AuthTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool isPassword;
  final String? helperText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool showPasswordChecklist;
  final Listenable? revalidateOn;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.isPassword = false,
    this.helperText,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.showPasswordChecklist = false,
    this.revalidateOn,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    widget.revalidateOn?.addListener(_revalidate);
  }

  @override
  void didUpdateWidget(AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revalidateOn != widget.revalidateOn) {
      oldWidget.revalidateOn?.removeListener(_revalidate);
      widget.revalidateOn?.addListener(_revalidate);
    }
  }

  @override
  void dispose() {
    widget.revalidateOn?.removeListener(_revalidate);
    super.dispose();
  }

  /// Chỉ kiểm tra lại khi ô đã có chữ, tránh báo lỗi ô người dùng chưa đụng tới.
  void _revalidate() {
    if (widget.controller.text.isNotEmpty) _fieldKey.currentState?.validate();
  }

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.authLabel),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: _fieldKey,
          controller: widget.controller,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword && _obscured,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            // Đã có checklist thì không cần dòng gợi ý trùng nội dung.
            helperText: widget.showPasswordChecklist ? null : widget.helperText,
            helperStyle: const TextStyle(fontSize: 11, color: AppColors.authHint),
            helperMaxLines: 2,
            errorStyle: const TextStyle(fontSize: 11),
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: _border(AppColors.authBorder),
            enabledBorder: _border(AppColors.authBorder),
            focusedBorder: _border(AppColors.authPrimary, 1.5),
            errorBorder: _border(Colors.red),
            focusedErrorBorder: _border(Colors.red, 1.5),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.authSubtle,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
        if (widget.showPasswordChecklist) PasswordChecklist(controller: widget.controller),
      ],
    );
  }
}

/// Danh sách điều kiện mật khẩu ([Validators.passwordRules]); điều kiện đạt chuyển xanh ngay khi gõ.
class PasswordChecklist extends StatelessWidget {
  final TextEditingController controller;

  const PasswordChecklist({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.text;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final rule in Validators.passwordRules)
                _item(rule.label, rule.test(value)),
            ],
          ),
        );
      },
    );
  }

  Widget _item(String label, bool met) {
    final color = met ? AppColors.primaryGreen : AppColors.authHint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: met ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng lỗi ngay dưới form (vd. sai tài khoản / mật khẩu), thay vì chỉ hiện popup.
class AuthInlineError extends StatelessWidget {
  final String message;

  const AuthInlineError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.red, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
