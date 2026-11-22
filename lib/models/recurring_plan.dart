import '../core/constants/booking_rules.dart';
import '../core/strings/booking_strings.dart';
import 'time_slot.dart';

/// Lý do một buổi trong lịch lặp lại không đặt được.
enum RecurringIssue {
  /// Khung giờ đó đã có người đặt / đang bảo trì.
  taken,

  /// Sân chưa mở lịch tới ngày đó (BE chỉ sinh khung giờ trước khoảng 35 ngày) hoặc ngày đó không có khung giờ này.
  notOpen,

  /// Ngày đó có ca trùng giờ trên cùng sân con nhưng khác độ dài với ca mẫu (vd. mẫu 60 phút, tuần này đã gộp
  /// thành ca 120 phút) → BE không nhận vào cùng gói.
  lengthMismatch,
}

/// Một ngày trong lịch lặp lại: các khung cùng sân con, cùng giờ với các khung người chơi chọn ở ngày bắt đầu.
class RecurringSession {
  final DateTime date;

  /// Các khung của ngày này, cùng thứ tự với khung mẫu (rỗng khi [issue] khác null).
  final List<TimeSlot> slots;
  final RecurringIssue? issue;

  const RecurringSession({required this.date, this.slots = const [], this.issue});

  bool get isOk => issue == null;

  int get price => slots.fold(0, (sum, s) => sum + s.price);
}

/// Lịch đặt lặp lại: người chơi chọn các khung giờ trên 1 sân con ở ngày bắt đầu, các thứ trong tuần và số tuần
/// (tính từ ngày bắt đầu). Mỗi khung mỗi ngày là một lượt đặt: T3 slot 5 + 6 × 4 tuần = 8 lượt; thêm T5 = 16 lượt.
/// Chọn khung trên nhiều sân con thì không đặt lặp lại được (UI khóa), chỉ đặt thường.
///
/// BE chỉ nhận một gói khi các buổi cùng sân con, cùng thứ, cách nhau đúng 7 ngày → app tách thành nhiều gói
/// ([packages]): mỗi thứ × mỗi sân con × mỗi cụm khung liền nhau là một gói, đặt cùng một lần thanh toán.
class RecurringPlan {
  /// Các ngày của lịch, sắp theo ngày.
  final List<RecurringSession> sessions;

  /// Chỉ số cụm khung liền nhau (trên cùng một sân con) của từng khung mẫu: khung 5, 6 Sân 1 cùng cụm;
  /// khung 8 Sân 1 hoặc khung 5 Sân 2 là cụm khác.
  final List<int> _blockOf;

  const RecurringPlan(this.sessions, {this._blockOf = const []});

  /// Mọi buổi đều đặt được (BE không cho bỏ tuần).
  bool get isComplete => sessions.isNotEmpty && sessions.every((s) => s.isOk);

  List<RecurringSession> get problems => sessions.where((s) => !s.isOk).toList();

  /// Toàn bộ khung giờ (mỗi khung = một lượt đặt), sắp theo giờ.
  List<TimeSlot> get slots => [for (final s in sessions) ...s.slots]..sort((a, b) => a.start.compareTo(b.start));

  int get originalTotal => sessions.fold(0, (sum, s) => sum + s.price);

  /// Các gói gửi BE: gom theo (thứ trong tuần, cụm khung liền nhau của một sân con), mỗi gói sắp theo giờ.
  List<List<TimeSlot>> get packages {
    final groups = <(int, int), List<TimeSlot>>{};
    for (final s in sessions) {
      for (var i = 0; i < s.slots.length; i++) {
        final block = i < _blockOf.length ? _blockOf[i] : 0;
        (groups[(s.date.weekday, block)] ??= []).add(s.slots[i]);
      }
    }
    final keys = groups.keys.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final k in keys) groups[k]!..sort((a, b) => a.start.compareTo(b.start))];
  }

  /// Các khung đã chọn làm được mẫu lặp lại: cùng một ngày (ngày bắt đầu) và cùng MỘT sân con.
  static bool isValidPattern(List<TimeSlot> selected) =>
      selected.isNotEmpty && isSameDay(selected) && courtCount(selected) == 1;

  /// Mọi khung cùng một ngày.
  static bool isSameDay(List<TimeSlot> slots) => slots.every((s) => _sameDay(s.start, slots.first.start));

  /// Số sân con trong mẫu.
  static int courtCount(List<TimeSlot> pattern) => pattern.map((s) => s.courtName).toSet().length;

  /// Mẫu sắp theo sân con rồi theo giờ (thứ tự dùng cho [RecurringSession.slots] và cụm khung).
  static List<TimeSlot> sortPattern(List<TimeSlot> pattern) => [...pattern]
    ..sort((a, b) => a.courtName != b.courtName ? a.courtName.compareTo(b.courtName) : a.start.compareTo(b.start));

  /// Các ngày thuộc [weekdays] (1 = T2 … 7 = CN) trong [weeks] tuần tính từ [start] (gồm cả ngày [start]).
  static List<DateTime> datesFor(DateTime start, Set<int> weekdays, int weeks) {
    final day = _dayOf(start);
    return [
      for (var i = 0; i < RecurringBookingRules.interval.inDays * weeks; i++)
        if (weekdays.contains(DateTime(day.year, day.month, day.day + i).weekday)) DateTime(day.year, day.month, day.day + i),
    ];
  }

  /// Dò mọi ngày của lịch bằng [loadDay] (khung giờ mọi sân con của một ngày). Ngày tải lỗi được coi là chưa mở lịch.
  static Future<RecurringPlan> build({
    required List<TimeSlot> pattern,
    required Set<int> weekdays,
    required int weeks,
    required Future<List<TimeSlot>> Function(DateTime date) loadDay,
    required DateTime now,
  }) async {
    final sorted = sortPattern(pattern);
    final base = sorted.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final blockOf = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      final continues = i > 0 && sorted[i].courtName == sorted[i - 1].courtName && sorted[i].start == sorted[i - 1].end;
      blockOf.add(i == 0 ? 0 : (continues ? blockOf[i - 1] : blockOf[i - 1] + 1));
    }

    final sessions = <RecurringSession>[];
    for (final date in datesFor(base, weekdays, weeks)) {
      List<TimeSlot> day;
      try {
        day = await loadDay(date);
      } catch (_) {
        day = const [];
      }
      final matched = <TimeSlot>[];
      RecurringIssue? issue;
      for (final s in sorted) {
        final start = _at(date, base, s.start);
        final end = _at(date, base, s.end);
        final found = day.where((d) => d.courtName == s.courtName && d.start == start && d.end == end).firstOrNull;
        if (found == null) {
          final overlaps = day.any((d) => d.courtName == s.courtName && d.start.isBefore(end) && d.end.isAfter(start));
          issue = overlaps ? RecurringIssue.lengthMismatch : RecurringIssue.notOpen;
          break;
        }
        if (!found.isBookable(now)) issue ??= RecurringIssue.taken;
        matched.add(found);
      }
      sessions.add(issue == null
          ? RecurringSession(date: date, slots: matched)
          : RecurringSession(date: date, issue: issue));
    }
    return RecurringPlan(sessions, blockOf: blockOf);
  }

  /// Lý do các khung của MỘT gói không thành gói định kỳ theo luật BE (`null` = thành gói): ≥4 buổi, cùng sân con,
  /// cùng độ dài, buổi sau cách buổi trước đúng 7 ngày. Các ca liền nhau cùng ngày, cùng sân tính là một buổi.
  /// BE chưa có API xem trước → app tự kiểm; lỗi từ POST /bookings vẫn là lớp chặn cuối.
  static String? packageError(List<TimeSlot> slots) {
    final sorted = [...slots]..sort((a, b) => a.start.compareTo(b.start));
    final sessions = <List<TimeSlot>>[];
    for (final s in sorted) {
      final last = sessions.lastOrNull;
      if (last != null && last.last.end == s.start && last.last.courtName == s.courtName) {
        last.add(s);
      } else {
        sessions.add([s]);
      }
    }
    if (sessions.length < RecurringBookingRules.minSessions) return BookingStrings.packageTooFew;
    final first = sessions.first;
    final length = first.last.end.difference(first.first.start);
    for (var i = 1; i < sessions.length; i++) {
      final s = sessions[i];
      if (s.first.courtName != first.first.courtName) return BookingStrings.packageSameCourt;
      if (s.last.end.difference(s.first.start) != length) return BookingStrings.packageSameLength;
      if (s.first.start.difference(sessions[i - 1].first.start) != RecurringBookingRules.interval) {
        return BookingStrings.packageWeekly;
      }
    }
    return null;
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Cùng giờ:phút với [time] nhưng ở ngày [date]; [time] khác ngày [base] (khung kết thúc lúc 0:00) thì lệch ngày tương ứng.
  static DateTime _at(DateTime date, DateTime base, DateTime time) => DateTime(
      date.year, date.month, date.day + _dayOf(time).difference(_dayOf(base)).inDays, time.hour, time.minute);

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Thông tin lịch lặp lại chuyển sang màn Thanh toán.
class RecurringCheckout {
  /// Tổng số lượt đặt (mỗi khung mỗi ngày).
  final int sessions;
  final int discountPercent;

  /// "T3, T5 • Sân 2 • 09:00 - 11:00".
  final String summary;

  /// Các gói gửi BE lần lượt (xem [RecurringPlan.packages]).
  final List<List<TimeSlot>> packages;

  /// Từng ngày của lịch (khung đã thay bằng bản mới nhất trong lượt giữ chỗ) để màn Thanh toán liệt kê ✔ / ❌.
  final List<RecurringSession> days;

  const RecurringCheckout({
    required this.sessions,
    required this.discountPercent,
    required this.summary,
    required this.packages,
    this.days = const [],
  });

  /// Lý do (không trùng) khiến lịch không thành gói: có ngày không đặt được, hoặc một gói sai luật BE.
  /// Rỗng = đủ điều kiện thành gói (được giảm giá).
  List<String> get problems => {
        if (days.any((d) => !d.isOk)) BookingStrings.recurringHasBadDay,
        for (final p in packages) ?RecurringPlan.packageError(p),
      }.toList();

  /// Id các khung thuộc gói sai luật (để đánh ❌ đúng ngày).
  Set<String> get badSlotIds => {
        for (final p in packages)
          if (RecurringPlan.packageError(p) != null) ...p.map((s) => s.id),
      };
}
