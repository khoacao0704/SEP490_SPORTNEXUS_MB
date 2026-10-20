import '../../core/constants/split_payment_rules.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking.dart';
import '../../models/time_slot.dart';
import '../repositories/booking_repository.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// [BookingRepository] gọi Backend thật.
///
/// - Đặt sân: POST /api/v1/bookings với các ca đã chọn; BE tạo MỘT đơn cho mỗi ca (cả lần đặt thành công hoặc
///   không đơn nào), trừ ví ngay (tạm giữ tới khi chơi xong). Hai người cùng đặt một ca: người sau nhận 400.
/// - BE chưa có: cọc 1/4 (chỉ trả 100%), giữ chỗ 10 phút (app tự đếm trên máy, xem [ApiFacilityRepository.holdSlots])
///   → [supportsDeposit] = false.
/// - Chia tiền: người đặt mời bạn theo TÀI KHOẢN (tra bằng SĐT); mỗi ca một đơn PENDING, mọi người (gồm người đặt)
///   chia đều, người đặt chịu phần lẻ; hạn 30 phút (không quá giờ bắt đầu). BE chưa có mã/link chia sẻ nên luồng
///   chia mã của SplitPaymentRepository tắt ([supportsSplitPayment] = false, [supportsSplitInvite] = true).
/// - Trạng thái đơn của BE: PENDING (chia tiền chờ góp), PAID, CHECKED_IN, CANCELLED; "đã chơi xong" suy ra từ giờ kết thúc.
/// - Hủy: chỉ người đặt; BE trả số tiền thực được hoàn. Vé QR đổi mã mỗi 30 giây.
class ApiBookingRepository implements BookingRepository {
  static const String bookingsPath = '/api/v1/bookings';
  static const String myBookingsPath = '/api/v1/bookings/my-bookings';
  static const String cancelReasonsPath = '/api/v1/bookings/cancellation-reasons';
  static String bookingPath(String id) => '/api/v1/bookings/$id';
  static String cancelPath(String id) => '/api/v1/bookings/$id/cancel';
  static String ticketPath(String id) => '/api/v1/bookings/$id/qr-ticket';
  static String joinPath(String id) => '/api/v1/bookings/$id/join';
  static String participantsPath(String id) => '/api/v1/bookings/$id/participants';
  static String payRemainingPath(String id) => '/api/v1/bookings/$id/pay-remaining';
  static const String lookupPath = '/api/accounts/lookup';

  /// Trạng thái thanh toán của một người trong đơn được tính là đã trả.
  static const Set<String> paidStatuses = {'HELD', 'PAID', 'RELEASED', 'CHECKED_IN'};

  final ApiClient _api;

  ApiBookingRepository({required this._api});

  @override
  bool get supportsDeposit => false;

  @override
  bool get supportsSplitPayment => false;

  @override
  Duration? get ticketRefreshInterval => const Duration(seconds: 30);

  @override
  bool get supportsSplitInvite => true;

  @override
  Future<List<Booking>> createBooking({
    required SlotHold hold,
    required BookingPaymentType paymentType,
    required String facilityName,
    required String sportLabel,
    required String location,
    required String schedule,
  }) async {
    if (paymentType == BookingPaymentType.deposit) throw const BookingException(BookingStrings.depositUnavailable);
    if (paymentType == BookingPaymentType.split) throw const BookingException(BookingStrings.useSplitFlow);
    final me = await SessionStore.readUser();
    if (me == null) throw const BookingException(BookingStrings.loginRequired);

    final slots = [...hold.slots]..sort((a, b) => a.start.compareTo(b.start));
    // Ca vừa có người đặt / ví không đủ: BE trả câu tiếng Việt, hiển thị nguyên văn.
    final data = await _call(() => _api.post(bookingsPath, body: {'courtSlotIds': slots.map((s) => s.id).toList()}))
        as Map<String, dynamic>;

    final slotsById = {for (final s in slots) s.id: s};
    final now = DateTime.now();
    final bookings = (data['bookings'] as List? ?? const []).cast<Map<String, dynamic>>().map((b) {
      final slot = slotsById[b['courtSlotId']?.toString()];
      final start = _time(b['startTime']) ?? slot!.start;
      final end = _time(b['endTime']) ?? slot!.end;
      final price = b.containsKey('slotPrice') ? _money(b['slotPrice']) : slot?.price ?? 0;
      return Booking(
        id: b['bookingId'].toString(),
        bookerId: me.id,
        facilityName: facilityName,
        location: location,
        sportLabel: sportLabel,
        courtName: slot?.courtName,
        schedule: Formatters.slotLabel(start, end),
        start: start,
        end: end,
        totalPrice: price,
        paymentType: BookingPaymentType.full,
        payments: [BookingPayment(userId: me.id, name: me.fullName, amount: price)],
        createdAt: now,
      );
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return bookings;
  }

  /// Gồm đơn mình đặt và đơn mình được mời góp tiền: sắp diễn ra trước (gần nhất trước), đã qua sau.
  @override
  Future<List<Booking>> getMyBookings() async {
    final myId = (await SessionStore.readUser())?.id ?? '';
    final list = await _call(() => _api.get(myBookingsPath)) as List? ?? const [];
    final all = list.cast<Map<String, dynamic>>().map((json) => bookingFromSummary(json, myId)).toList();
    final now = DateTime.now();
    final upcoming = all.where((b) => b.status(now) == BookingStatus.upcoming).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = all.where((b) => b.status(now) != BookingStatus.upcoming).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return [...upcoming, ...past];
  }

  @override
  Future<Booking> cancelBooking(String bookingId, {int? reasonCode, String? reason}) async {
    final note = reason?.trim();
    final result = await _call(() => _api.post(cancelPath(bookingId), body: {
          'reasonCode': ?reasonCode,
          if (note != null && note.isNotEmpty) 'reason': note,
        }));
    final refund = result is Map<String, dynamic> ? _money(result['refundAmount']) : 0;
    // Đã hủy xong; chi tiết chỉ để cập nhật thẻ. Không tải được thì vẫn báo đúng số tiền hoàn.
    try {
      final detail = await _api.get(bookingPath(bookingId)) as Map<String, dynamic>;
      return bookingFromDetail(detail, await _myId()).copyWith(cancelledAt: DateTime.now(), refunded: refund);
    } on ApiException {
      return _cancelledStub(bookingId, refund);
    }
  }

  @override
  Future<List<CancelReason>> getCancelReasons() async {
    final list = await _call(() => _api.get(cancelReasonsPath)) as List? ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map((r) => CancelReason(
              code: (r['code'] as num).toInt(),
              label: r['label'] as String? ?? '',
              isCustom: r['isCustom'] == true,
            ))
        .toList();
  }

  /// BE trả chuỗi TICKET_{bookingId}_{userId}_{chu kỳ 30 giây}; có thể bọc trong object.
  @override
  Future<String> getTicketCode(Booking booking) async {
    final data = await _call(() => _api.get(ticketPath(booking.id)));
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      for (final key in const ['qrCode', 'ticketCode', 'code', 'qrData', 'ticket']) {
        final value = data[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    throw const BookingException(BookingStrings.ticketLoadError);
  }

  // ---------------- Chia tiền: mời bạn theo tài khoản ----------------

  /// BE chỉ trả tài khoản đang hoạt động, không trả chính mình; SĐT bị che còn 4 số cuối.
  @override
  Future<PlayerLookup> findPlayerByPhone(String phone) async {
    final data = await _call(() => _api.get(lookupPath, query: {'phone': phone.trim()}));
    if (data is! Map<String, dynamic> || data['id'] == null) {
      throw const BookingException(SplitPaymentStrings.playerNotFound);
    }
    return PlayerLookup(
      id: data['id'].toString(),
      fullName: data['fullName'] as String? ?? '',
      phoneMasked: data['phoneMasked'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
    );
  }

  @override
  Future<List<Booking>> createSplitBooking({
    required SlotHold hold,
    required List<String> inviteeIds,
    required String facilityName,
    required String sportLabel,
    required String location,
  }) async {
    if (inviteeIds.isEmpty) throw const BookingException(SplitPaymentStrings.inviteRequired);
    final me = await SessionStore.readUser();
    if (me == null) throw const BookingException(BookingStrings.loginRequired);

    final slots = [...hold.slots]..sort((a, b) => a.start.compareTo(b.start));
    final data = await _call(() => _api.post(bookingsPath, body: {
          'courtSlotIds': slots.map((s) => s.id).toList(),
          'isSplitPayment': true,
          'participantIds': inviteeIds,
        })) as Map<String, dynamic>;

    final people = inviteeIds.length + 1;
    final slotsById = {for (final s in slots) s.id: s};
    final now = DateTime.now();
    return (data['bookings'] as List? ?? const []).cast<Map<String, dynamic>>().map((b) {
      final slot = slotsById[b['courtSlotId']?.toString()];
      final start = _time(b['startTime']) ?? slot!.start;
      final end = _time(b['endTime']) ?? slot!.end;
      final price = b.containsKey('slotPrice') ? _money(b['slotPrice']) : slot?.price ?? 0;
      final mine = SplitPaymentRules.hostShare(price, people);
      return Booking(
        id: b['bookingId'].toString(),
        bookerId: me.id,
        facilityName: facilityName,
        location: location,
        sportLabel: sportLabel,
        courtName: slot?.courtName,
        schedule: Formatters.slotLabel(start, end),
        start: start,
        end: end,
        totalPrice: price,
        paymentType: BookingPaymentType.split,
        payments: [BookingPayment(userId: me.id, name: me.fullName, amount: mine)],
        createdAt: now,
        awaitingPayment: true,
        myShare: mine,
      );
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<Booking> getBooking(String bookingId) async =>
      bookingFromDetail(await _call(() => _api.get(bookingPath(bookingId))) as Map<String, dynamic>, await _myId());

  /// Ví không đủ / quá hạn / đơn đã đủ: BE trả câu tiếng Việt.
  @override
  Future<Booking> joinSplit(String bookingId) async {
    await _call(() => _api.post(joinPath(bookingId)));
    return getBooking(bookingId);
  }

  /// Đã có bạn góp thì BE chặn ("Không thể chia lại tiền vì đã có thành viên góp tiền").
  @override
  Future<Booking> inviteMore(String bookingId, List<String> inviteeIds) async {
    await _call(() => _api.post(participantsPath(bookingId), body: {'participantIds': inviteeIds}));
    return getBooking(bookingId);
  }

  @override
  Future<Booking> payRemaining(String bookingId) async {
    await _call(() => _api.post(payRemainingPath(bookingId)));
    return getBooking(bookingId);
  }

  Future<String> _myId() async => (await SessionStore.readUser())?.id ?? '';

  // ---------------- Chuyển đổi dữ liệu BE ----------------

  /// Một phần tử của GET my-bookings. Danh sách không có giờ hủy / số tiền hoàn / người đặt khác mình:
  /// đơn đã hủy lấy tạm giờ tạo làm giờ hủy; đơn mình được mời thì không phải người đặt (không hủy được).
  static Booking bookingFromSummary(Map<String, dynamic> json, String myId) {
    final start = _time(json['startTime'])!;
    final end = _time(json['endTime'])!;
    final createdAt = _time(json['createdAt']) ?? start;
    final status = (json['bookingStatus'] as String? ?? '').toUpperCase();
    final isHost = (json['myRole'] as String? ?? '').toLowerCase() == 'host';
    final paid = paidStatuses.contains((json['myPaymentStatus'] as String? ?? '').toUpperCase());
    return Booking(
      id: json['bookingId'].toString(),
      bookerId: isHost ? myId : '',
      facilityName: json['facilityName'] as String? ?? '',
      location: json['facilityAddress'] as String? ?? '',
      sportLabel: _sportLabel(json['sportName']),
      courtName: json['courtName'] as String?,
      schedule: Formatters.slotLabel(start, end),
      start: start,
      end: end,
      totalPrice: _money(json['totalAmount']),
      paymentType: ((json['participantCount'] as num?) ?? 1) > 1 ? BookingPaymentType.split : BookingPaymentType.full,
      payments: paid ? [BookingPayment(userId: myId, name: '', amount: _money(json['myAmount']))] : const [],
      createdAt: createdAt,
      cancelledAt: status == 'CANCELLED' ? createdAt : null,
      isCheckedIn: status == 'CHECKED_IN',
      awaitingPayment: status == 'PENDING',
      myShare: ((json['participantCount'] as num?) ?? 1) > 1 ? _money(json['myAmount']) : 0,
    );
  }

  /// GET /bookings/{id}: đủ người đặt, người góp (amountContributed = phần của người đó), thông tin hủy.
  static Booking bookingFromDetail(Map<String, dynamic> json, String myId) {
    final start = _time(json['startTime'])!;
    final end = _time(json['endTime'])!;
    final status = (json['bookingStatus'] as String? ?? '').toUpperCase();
    final participants = (json['participants'] as List? ?? const []).cast<Map<String, dynamic>>();
    final cancellation = json['cancellation'] as Map<String, dynamic>?;
    final people = participants
        .map((p) => BookingParticipant(
              userId: p['userId'].toString(),
              name: p['fullName'] as String? ?? '',
              amount: _money(p['amountContributed']),
              isPaid: paidStatuses.contains((p['paymentStatus'] as String? ?? '').toUpperCase()),
              isHost: p['isHost'] == true,
            ))
        .toList();
    final me = people.where((p) => p.userId == myId).firstOrNull;
    return Booking(
      id: json['bookingId'].toString(),
      bookerId: json['hostId']?.toString() ?? '',
      facilityName: json['facilityName'] as String? ?? '',
      location: json['facilityAddress'] as String? ?? '',
      sportLabel: _sportLabel(json['sportName']),
      courtName: json['courtName'] as String?,
      schedule: Formatters.slotLabel(start, end),
      start: start,
      end: end,
      totalPrice: _money(json['totalAmount']),
      paymentType: participants.length > 1 ? BookingPaymentType.split : BookingPaymentType.full,
      payments: people.where((p) => p.isPaid).map((p) => BookingPayment(userId: p.userId, name: p.name, amount: p.amount)).toList(),
      createdAt: _time(json['createdAt']) ?? start,
      cancelledAt: status == 'CANCELLED' ? _time(cancellation?['cancelledAt']) ?? DateTime.now() : null,
      refunded: _money(cancellation?['refundAmount']),
      isCheckedIn: status == 'CHECKED_IN',
      awaitingPayment: status == 'PENDING',
      myShare: people.length > 1 ? me?.amount ?? 0 : 0,
      participants: people,
    );
  }

  /// Đã hủy nhưng không tải lại được chi tiết: chỉ cần số tiền hoàn để báo người dùng.
  static Booking _cancelledStub(String id, int refund) {
    final now = DateTime.now();
    return Booking(
      id: id,
      bookerId: '',
      facilityName: '',
      location: '',
      sportLabel: '',
      schedule: '',
      start: now,
      end: now,
      totalPrice: 0,
      paymentType: BookingPaymentType.full,
      payments: const [],
      createdAt: now,
      cancelledAt: now,
      refunded: refund,
    );
  }

  /// "Cầu lông" của BE → nhãn môn của app; môn app chưa có thì giữ nguyên tên BE.
  static String _sportLabel(Object? value) {
    final name = value as String?;
    return ApiFacilityRepository.sportFromName(name)?.label ?? name ?? '';
  }

  static DateTime? _time(Object? value) => value is String ? DateTime.parse(value).toLocal() : null;

  /// Tiền BE là decimal nhưng luôn là VNĐ nguyên.
  static int _money(Object? value) => value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;

  /// Gọi BE; lỗi thành [BookingException] mang câu tiếng Việt của BE.
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw BookingException(e.message);
    }
  }
}
