class Formatters {
  Formatters._();

  static final RegExp _thousands = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

  static const List<String> _weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

  /// 1500000 -> "1.500.000"
  static String currency(int amount) {
    return amount.toString().replaceAllMapped(_thousands, (m) => '${m[1]}.');
  }

  /// 1500000 -> "1.500.000 đ"
  static String vnd(int amount) => '${currency(amount)} đ';

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "18:30"
  static String time(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  /// "18:00 - 19:30"
  static String timeRange(DateTime start, DateTime end) => '${time(start)} - ${time(end)}';

  /// "Thứ 4"
  static String weekday(DateTime dt) => _weekdays[dt.weekday - 1];

  /// "15/10"
  static String dayMonth(DateTime dt) => '${_two(dt.day)}/${_two(dt.month)}';

  /// "Thứ 4, 15/10"
  static String weekdayDayMonth(DateTime dt) => '${weekday(dt)}, ${dayMonth(dt)}';
}
