import 'package:flutter/services.dart';

import 'formatters.dart';

/// Ô nhập tiền: chỉ nhận chữ số, tự thêm dấu chấm hàng nghìn ("1500000" -> "1.500.000").
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = Formatters.currency(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// "1.500.000" -> 1500000; rỗng -> 0.
  static int parse(String text) => int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;
}
