import 'dart:math' as math;

import '../../models/match_scoring.dart';
import '../../models/organized_tournament.dart';
import '../../models/tournament_management.dart';

/// Luật tạo / sửa giải (theo tournamentRules.js của Web, luồng 26/11). Không có chế độ test.
class TournamentRules {
  TournamentRules._();

  /// Hạn đăng ký trước ngày bắt đầu ít nhất 48 giờ (ngày trơn → 2 ngày).
  static const int deadlineGapDays = 2;

  /// Giải kéo dài tối đa 1 tháng kể từ ngày bắt đầu.
  static const int maxDurationMonths = 1;

  /// Số người / đội tối thiểu cố định.
  static const int minParticipants = 4;

  /// BTC tự hủy được tới 24 giờ trước hạn đăng ký.
  static const Duration cancelLock = Duration(hours: 24);

  /// Fair Play tối thiểu để người chơi tổ chức giải.
  static const int organizerMinFairPlay = 90;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Cộng tháng, ngày cuối tháng được kẹp lại (31/01 + 1 tháng = 28/02 hoặc 29/02).
  static DateTime addMonths(DateTime d, int months) {
    final lastDay = DateTime(d.year, d.month + months + 1, 0).day;
    return DateTime(d.year, d.month + months, math.min(d.day, lastDay));
  }

  static DateTime minStart(DateTime today) => _day(today).add(const Duration(days: deadlineGapDays));
  static DateTime maxEnd(DateTime start) => addMonths(_day(start), maxDurationMonths);
  static DateTime maxDeadline(DateTime start) => _day(start).subtract(const Duration(days: deadlineGapDays));

  /// Hạn đăng ký mặc định: đúng 48 giờ trước ngày bắt đầu.
  static DateTime defaultDeadline(DateTime start) => maxDeadline(start);

  /// Câu lỗi đầu tiên, hoặc null nếu hợp lệ.
  /// [changed]: khi sửa giải, luật mới chỉ áp cho ô vừa đổi; thứ tự ngày luôn kiểm tra.
  static String? validateDates({
    DateTime? start,
    DateTime? end,
    DateTime? deadline,
    required DateTime today,
    bool requireDates = true,
    Set<String>? changed,
  }) {
    bool isChanged(List<String> keys) => changed == null || keys.any(changed.contains);
    final t = _day(today);
    if (requireDates && (start == null || end == null)) return 'Vui lòng chọn ngày bắt đầu và ngày kết thúc.';
    final s = start == null ? null : _day(start);
    final e = end == null ? null : _day(end);
    final d = deadline == null ? null : _day(deadline);
    if (s != null && isChanged(['start']) && s.isBefore(minStart(t))) {
      return 'Ngày bắt đầu phải cách hôm nay ít nhất 2 ngày (để còn 48 giờ cho hạn đăng ký).';
    }
    if (e != null && isChanged(['end']) && e.isBefore(t)) return 'Ngày kết thúc không được ở quá khứ.';
    if (s != null && e != null && e.isBefore(s)) return 'Ngày kết thúc phải từ ngày bắt đầu trở đi.';
    if (s != null && e != null && isChanged(['start', 'end']) && e.isAfter(maxEnd(s))) {
      return 'Giải kéo dài tối đa 1 tháng kể từ ngày bắt đầu.';
    }
    if (d != null && isChanged(['deadline']) && d.isBefore(t)) return 'Hạn đăng ký không được ở quá khứ.';
    if (d != null && s != null && d.isAfter(s)) return 'Hạn đăng ký phải trước ngày bắt đầu.';
    if (d != null && s != null && isChanged(['start', 'deadline']) && d.isAfter(maxDeadline(s))) {
      return 'Hạn đăng ký phải trước ngày bắt đầu ít nhất 48 giờ.';
    }
    return null;
  }

  // ---------- Thể thức ----------

  /// Gợi ý: đến 8 đấu thủ loại trực tiếp, từ 9 vòng bảng rồi loại trực tiếp.
  static BracketFormat suggestFormat(int count) => count >= 9 ? BracketFormat.groupKnockout : BracketFormat.knockout;

  static String? formatError(BracketFormat format, int count) {
    final max = format.maxCount;
    if (max != null && count > max) return '${format.label} chỉ cho tối đa $max đấu thủ.';
    if (count < format.minCount) return '${format.label} cần ít nhất ${format.minCount} đấu thủ.';
    return null;
  }

  /// Số trận ước tính (chưa tính tranh hạng 3), như Web.
  static int estimateMatches(BracketFormat format, int n) {
    if (n < 2) return 0;
    switch (format) {
      case BracketFormat.roundRobin:
        return n * (n - 1) ~/ 2;
      case BracketFormat.groupKnockout:
        final groups = (n / 4).ceil();
        final base = n ~/ groups;
        final bigger = n % groups;
        int pairs(int k) => k * (k - 1) ~/ 2;
        final groupMatches = bigger * pairs(base + 1) + (groups - bigger) * pairs(base);
        var power = 1;
        while (power * 2 <= 2 * groups) {
          power *= 2;
        }
        return groupMatches + power - 1;
      case BracketFormat.knockout:
        return n - 1;
    }
  }

  /// Cảnh báo khi thể thức không hợp với số đấu thủ (null = không có gì).
  static String? formatWarning(BracketFormat format, int n) {
    if (n < 2) return null;
    if (format == BracketFormat.roundRobin && n > 6) {
      return 'Vòng tròn với $n đấu thủ là ${estimateMatches(format, n)} trận, quá nhiều cho một giải.';
    }
    if (format == BracketFormat.groupKnockout && n < 9) {
      return 'Dưới 9 đấu thủ nên chọn loại trực tiếp; chia bảng sẽ có bảng quá ít người.';
    }
    if (format == BracketFormat.knockout && n >= 9) {
      return 'Từ 9 đấu thủ, loại trực tiếp làm một nửa số người chỉ đấu 1 trận; nên chọn vòng bảng + loại trực tiếp.';
    }
    return null;
  }

  // ---------- Lịch sân yêu cầu ----------

  static String _show(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String? validateSchedule(List<CourtScheduleRequest> rows, {DateTime? start, DateTime? end}) {
    if (rows.isEmpty) return null;
    if (start == null) return 'Chọn ngày bắt đầu trước khi nhập lịch sân.';
    final first = _day(start);
    final last = _day(end ?? start);
    final seen = <CourtScheduleRequest>[];
    for (final row in rows) {
      final date = row.date;
      if (date == null) return 'Chọn ngày cho từng dòng lịch sân.';
      final d = _day(date);
      if (d.isBefore(first) || d.isAfter(last)) return 'Ngày ${_show(d)} nằm ngoài thời gian diễn ra giải.';
      if (row.courtCount < 1) return 'Số sân mỗi dòng phải từ 1 trở lên.';
      final clash = seen.any(
        (o) =>
            _day(o.date!) == d &&
            (o.session == row.session || o.session == CourtSession.fullDay || row.session == CourtSession.fullDay),
      );
      if (clash) return 'Ngày ${_show(d)} bị trùng buổi.';
      seen.add(row);
    }
    return null;
  }

  // ---------- Hủy giải / điều kiện BTC ----------

  /// BTC tự hủy được tới 24 giờ trước hạn đăng ký; không có hạn thì không chặn.
  static bool canOrganizerCancel(DateTime? deadline, DateTime now) =>
      deadline == null || now.isBefore(deadline.subtract(cancelLock));

  /// Chưa biết điểm thì không chặn (để BE quyết).
  static String? fairPlayBlock(int? score) {
    if (score == null || score >= organizerMinFairPlay) return null;
    return 'Cần điểm Fair Play từ $organizerMinFairPlay để tổ chức giải (hiện tại $score).';
  }

  // ---------- Chọn cơ sở: gõ không dấu ----------

  static String fold(String text) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final lower = text.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }

  /// Mọi từ gõ vào đều phải có trong tên / địa chỉ (không dấu, không theo thứ tự). Tên khớp đầu chuỗi lên trước.
  static List<FacilityOption> matchFacilities(List<FacilityOption> all, String query) {
    final q = fold(query).trim();
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return all;
    final hits = all.where((f) {
      final text = fold('${f.name} ${f.address}');
      return words.every(text.contains);
    }).toList();
    int rank(FacilityOption f) => fold(f.name).startsWith(q) ? 0 : 1;
    hits.sort((a, b) => rank(a).compareTo(rank(b)));
    return hits;
  }

  // ---------- Điểm danh trước khi thi đấu (nhóm chốt 24/11) ----------

  /// Trận chưa có kết quả: cả hai bên đã điểm danh → nhập bình thường; thiếu một bên → chỉ xử thắng cho bên có mặt;
  /// thiếu cả hai → không lưu được. Tìm theo id người tham gia, thiếu id thì theo tên. Chưa có danh sách → null (để BE quyết).
  static CheckInGate? checkInGate(List<MatchSide> sides, List<OrganizerParticipant>? participants) {
    if (participants == null || participants.isEmpty) return null;
    OrganizerParticipant? find(MatchSide s) => participants
        .where((p) => s.id.isNotEmpty ? p.participantId == s.id : p.displayName == s.name)
        .firstOrNull;
    final present = [for (final s in sides) if (find(s)?.isCheckedIn == true) s];
    final absent = [for (final s in sides) if (find(s)?.isCheckedIn != true) s];
    if (absent.isEmpty) return CheckInGate(mode: CheckInGateMode.ok, present: present);
    return CheckInGate(
      mode: present.isEmpty ? CheckInGateMode.blocked : CheckInGateMode.walkoverOnly,
      present: present,
      absent: absent,
    );
  }

  // ---------- Tỉ số (PUT /matches/{id}/score, dùng lại khi xử lý khiếu nại) ----------

  static const int maxSets = 5;

  /// [sets]: các cặp chuỗi từ ô nhập; [tiebreak]: luân lưu (để trống nếu không có).
  /// Trả về (body, null) hoặc (null, câu lỗi), như buildScorePayload của Web.
  static (Map<String, dynamic>?, String?) buildScorePayload({
    required ScoreKind kind,
    required List<(String, String)> sets,
    String? winnerId,
    (String, String) tiebreak = ('', ''),
  }) {
    final filled = <Map<String, dynamic>>[];
    for (final (a, b) in sets) {
      if (a.trim().isEmpty && b.trim().isEmpty) continue;
      final pa = int.tryParse(a.trim()) ?? 0;
      final pb = int.tryParse(b.trim()) ?? 0;
      if (pa < 0 || pb < 0) return (null, 'Tỉ số không được âm.');
      filled.add({'setNumber': filled.length + 1, 'scoreP1': pa, 'scoreP2': pb});
    }
    final body = <String, dynamic>{
      'sets': <Map<String, dynamic>>[],
      'winnerId': null,
      'tiebreakP1': null,
      'tiebreakP2': null,
      'resultType': kind.apiValue,
    };
    final hasWinner = winnerId != null && winnerId.isNotEmpty;
    if (kind == ScoreKind.walkover) {
      if (!hasWinner) return (null, 'Chọn bên được xử thắng.');
      return ({...body, 'winnerId': winnerId}, null);
    }
    if (filled.isEmpty) return (null, 'Nhập tỉ số ít nhất 1 hiệp.');
    body['sets'] = filled;
    if (kind == ScoreKind.retired) {
      if (!hasWinner) return (null, 'Chọn bên thắng (bên còn lại bỏ cuộc).');
      return ({...body, 'winnerId': winnerId}, null);
    }
    final (ta, tb) = tiebreak;
    if (ta.trim().isNotEmpty || tb.trim().isNotEmpty) {
      final a = int.tryParse(ta.trim());
      final b = int.tryParse(tb.trim());
      if (a == null || b == null || a == b) return (null, 'Tỉ số luân lưu phải đủ hai bên và không bằng nhau.');
      body['tiebreakP1'] = a;
      body['tiebreakP2'] = b;
    }
    return (body, null);
  }
}
