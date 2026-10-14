import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Ô nhập có nhãn phía trên, dùng cho các form xác thực.
/// [isPassword] = true sẽ ẩn nội dung và hiện nút con mắt.
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
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

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
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword && _obscured,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onFieldSubmitted,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            helperStyle: const TextStyle(fontSize: 11, color: AppColors.authHint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: _border(AppColors.authBorder),
            enabledBorder: _border(AppColors.authBorder),
            focusedBorder: _border(AppColors.authPrimary, 1.5),
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
      ],
    );
  }
}
