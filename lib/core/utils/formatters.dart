class Formatters {
  Formatters._();

  static final RegExp _thousands = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

  /// 1500000 -> "1.500.000"
  static String currency(int amount) {
    return amount.toString().replaceAllMapped(_thousands, (m) => '${m[1]}.');
  }
}
