import '../core/constants/owner_rules.dart';

/// Nguồn doanh thu của Chủ sân.
enum RevenueKind {
  /// Tiền sân của lượt đã check-out (gồm phần tự thu tại sân).
  courtFee('CourtFee'),

  /// Tiền phạt người chơi hủy trong 24 giờ hoặc vắng mặt: về chủ sân.
  penalty('Penalty'),

  /// Lệ phí giải đấu Chủ sân tổ chức, giải ngân khi giải kết thúc.
  tournamentFee('TournamentFee');

  const RevenueKind(this.apiValue);

  final String apiValue;

  static RevenueKind fromApi(String value) => values.firstWhere((k) => k.apiValue == value);
}

/// Một khoản doanh thu (BE có thể gộp theo ngày / cơ sở).
class RevenueItem {
  final String id;
  final DateTime date;
  final String facilityId;
  final String facilityName;
  final RevenueKind kind;

  /// Tính vào doanh thu (và vào phí 10%).
  final int amount;

  /// Phần đi qua app, đã giải ngân vào ví Chủ sân. Phần còn lại chủ sân tự thu tại sân.
  final int viaApp;

  /// Số lượt sân gộp trong khoản này.
  final int sessions;
  final String description;

  const RevenueItem({
    required this.id,
    required this.date,
    required this.facilityId,
    required this.facilityName,
    required this.kind,
    required this.amount,
    required this.viaApp,
    this.sessions = 1,
    this.description = '',
  });

  int get atCourt => amount - viaApp;

  factory RevenueItem.fromJson(Map<String, dynamic> json) => RevenueItem(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        facilityId: json['facilityId'] as String,
        facilityName: json['facilityName'] as String,
        kind: RevenueKind.fromApi(json['kind'] as String),
        amount: (json['amount'] as num).toInt(),
        viaApp: (json['viaApp'] as num).toInt(),
        sessions: (json['sessions'] as num?)?.toInt() ?? 1,
        description: json['description'] as String? ?? '',
      );
}

/// Doanh thu một tháng (có thể đã lọc theo cơ sở).
class MonthlyRevenue {
  /// Ngày 1 của tháng.
  final DateTime month;
  final List<RevenueItem> items;

  const MonthlyRevenue({required this.month, required this.items});

  int _sum(int Function(RevenueItem i) f) => items.fold(0, (s, i) => s + f(i));

  int get total => _sum((i) => i.amount);
  int get viaApp => _sum((i) => i.viaApp);
  int get atCourt => _sum((i) => i.atCourt);
  int get penalties => _sum((i) => i.kind == RevenueKind.penalty ? i.amount : 0);
  int get sessions => _sum((i) => i.kind == RevenueKind.courtFee ? i.sessions : 0);

  /// Phí duy trì 10% tính trên doanh thu này.
  int get listingFee => ListingFeeRules.feeFor(total);

  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  /// Doanh thu từng ngày, chỉ số 0 = ngày 1.
  List<int> get daily {
    final days = List.filled(daysInMonth, 0);
    for (final i in items) {
      days[i.date.day - 1] += i.amount;
    }
    return days;
  }

  /// Doanh thu theo cơ sở, lớn nhất trước.
  List<({String facilityId, String name, int amount})> get byFacility {
    final map = <String, ({String facilityId, String name, int amount})>{};
    for (final i in items) {
      final cur = map[i.facilityId];
      map[i.facilityId] = (facilityId: i.facilityId, name: i.facilityName, amount: (cur?.amount ?? 0) + i.amount);
    }
    return map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

enum FeeStatus { due, overdue, paid }

/// Hóa đơn phí duy trì của một tháng: chốt ngày 1 tháng sau, hạn ngày 7.
class ListingFeeBill {
  final String id;

  /// Ngày 1 của tháng tính phí.
  final DateTime month;
  final int revenue;
  final int amount;
  final DateTime? paidAt;

  const ListingFeeBill({
    required this.id,
    required this.month,
    required this.revenue,
    required this.amount,
    this.paidAt,
  });

  DateTime get issuedAt => DateTime(month.year, month.month + 1, 1);

  /// Hạn trả (hết ngày này).
  DateTime get dueDate => DateTime(month.year, month.month + 1, ListingFeeRules.dueDay);

  FeeStatus status(DateTime now) {
    if (paidAt != null) return FeeStatus.paid;
    return now.isBefore(dueDate.add(const Duration(days: 1))) ? FeeStatus.due : FeeStatus.overdue;
  }

  ListingFeeBill copyWith({DateTime? paidAt}) =>
      ListingFeeBill(id: id, month: month, revenue: revenue, amount: amount, paidAt: paidAt ?? this.paidAt);

  factory ListingFeeBill.fromJson(Map<String, dynamic> json) => ListingFeeBill(
        id: json['id'] as String,
        month: DateTime.parse(json['month'] as String),
        revenue: (json['revenue'] as num).toInt(),
        amount: (json['amount'] as num).toInt(),
        paidAt: json['paidAt'] == null ? null : DateTime.parse(json['paidAt'] as String),
      );
}
