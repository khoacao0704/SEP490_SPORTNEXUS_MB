import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/booking_rules.dart';
import '../../core/constants/voucher_rules.dart';
import '../../core/strings/booking_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking.dart';
import '../../models/voucher.dart';
import '../../models/recurring_plan.dart';
import '../../models/split_payment.dart';
import '../../models/time_slot.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/booking_repository.dart';
import '../repositories/facility_repository.dart';
import '../repositories/wallet_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_wallet_repository.dart';

/// Bản giả lập [BookingRepository].
///
/// - Lần đặt lưu trong máy; tiền trừ/hoàn qua ví giả lập.
/// - Khung giờ được giữ tới khi kết thúc qua bản giả lập sân (chỉ trong bộ nhớ); hủy thì nhả.
class MockBookingRepository implements BookingRepository {
  static const String keyBookings = 'bookings';

  final Duration latency;
  final DateTime Function() _now;
  final MockWalletRepository _wallet;
  final FacilityRepository _facility;

  /// bookingId -> holdId đang giữ khung giờ.
  final Map<String, String> _holds = {};
  int _counter = 0;

  MockBookingRepository({
    required this._facility,
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
    MockWalletRepository? wallet,
  })  : _now = now ?? DateTime.now,
        _wallet = wallet ?? MockWalletRepository(latency: Duration.zero);

  @override
  Future<List<Booking>> createBooking({
    required SlotHold hold,
    required BookingPaymentType paymentType,
    required String facilityName,
    required String sportLabel,
    required String location,
    required String schedule,
    bool recurring = false,
    int discountPercent = 0,
    Voucher? voucher,
  }) async {
    await _delay();
    if (paymentType == BookingPaymentType.split) throw const BookingException(BookingStrings.useSplitFlow);
    final me = await _requireUser();
    final now = _now();
    final slots = [...hold.slots]..sort((a, b) => a.start.compareTo(b.start));
    // Như BE: danh sách thành gói hợp lệ thì là gói (giảm giá); cờ [recurring] chỉ để báo lỗi khi không thành gói.
    final packageError = RecurringPlan.packageError(slots);
    if (recurring && packageError != null) throw BookingException(BookingStrings.notAPackage(packageError));
    final isPackage = packageError == null;
    final percent = isPackage ? discountPercent : 0;
    // Như BE: voucher chỉ cho lần đặt thành đúng 1 đơn (không gói, cùng sân, ca liền nhau); giảm trên giá sau gói.
    if (voucher != null) {
      if (isPackage || !VoucherRules.formsSingleBooking(slots)) throw const BookingException(BookingStrings.voucherSingleOnly);
      if (voucher.status != VoucherStatus.active || !voucher.expiresAt.isAfter(now)) {
        throw const BookingException(BookingStrings.voucherUnavailable);
      }
    }
    final prices = [for (final s in slots) RecurringBookingRules.discounted(s.price, percent)];
    final voucherOff = VoucherRules.discount(prices.fold(0, (a, b) => a + b), voucher?.discountPercent ?? 0);
    if (voucherOff > 0) prices[prices.length - 1] -= voucherOff;
    int priceOf(TimeSlot s) => prices[slots.indexOf(s)];
    final total = prices.fold(0, (sum, p) => sum + p);
    final baseId = '${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}${++_counter}';
    final groupId = isPackage ? 'PKG-$baseId' : null;
    String idFor(int i) => slots.length == 1 ? baseId : '$baseId-${i + 1}';

    // Một giao dịch ví cho cả lần thanh toán; mỗi khung giờ là một lượt đặt riêng.
    try {
      await _wallet.pay(
        amount: total,
        type: TransactionType.bookingPayment,
        description: 'Đặt sân $facilityName'
            '${isPackage ? ' • gói cố định' : slots.length > 1 ? ' • ${slots.length} khung giờ' : ''}',
        reference: baseId,
      );
    } on WalletException catch (e) {
      throw BookingException(e.message);
    }

    final bookings = <Booking>[];
    try {
      for (var i = 0; i < slots.length; i++) {
        final slot = slots[i];
        final kept = await _facility.transferHold(hold.holdId, until: slot.end, slotIds: [slot.id]);
        _holds[idFor(i)] = kept.holdId;
        bookings.add(Booking(
          id: idFor(i),
          bookerId: me.id,
          facilityName: facilityName,
          location: location,
          sportLabel: sportLabel,
          courtName: slot.courtName,
          schedule: Formatters.slotLabel(slot.start, slot.end),
          start: slot.start,
          end: slot.end,
          totalPrice: priceOf(slot),
          paymentType: paymentType,
          payments: [BookingPayment(userId: me.id, name: me.name, amount: priceOf(slot))],
          createdAt: now,
          recurringGroupId: groupId,
          originalPrice: priceOf(slot) != slot.price ? slot.price : null,
        ));
      }
    } on FacilityException catch (e) {
      // Chỗ giữ vừa hết hạn: nhả các khung đã chuyển và hoàn lại toàn bộ.
      for (final b in bookings) {
        final holdId = _holds.remove(b.id);
        if (holdId != null) await _facility.releaseHold(holdId);
      }
      await _wallet.creditRefund(amount: total, description: 'Hoàn Điểm đặt sân $facilityName', reference: baseId);
      throw BookingException(e.message);
    }

    for (final b in bookings) {
      await _save(b);
    }
    return bookings;
  }

  /// Bản giả lập chia Điểm gọi khi nhóm đã trả đủ (việc BE tự làm): mỗi khung giờ một lượt đặt,
  /// phần của từng người chia theo tỉ lệ giá các khung. [holdIds]: slotId -> lượt giữ của khung đó.
  Future<List<Booking>> addFromSplit(SplitPayment split, {Map<String, String> holdIds = const {}}) async {
    final slots = [...split.slots]..sort((a, b) => a.start.compareTo(b.start));
    final paid = split.shares.where((s) => s.isPaid).toList();
    final allocated = {for (final s in paid) s.index: 0};
    final bookings = <Booking>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final isLast = i == slots.length - 1;
      final payments = <BookingPayment>[];
      for (final s in paid) {
        // Khung cuối nhận phần còn lại để tổng mỗi người đúng bằng số đã trả.
        final amount = isLast ? s.amount - allocated[s.index]! : (s.amount * slot.price / split.totalAmount).round();
        allocated[s.index] = allocated[s.index]! + amount;
        payments.add(BookingPayment(userId: s.payerId!, name: s.payerName!, amount: amount));
      }
      final id = slots.length == 1 ? split.bookingId : '${split.bookingId}-${i + 1}';
      final booking = Booking(
        id: id,
        bookerId: split.bookerId,
        facilityName: split.facilityName,
        location: split.location,
        sportLabel: split.sportLabel,
        courtName: slot.courtName,
        schedule: Formatters.slotLabel(slot.start, slot.end),
        start: slot.start,
        end: slot.end,
        totalPrice: slot.price,
        paymentType: BookingPaymentType.split,
        payments: payments,
        createdAt: _now(),
      );
      final holdId = holdIds[slot.id];
      if (holdId != null) _holds[id] = holdId;
      await _save(booking);
      bookings.add(booking);
    }
    return bookings;
  }

  @override
  Future<List<Booking>> getMyBookings() async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    final mine = (await _all())
        .where((b) => b.bookerId == me.id || b.payments.any((p) => p.userId == me.id))
        .toList();
    final upcoming = mine.where((b) => b.status(now) == BookingStatus.upcoming).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = mine.where((b) => b.status(now) != BookingStatus.upcoming).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return [...upcoming, ...past];
  }

  @override
  bool get supportsSplitPayment => true;

  /// Mã vé giả lập cố định theo lượt đặt.
  @override
  Duration? get ticketRefreshInterval => null;

  @override
  Future<String> getTicketCode(Booking booking) async => booking.ticketCode;

  /// Giống danh sách lý do của BE.
  @override
  Future<List<CancelReason>> getCancelReasons() async => const [
        CancelReason(code: 1, label: 'Thay đổi lịch trình / Bận việc đột xuất'),
        CancelReason(code: 2, label: 'Không đủ người chơi / Đồng đội hủy kèo'),
        CancelReason(code: 3, label: 'Thời tiết xấu / Không thuận lợi di chuyển'),
        CancelReason(code: 4, label: 'Đặt nhầm ngày, khung giờ hoặc nhầm sân'),
        CancelReason(code: 5, label: 'Vấn đề sức khỏe / Chấn thương'),
        CancelReason(code: 6, label: 'Khác (Tự nhập lý do)', isCustom: true),
      ];

  // ---- Chia Điểm mời bạn: bản giả lập dùng luồng mã/link của MockSplitPaymentRepository ----

  @override
  bool get supportsSplitInvite => false;

  Never _inviteUnsupported() => throw const BookingException(BookingStrings.splitUnavailable);

  @override
  Future<PlayerLookup> findPlayerByPhone(String phone) async => _inviteUnsupported();

  @override
  Future<List<Booking>> createSplitBooking({
    required SlotHold hold,
    required List<String> inviteeIds,
    required String facilityName,
    required String sportLabel,
    required String location,
  }) async =>
      _inviteUnsupported();

  @override
  Future<Booking> getBooking(String bookingId) async {
    final booking = (await _all()).where((b) => b.id == bookingId).firstOrNull;
    if (booking == null) throw const BookingException(BookingStrings.notFound);
    return booking;
  }

  @override
  Future<Booking> joinSplit(String bookingId) async => _inviteUnsupported();

  @override
  Future<Booking> inviteMore(String bookingId, List<String> inviteeIds) async => _inviteUnsupported();

  @override
  Future<Booking> payRemaining(String bookingId) async => _inviteUnsupported();

  /// Bản giả lập không lưu lý do hủy.
  @override
  Future<Booking> cancelBooking(String bookingId, {int? reasonCode, String? reason}) async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    final booking = (await _all()).where((b) => b.id == bookingId).firstOrNull;
    if (booking == null) throw const BookingException(BookingStrings.notFound);
    if (booking.bookerId != me.id) throw const BookingException(BookingStrings.onlyBookerCancels);
    if (booking.isRecurring) return _cancelPackage(booking, me, now);
    if (!booking.canCancel(now, me.id)) throw const BookingException(BookingStrings.cannotCancel);

    // Như BE: hoàn theo bậc (7 ngày 100%, 3 ngày 80%, 48 giờ 50%, dưới 48 giờ 0%; chờ góp luôn 100%),
    // chia cho từng người theo tỷ lệ phần đã góp (người cuối nhận phần còn lại).
    final total = booking.refundIfCancelled(now);
    final paying = booking.payments.where((p) => p.amount > 0).toList();
    final shares = BookingCancelPolicy.split(total, [for (final p in paying) p.amount]);
    var refunded = 0;
    for (var i = 0; i < paying.length; i++) {
      final p = paying[i];
      if (shares[i] <= 0) continue;
      refunded += shares[i];
      await _wallet.creditRefund(
        amount: shares[i],
        description: 'Hoàn Điểm hủy đặt sân ${booking.facilityName}${p.userId == me.id ? '' : ' • phần của ${p.name}'}',
        reference: booking.id,
      );
    }

    final holdId = _holds.remove(booking.id);
    if (holdId != null) await _facility.releaseHold(holdId);
    final cancelled = booking.copyWith(cancelledAt: now, refunded: refunded);
    await _save(cancelled);
    return cancelled;
  }

  /// Như BE: hủy một buổi của gói = hủy mọi buổi chưa hủy, hoàn theo bậc tới buổi đầu; chỉ khi còn ≥48h trước buổi đầu còn lại.
  Future<Booking> _cancelPackage(Booking booking, ({String id, String name}) me, DateTime now) async {
    final package = BookingPackage(
      booking.recurringGroupId!,
      (await _all()).where((b) => b.recurringGroupId == booking.recurringGroupId).toList(),
    );
    if (!package.canCancel(now, me.id)) throw const BookingException(BookingStrings.packageCancelTooLate);
    // Bậc xét một lần theo buổi đầu còn hiệu lực, % áp cho từng buổi (mỗi buổi làm tròn riêng).
    final percent = package.cancelRefundPercent(now);
    Booking? result;
    for (final b in package.active) {
      final refund = BookingCancelPolicy.refund(b.amountPaid, percent);
      if (refund > 0) {
        await _wallet.creditRefund(
          amount: refund,
          description: 'Hoàn $percent% hủy gói cố định ${b.facilityName}',
          reference: b.id,
        );
      }
      final holdId = _holds.remove(b.id);
      if (holdId != null) await _facility.releaseHold(holdId);
      final cancelled = b.copyWith(cancelledAt: now, refunded: refund);
      await _save(cancelled);
      if (b.id == booking.id) result = cancelled;
    }
    return result ?? booking;
  }

  // ---------------- Nội bộ ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<({String id, String name})> _requireUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) throw const BookingException(BookingStrings.loginRequired);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (id: json['id'] as String, name: json['fullName'] as String);
  }

  Future<List<Booking>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyBookings);
    if (raw == null) {
      // Lần đầu: tạo vài lần đặt mẫu (tính theo giờ hiện tại) để thử hủy ngay.
      final seeds = _seedBookings();
      await prefs.setString(keyBookings, jsonEncode(seeds.map((b) => b.toJson()).toList()));
      return seeds;
    }
    return (jsonDecode(raw) as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Đặt mẫu của tài khoản demo player@: còn hơn 48 giờ (hủy miễn phí), còn ~12 giờ (hủy không được hoàn), đã qua.
  List<Booking> _seedBookings() {
    final now = _now();
    final hour = DateTime(now.year, now.month, now.day, now.hour);
    const me = (id: 'u-player-001', name: 'Khoa Cao');
    Booking seed(String id, String facility, String location, String sport, DateTime start, Duration length, int total,
        BookingPaymentType type) {
      final end = start.add(length);
      return Booking(
        id: id,
        bookerId: me.id,
        facilityName: facility,
        location: location,
        sportLabel: sport,
        schedule: Formatters.slotLabel(start, end),
        start: start,
        end: end,
        totalPrice: total,
        paymentType: type,
        payments: [BookingPayment(userId: me.id, name: me.name, amount: total)],
        createdAt: now.subtract(const Duration(days: 1)),
      );
    }

    final in4Days = DateTime(now.year, now.month, now.day + 4, 18);
    return [
      seed('DEMO1', 'Sân Cầu Lông Thiên Triều', 'Quận 7, Hồ Chí Minh', 'Cầu Lông', in4Days,
          const Duration(hours: 1), 168000, BookingPaymentType.full),
      seed('DEMO2', 'Sân Bóng Hoa Lư', 'Quận 1, Hồ Chí Minh', 'Bóng Đá • Sân 5 người',
          hour.add(const Duration(hours: 12)), const Duration(minutes: 90), 700000, BookingPaymentType.full),
      seed('DEMO3', 'Eco Sport Quận 7', 'Quận 7, Hồ Chí Minh', 'Pickleball',
          hour.subtract(const Duration(days: 3)), const Duration(hours: 1), 140000, BookingPaymentType.full),
    ];
  }

  Future<void> _save(Booking booking) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _all();
    all.removeWhere((b) => b.id == booking.id);
    all.add(booking);
    await prefs.setString(keyBookings, jsonEncode(all.map((b) => b.toJson()).toList()));
  }
}
