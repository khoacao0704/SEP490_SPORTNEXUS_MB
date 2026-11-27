/// Loại vé đã check-in (GET /checkin/history?type=).
enum CheckInTicketType {
  booking('BOOKING', 'Vé đặt sân'),
  lfg('LFG', 'Vé kèo LFG'),
  tournament('TOURNAMENT', 'Vé giải đấu');

  const CheckInTicketType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CheckInTicketType? fromApi(Object? v) {
    final key = '${v ?? ''}'.toUpperCase();
    return values.where((t) => t.apiValue == key).firstOrNull;
  }
}

/// Một lượt check-in của tôi (lịch sử check-in của Web).
class CheckInRecord {
  final String id;

  /// `null` khi BE trả loại app chưa biết ([rawType] giữ nguyên để hiện).
  final CheckInTicketType? type;
  final String rawType;
  final DateTime checkedInAt;
  final String? facilityName;
  final String? courtName;
  final String? sportName;
  final DateTime? start;
  final DateTime? end;
  final String? tournamentName;
  final bool isLate;

  const CheckInRecord({
    required this.id,
    required this.type,
    required this.rawType,
    required this.checkedInAt,
    this.facilityName,
    this.courtName,
    this.sportName,
    this.start,
    this.end,
    this.tournamentName,
    this.isLate = false,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> j) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    DateTime? time(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    return CheckInRecord(
      id: str(j['id']) ?? '',
      type: CheckInTicketType.fromApi(j['type']),
      rawType: str(j['type']) ?? '',
      checkedInAt: time(j['checkedInAt']) ?? DateTime.now(),
      facilityName: str(j['facilityName']),
      courtName: str(j['courtName']),
      sportName: str(j['sportName']),
      start: time(j['startTime']),
      end: time(j['endTime']),
      tournamentName: str(j['tournamentName']),
      isLate: j['isLate'] == true,
    );
  }
}

/// Một trang lịch sử check-in.
class CheckInHistoryPage {
  final List<CheckInRecord> items;
  final int totalItems;

  const CheckInHistoryPage({required this.items, required this.totalItems});
}
