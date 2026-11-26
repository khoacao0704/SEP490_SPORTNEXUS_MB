// Đơn đặt sân và lưới ca phía Chủ sân, đọc theo đúng tên trường Web FE đang dùng
// (GET /bookings/owner, /bookings/owner/{id}, /facilities/{id}/slots).

int _int(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

DateTime? _date(Object? v) {
  final s = _str(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

bool _bool(Object? v) => v == true || v?.toString().toLowerCase() == 'true';

String _upper(Object? v) => (v?.toString() ?? '').trim().toUpperCase();

/// Trạng thái đơn của BE: PENDING | PAID | CHECKED_IN | CANCELLED (thêm COMPLETED / NO_SHOW...).
abstract final class OwnerBookingStatus {
  static const pending = 'PENDING';
  static const paid = 'PAID';
  static const checkedIn = 'CHECKED_IN';
  static const cancelled = 'CANCELLED';
}

/// Người chơi của đơn (participants).
class OwnerBookingParticipant {
  final String userId;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final bool isHost;
  final int amountContributed;
  final String paymentStatus;
  final bool isCheckedIn;

  const OwnerBookingParticipant({
    required this.userId,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.isHost = false,
    this.amountContributed = 0,
    this.paymentStatus = '',
    this.isCheckedIn = false,
  });

  factory OwnerBookingParticipant.fromJson(Map<String, dynamic> j) => OwnerBookingParticipant(
        userId: _str(j['userId'] ?? j['accountId'] ?? j['id']) ?? '',
        fullName: _str(j['fullName'] ?? j['name']) ?? '—',
        phone: _str(j['phone']),
        avatarUrl: _str(j['avatarUrl']),
        isHost: _bool(j['isHost']),
        amountContributed: _int(j['amountContributed'] ?? j['amountPaid']),
        paymentStatus: _upper(j['paymentStatus']),
        isCheckedIn: _bool(j['isCheckedIn']) || j['checkedInAt'] != null,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'fullName': fullName,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'isHost': isHost,
        'amountContributed': amountContributed,
        'paymentStatus': paymentStatus,
        'isCheckedIn': isCheckedIn,
      };
}

/// Người chơi nhận suất trong kèo LFG gắn với đơn (lfg.participants).
class OwnerLfgPlayer {
  final String userId;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String status;
  final int amountPaid;
  final bool isCheckedIn;

  const OwnerLfgPlayer({
    required this.userId,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.status,
    this.amountPaid = 0,
    this.isCheckedIn = false,
  });

  bool get isAccepted => status == 'ACCEPTED';

  factory OwnerLfgPlayer.fromJson(Map<String, dynamic> j) => OwnerLfgPlayer(
        userId: _str(j['userId']) ?? '',
        fullName: _str(j['fullName'] ?? j['name']) ?? '—',
        phone: _str(j['phone']),
        avatarUrl: _str(j['avatarUrl']),
        status: _upper(j['status']),
        amountPaid: _int(j['amountPaid']),
        isCheckedIn: _bool(j['isCheckedIn']),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'fullName': fullName,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'status': status,
        'amountPaid': amountPaid,
        'isCheckedIn': isCheckedIn,
      };
}

/// Kèo LFG gắn với đơn (trường `lfg` của chi tiết đơn).
class OwnerBookingLfg {
  final String status;
  final String? cancelReason;
  final int? totalSlots;
  final int? remainingSlots;
  final int pricePerPerson;
  final int acceptedCount;
  final int checkedInCount;
  final List<OwnerLfgPlayer> participants;

  const OwnerBookingLfg({
    required this.status,
    this.cancelReason,
    this.totalSlots,
    this.remainingSlots,
    this.pricePerPerson = 0,
    this.acceptedCount = 0,
    this.checkedInCount = 0,
    this.participants = const [],
  });

  bool get isCancelled => status == 'CANCELLED';

  factory OwnerBookingLfg.fromJson(Map<String, dynamic> j) => OwnerBookingLfg(
        status: _upper(j['status']),
        cancelReason: _str(j['cancelReason']),
        totalSlots: j['totalSlots'] == null ? null : _int(j['totalSlots']),
        remainingSlots: j['remainingSlots'] == null ? null : _int(j['remainingSlots']),
        pricePerPerson: _int(j['pricePerPerson']),
        acceptedCount: _int(j['acceptedCount']),
        checkedInCount: _int(j['checkedInCount']),
        participants: (j['participants'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => OwnerLfgPlayer.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'cancelReason': cancelReason,
        'totalSlots': totalSlots,
        'remainingSlots': remainingSlots,
        'pricePerPerson': pricePerPerson,
        'acceptedCount': acceptedCount,
        'checkedInCount': checkedInCount,
        'participants': participants.map((p) => p.toJson()).toList(),
      };
}

/// Thông tin hủy của đơn đã hủy (trường `cancellation`).
class OwnerBookingCancellation {
  final DateTime? cancelledAt;
  final String? reason;
  final int refundAmount;
  final int penaltyAmount;

  const OwnerBookingCancellation({this.cancelledAt, this.reason, this.refundAmount = 0, this.penaltyAmount = 0});

  factory OwnerBookingCancellation.fromJson(Map<String, dynamic> j) => OwnerBookingCancellation(
        cancelledAt: _date(j['cancelledAt']),
        reason: _str(j['reason']),
        refundAmount: _int(j['refundAmount']),
        penaltyAmount: _int(j['penaltyAmount']),
      );

  Map<String, dynamic> toJson() => {
        'cancelledAt': cancelledAt?.toIso8601String(),
        'reason': reason,
        'refundAmount': refundAmount,
        'penaltyAmount': penaltyAmount,
      };
}

/// Một đơn đặt sân nhìn từ phía Chủ sân (dòng danh sách hoặc chi tiết).
class OwnerBooking {
  final String id;
  final String facilityId;
  final String status;
  final String courtName;
  final String sportName;
  final DateTime start;
  final DateTime end;
  final int totalAmount;
  final int paidAmount;
  final int pendingAmount;
  final DateTime? createdAt;

  /// Danh sách đơn trả customerName/customerPhone; chi tiết đơn trả hostName/hostPhone.
  final String? customerName;
  final String? customerPhone;
  final String? customerNote;
  final bool isWalkIn;
  final bool isNoShow;
  final int participantCount;
  final int checkedInCount;
  final List<OwnerBookingParticipant> participants;
  final OwnerBookingLfg? lfg;
  final OwnerBookingCancellation? cancellation;

  const OwnerBooking({
    required this.id,
    this.facilityId = '',
    required this.status,
    required this.courtName,
    this.sportName = '',
    required this.start,
    required this.end,
    required this.totalAmount,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.createdAt,
    this.customerName,
    this.customerPhone,
    this.customerNote,
    this.isWalkIn = false,
    this.isNoShow = false,
    this.participantCount = 0,
    this.checkedInCount = 0,
    this.participants = const [],
    this.lfg,
    this.cancellation,
  });

  bool get isLfg => lfg != null;

  /// Web: chỉ hủy được đơn PENDING / PAID.
  bool get canCancel => status == OwnerBookingStatus.pending || status == OwnerBookingStatus.paid;

  /// Web: kết thúc ca sớm khi đơn đã check-in và ca chưa hết giờ.
  bool canEndEarly(DateTime now) => status == OwnerBookingStatus.checkedIn && end.isAfter(now);

  /// Số người đã vào sân: ưu tiên số BE trả, không có thì đếm từ participants.
  int get checkedIn => checkedInCount > 0 ? checkedInCount : participants.where((p) => p.isCheckedIn).length;

  OwnerBooking copyWith({
    String? status,
    bool? isNoShow,
    List<OwnerBookingParticipant>? participants,
    int? checkedInCount,
    int? paidAmount,
    int? pendingAmount,
    OwnerBookingCancellation? cancellation,
  }) =>
      OwnerBooking(
        id: id,
        facilityId: facilityId,
        status: status ?? this.status,
        courtName: courtName,
        sportName: sportName,
        start: start,
        end: end,
        totalAmount: totalAmount,
        paidAmount: paidAmount ?? this.paidAmount,
        pendingAmount: pendingAmount ?? this.pendingAmount,
        createdAt: createdAt,
        customerName: customerName,
        customerPhone: customerPhone,
        customerNote: customerNote,
        isWalkIn: isWalkIn,
        isNoShow: isNoShow ?? this.isNoShow,
        participantCount: participantCount,
        checkedInCount: checkedInCount ?? this.checkedInCount,
        participants: participants ?? this.participants,
        lfg: lfg,
        cancellation: cancellation ?? this.cancellation,
      );

  factory OwnerBooking.fromJson(Map<String, dynamic> j) {
    final start = _date(j['startTime'] ?? j['start']) ?? DateTime.now();
    final participants = (j['participants'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => OwnerBookingParticipant.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final lfg = j['lfg'];
    final cancellation = j['cancellation'];
    return OwnerBooking(
      id: _str(j['bookingId'] ?? j['id']) ?? '',
      facilityId: _str(j['facilityId']) ?? '',
      status: _upper(j['bookingStatus'] ?? j['status']),
      courtName: _str(j['courtName']) ?? '—',
      sportName: _str(j['sportName']) ?? '',
      start: start,
      end: _date(j['endTime'] ?? j['end']) ?? start.add(const Duration(hours: 1)),
      totalAmount: _int(j['totalAmount'] ?? j['totalPrice']),
      paidAmount: _int(j['paidAmount']),
      pendingAmount: _int(j['pendingAmount']),
      createdAt: _date(j['createdAt']),
      customerName: _str(j['customerName'] ?? j['hostName']),
      customerPhone: _str(j['customerPhone'] ?? j['hostPhone']),
      customerNote: _str(j['customerNote']),
      isWalkIn: _bool(j['isWalkIn']),
      isNoShow: _bool(j['isNoShow']),
      participantCount: j['participantCount'] == null ? participants.length : _int(j['participantCount']),
      checkedInCount: _int(j['checkedInCount']),
      participants: participants,
      lfg: lfg is Map ? OwnerBookingLfg.fromJson(Map<String, dynamic>.from(lfg)) : null,
      cancellation: cancellation is Map ? OwnerBookingCancellation.fromJson(Map<String, dynamic>.from(cancellation)) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'bookingId': id,
        'facilityId': facilityId,
        'bookingStatus': status,
        'courtName': courtName,
        'sportName': sportName,
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'pendingAmount': pendingAmount,
        'createdAt': createdAt?.toIso8601String(),
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerNote': customerNote,
        'isWalkIn': isWalkIn,
        'isNoShow': isNoShow,
        'participantCount': participantCount,
        'checkedInCount': checkedInCount,
        'participants': participants.map((p) => p.toJson()).toList(),
        'lfg': lfg?.toJson(),
        'cancellation': cancellation?.toJson(),
      };
}

/// Một trang danh sách đơn kèm số liệu tổng (totalActiveRevenue, paidCount...).
class OwnerBookingPage {
  final List<OwnerBooking> items;
  final int total;
  final int totalPages;
  final int revenue;
  final int paidCount;
  final int checkedInCount;
  final int cancelledCount;

  const OwnerBookingPage({
    required this.items,
    required this.total,
    required this.totalPages,
    this.revenue = 0,
    this.paidCount = 0,
    this.checkedInCount = 0,
    this.cancelledCount = 0,
  });

  static const empty = OwnerBookingPage(items: [], total: 0, totalPages: 1);

  factory OwnerBookingPage.fromJson(Object? data, {required int pageSize}) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final raw = data is List ? data : (map['items'] ?? map['data'] ?? const []) as List;
    final items = raw.whereType<Map>().map((e) => OwnerBooking.fromJson(Map<String, dynamic>.from(e))).toList();
    final total = map['total'] ?? map['totalCount'] ?? map['totalItems'];
    final count = total == null ? items.length : _int(total);
    final pages = _int(map['totalPages']);
    return OwnerBookingPage(
      items: items,
      total: count,
      totalPages: pages > 0 ? pages : (count / pageSize).ceil().clamp(1, 1 << 30),
      revenue: _int(map['totalActiveRevenue']),
      paidCount: _int(map['paidCount']),
      checkedInCount: _int(map['checkedInCount']),
      cancelledCount: _int(map['cancelledCount']),
    );
  }
}

/// Trạng thái một ô trên lưới lịch (theo `cellState` của Web).
enum SlotCellState { available, past, maintenance, reserved, checkedIn, paid, pending }

/// Mã CourtSlotStatus BE nhận ở PUT /slots/{id}/status.
abstract final class CourtSlotStatusCode {
  static const available = 0;
  static const maintenance = 3;
}

/// Một ca trên lưới lịch của cơ sở.
class ScheduleSlot {
  final String id;
  final DateTime start;
  final DateTime end;
  final String status;
  final String bookingStatus;
  final String? bookingId;
  final int price;
  final bool isPast;
  final bool isWalkIn;
  final String? customerName;
  final String? customerPhone;
  final int? bookingTotalAmount;
  final String? matchName;

  const ScheduleSlot({
    required this.id,
    required this.start,
    required this.end,
    required this.status,
    this.bookingStatus = '',
    this.bookingId,
    required this.price,
    this.isPast = false,
    this.isWalkIn = false,
    this.customerName,
    this.customerPhone,
    this.bookingTotalAmount,
    this.matchName,
  });

  SlotCellState get state {
    if (status == 'BOOKED') {
      if (bookingStatus == OwnerBookingStatus.checkedIn) return SlotCellState.checkedIn;
      if (bookingStatus == OwnerBookingStatus.pending) return SlotCellState.pending;
      return SlotCellState.paid;
    }
    if (status == 'MAINTENANCE') return SlotCellState.maintenance;
    if (status == 'RESERVED') return SlotCellState.reserved;
    return isPast ? SlotCellState.past : SlotCellState.available;
  }

  bool get isBooked => const {SlotCellState.checkedIn, SlotCellState.paid, SlotCellState.pending}.contains(state);

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) {
    final start = _date(j['startTime']) ?? DateTime.now();
    return ScheduleSlot(
      id: _str(j['id'] ?? j['slotId'] ?? j['courtSlotId']) ?? '',
      start: start,
      end: _date(j['endTime']) ?? start.add(const Duration(hours: 1)),
      status: _upper(j['status']),
      bookingStatus: _upper(j['bookingStatus']),
      bookingId: _str(j['bookingId']),
      price: _int(j['price']),
      isPast: _bool(j['isPast']),
      isWalkIn: _bool(j['isWalkIn']),
      customerName: _str(j['customerName']),
      customerPhone: _str(j['customerPhone']),
      bookingTotalAmount: j['bookingTotalAmount'] == null && j['totalAmount'] == null
          ? null
          : _int(j['bookingTotalAmount'] ?? j['totalAmount']),
      matchName: _str(j['matchName'] ?? j['tournamentName']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'status': status,
        'bookingStatus': bookingStatus,
        'bookingId': bookingId,
        'price': price,
        'isPast': isPast,
        'isWalkIn': isWalkIn,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'bookingTotalAmount': bookingTotalAmount,
        'matchName': matchName,
      };
}

/// Một sân con trên lưới lịch.
class ScheduleCourt {
  final String id;
  final String name;
  final String sport;
  final String status;
  final List<ScheduleSlot> slots;

  const ScheduleCourt({required this.id, required this.name, required this.sport, required this.status, required this.slots});

  bool get isActive => status == 'ACTIVE';

  factory ScheduleCourt.fromJson(Map<String, dynamic> j) => ScheduleCourt(
        id: _str(j['courtId'] ?? j['id']) ?? '',
        name: _str(j['courtName'] ?? j['name']) ?? '—',
        sport: _str(j['sportName']) ?? 'Khác',
        status: _upper(j['status']),
        slots: ((j['slots'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e)))
                .toList())
          ..sort((a, b) => a.start.compareTo(b.start)),
      );
}

/// Lịch một ngày của cơ sở: GET /facilities/{id}/slots?date=.
class FacilityDaySchedule {
  final String facilityName;
  final int totalSlots;
  final int availableSlots;
  final int lockedSlots;
  final List<ScheduleCourt> courts;

  const FacilityDaySchedule({
    required this.facilityName,
    required this.totalSlots,
    required this.availableSlots,
    required this.lockedSlots,
    required this.courts,
  });

  factory FacilityDaySchedule.fromJson(Map<String, dynamic> j) {
    final courts = (j['courts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ScheduleCourt.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final all = courts.expand((c) => c.slots).toList();
    return FacilityDaySchedule(
      facilityName: _str(j['facilityName']) ?? '',
      totalSlots: j['totalSlots'] == null ? all.length : _int(j['totalSlots']),
      availableSlots: j['availableSlots'] == null
          ? all.where((s) => s.state == SlotCellState.available).length
          : _int(j['availableSlots']),
      lockedSlots: j['lockedSlots'] == null
          ? all.where((s) => s.state == SlotCellState.maintenance).length
          : _int(j['lockedSlots']),
      courts: courts,
    );
  }
}

/// Đơn khách vãng lai: POST /bookings/owner/walk-in (CreateWalkInBookingRequest).
/// Một ca + số ca liên tiếp ([courtSlotId] + [numberOfSlots]) hoặc nhiều ca rời ([courtSlotIds]).
class WalkInRequest {
  final String? courtSlotId;
  final int numberOfSlots;
  final List<String>? courtSlotIds;
  final String customerName;
  final String? customerPhone;
  final String? note;
  final bool autoCheckIn;

  const WalkInRequest({
    this.courtSlotId,
    this.numberOfSlots = 1,
    this.courtSlotIds,
    required this.customerName,
    this.customerPhone,
    this.note,
    this.autoCheckIn = false,
  });

  Map<String, dynamic> toJson() => {
        if (courtSlotIds != null) 'courtSlotIds': courtSlotIds else ...{
          'courtSlotId': courtSlotId,
          'numberOfSlots': numberOfSlots,
        },
        'customerName': customerName,
        'customerPhone': customerPhone,
        'note': note,
        'autoCheckIn': autoCheckIn,
      };
}

/// Kết quả quét QR: message BE + thông tin người cầm vé (BE chưa mô tả schema nên thử vài tên trường như Web).
class ScanResult {
  final String message;
  final String? ticketType;
  final String? customerName;
  final String? courtName;
  final DateTime? start;
  final DateTime? end;
  final int? amount;
  final String? avatarUrl;

  const ScanResult({
    required this.message,
    this.ticketType,
    this.customerName,
    this.courtName,
    this.start,
    this.end,
    this.amount,
    this.avatarUrl,
  });

  factory ScanResult.fromJson(Object? data, String message) {
    final j = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    Object? pick(List<String> keys) => keys.map((k) => j[k]).firstWhere((v) => v != null, orElse: () => null);
    final amount = pick(['totalAmount', 'amountPaid', 'amount']);
    return ScanResult(
      message: message,
      ticketType: _str(j['ticketType'])?.toUpperCase(),
      customerName: _str(pick(['customerName', 'hostName', 'fullName', 'playerName', 'userName'])),
      courtName: _str(j['courtName']),
      start: _date(j['startTime']),
      end: _date(j['endTime']),
      amount: amount == null ? null : _int(amount),
      avatarUrl: _str(j['avatarUrl']),
    );
  }
}

/// Kết quả Chủ sân hủy đơn (POST /bookings/owner/{id}/cancel).
class OwnerCancelResult {
  /// Điểm phạt đã trừ vào Ví điểm Chủ sân.
  final int penaltyAmount;

  /// Điểm Fair Play bị trừ (0 nếu hủy từ 48h trở lên hoặc đơn vãng lai).
  final int fairPlayPenalty;

  /// Tiền hoàn cho khách.
  final int refundAmount;

  const OwnerCancelResult({required this.penaltyAmount, required this.fairPlayPenalty, required this.refundAmount});
}
