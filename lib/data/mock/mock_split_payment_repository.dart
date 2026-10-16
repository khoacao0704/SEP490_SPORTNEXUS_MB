import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/split_payment_rules.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../models/split_payment.dart';
import '../../models/time_slot.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/facility_repository.dart';
import '../repositories/split_payment_repository.dart';
import '../repositories/wallet_repository.dart';
import 'mock_booking_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_wallet_repository.dart';

/// Bản giả lập [SplitPaymentRepository].
///
/// - Lượt chia lưu trong máy; ví giả lập dùng chung nên đăng nhập tài khoản khác trên cùng máy
///   để thử vai người nhận link.
/// - Việc BE làm khi hết 30 phút (hủy đặt sân, hoàn tiền, nhả khung giờ) được làm lúc đọc dữ liệu.
/// - Đủ tiền thì giữ hẳn khung giờ tới khi kết thúc và tạo lần đặt sân qua [MockBookingRepository].
class MockSplitPaymentRepository implements SplitPaymentRepository, SandboxSplitSimulator {
  static const String keySplits = 'split_payments_v3';

  final Duration latency;
  final DateTime Function() _now;
  final MockWalletRepository _wallet;
  final FacilityRepository _facility;
  final MockBookingRepository? _bookings;

  /// splitId -> holdId đang giữ khung giờ (chỉ trong bộ nhớ, giống giữ chỗ của bản giả lập sân).
  final Map<String, String> _holds = {};

  int _counter = 0;

  MockSplitPaymentRepository({
    required this._facility,
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
    MockWalletRepository? wallet,
    this._bookings,
  })  : _now = now ?? DateTime.now,
        _wallet = wallet ?? MockWalletRepository(latency: Duration.zero);

  @override
  Future<SplitPayment> create({
    required SlotHold hold,
    required int parts,
    required String facilityName,
    required String sportLabel,
    required String location,
    required String schedule,
  }) async {
    await _delay();
    final me = await _requireUser();
    if (!SplitPaymentRules.allowedParts.contains(parts)) throw const SplitPaymentException(SplitPaymentStrings.invalidParts);
    final now = _now();
    final total = hold.totalPrice;
    final id = 'split-${now.millisecondsSinceEpoch}-${++_counter}';

    final bookerAmount = SplitPaymentRules.bookerAmount(total, parts);
    await _pay(bookerAmount, 'Đặt sân $facilityName • phần 1/$parts (chia tiền)', id);

    final expiresAt = now.add(SplitPaymentRules.window);
    final SlotHold newHold;
    try {
      newHold = await _facility.transferHold(hold.holdId, until: expiresAt);
    } on FacilityException catch (e) {
      // Chỗ giữ vừa hết hạn: hoàn lại phần vừa trả.
      await _wallet.creditRefund(amount: bookerAmount, description: 'Hoàn tiền đặt sân $facilityName', reference: id);
      throw SplitPaymentException(e.message);
    }
    _holds[id] = newHold.holdId;

    final share = SplitPaymentRules.shareAmount(total, parts);
    final usedCodes = (await _all()).map((s) => s.code).toSet();
    var code = _codeFor(now, _counter);
    for (var salt = 1; usedCodes.contains(code); salt++) {
      code = _codeFor(now, _counter + salt);
    }
    final split = SplitPayment(
      id: id,
      code: code,
      bookerId: me.id,
      bookerName: me.name,
      facilityName: facilityName,
      sportLabel: sportLabel,
      location: location,
      schedule: schedule,
      slots: [for (final s in hold.slots) SplitSlot(id: s.id, courtName: s.courtName, start: s.start, end: s.end, price: s.price)],
      totalAmount: total,
      parts: parts,
      shares: [
        SplitShare(index: 0, amount: bookerAmount, payerId: me.id, payerName: me.name, paidAt: now),
        for (var i = 1; i < parts; i++) SplitShare(index: i, amount: share),
      ],
      createdAt: now,
      expiresAt: expiresAt,
    );
    await _save(split);
    return split;
  }

  @override
  Future<SplitPayment> getById(String id) async {
    await _delay();
    final split = (await _all()).where((s) => s.id == id).firstOrNull;
    return split ?? (throw const SplitPaymentException(SplitPaymentStrings.notFound));
  }

  @override
  Future<SplitPayment> findByCode(String code) async {
    await _delay();
    final key = code.trim().toUpperCase();
    final split = (await _all()).where((s) => s.code == key).firstOrNull;
    return split ?? (throw const SplitPaymentException(SplitPaymentStrings.notFound));
  }

  @override
  Future<List<SplitPayment>> getMine() async {
    await _delay();
    final me = await _requireUser();
    return (await _all()).where((s) => s.involves(me.id)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<SplitPayment> payShare(String code) async {
    await _delay();
    final me = await _requireUser();
    final key = code.trim().toUpperCase();
    final split = (await _all()).where((s) => s.code == key).firstOrNull;
    if (split == null) throw const SplitPaymentException(SplitPaymentStrings.notFound);
    if (split.bookerId == me.id) throw const SplitPaymentException(SplitPaymentStrings.isBooker);
    if (split.hasPaid(me.id)) throw const SplitPaymentException(SplitPaymentStrings.alreadyPaid);
    return _payNext(split, me.id, me.name);
  }

  @override
  Future<SplitPayment> simulateFriendPaid(String id) async {
    final split = await getById(id);
    final taken = split.shares.map((s) => s.payerId).toSet();
    final friend = _friends.firstWhere((f) => !taken.contains(f.id));
    return _payNext(split, friend.id, friend.name, chargeWallet: false);
  }

  // ---------------- Nội bộ ----------------

  Future<SplitPayment> _payNext(SplitPayment split, String userId, String name, {bool chargeWallet = true}) async {
    final now = _now();
    final status = split.status(now);
    if (status == SplitStatus.expired) throw const SplitPaymentException(SplitPaymentStrings.expired);
    final share = split.nextUnpaid;
    if (status == SplitStatus.completed || share == null) throw const SplitPaymentException(SplitPaymentStrings.fullyPaid);

    if (chargeWallet) {
      await _pay(share.amount, 'Chia tiền sân ${split.facilityName} • phần ${share.index + 1}/${split.parts}', split.id);
    }
    final updated = split.copyWith(shares: [
      for (final s in split.shares) s.index == share.index ? s.paidBy(userId, name, now) : s,
    ]);
    await _save(updated);
    if (updated.isFullyPaid) await _complete(updated);
    return updated;
  }

  /// Đủ tiền: mỗi khung giờ được giữ hẳn tới khi kết thúc và thành một lượt đặt (hiện ở "Lịch Đặt & QR").
  Future<void> _complete(SplitPayment split) async {
    final holdId = _holds.remove(split.id);
    final kept = <String, String>{};
    if (holdId != null) {
      for (final slot in split.slots) {
        try {
          kept[slot.id] = (await _facility.transferHold(holdId, until: slot.end, slotIds: [slot.id])).holdId;
        } on FacilityException {
          // Bản giả lập: chỗ giữ trong bộ nhớ có thể đã mất (mở lại app); BE giữ thật.
        }
      }
    }
    await _bookings?.addFromSplit(split, holdIds: kept);
  }

  /// Việc BE làm khi hết 30 phút mà chưa đủ: hoàn đủ cho người đã trả, nhả khung giờ.
  Future<SplitPayment> _settle(SplitPayment split) async {
    if (split.refunded || split.isFullyPaid || _now().isBefore(split.expiresAt)) return split;
    // Bạn bè giả lập không trả qua ví này nên không hoàn vào đây.
    final simulated = _friends.map((f) => f.id).toSet();
    for (final s in split.shares.where((s) => s.isPaid && !simulated.contains(s.payerId))) {
      await _wallet.creditRefund(
        amount: s.amount,
        description: 'Hoàn tiền chia sân ${split.facilityName} • nhóm chưa trả đủ trong 30 phút',
        reference: split.id,
      );
    }
    final holdId = _holds.remove(split.id);
    if (holdId != null) await _facility.releaseHold(holdId);
    final refunded = split.copyWith(refunded: true);
    await _save(refunded);
    return refunded;
  }

  Future<void> _pay(int amount, String description, String reference) async {
    try {
      await _wallet.pay(amount: amount, type: TransactionType.bookingPayment, description: description, reference: reference);
    } on WalletException catch (e) {
      throw SplitPaymentException(e.message);
    }
  }

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<({String id, String name})> _requireUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) throw const SplitPaymentException(SplitPaymentStrings.loginRequired);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (id: json['id'] as String, name: json['fullName'] as String);
  }

  Future<List<SplitPayment>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keySplits);
    if (raw == null) return [];
    final splits = (jsonDecode(raw) as List).map((e) => SplitPayment.fromJson(e as Map<String, dynamic>)).toList();
    return [for (final s in splits) await _settle(s)];
  }

  Future<void> _save(SplitPayment split) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keySplits);
    final splits = raw == null
        ? <SplitPayment>[]
        : (jsonDecode(raw) as List).map((e) => SplitPayment.fromJson(e as Map<String, dynamic>)).toList();
    splits.removeWhere((s) => s.id == split.id);
    splits.add(split);
    await prefs.setString(keySplits, jsonEncode(splits.map((s) => s.toJson()).toList()));
  }

  /// Mã 6 ký tự dễ đọc (bỏ 0/O, 1/I).
  static String _codeFor(DateTime now, int counter) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var n = now.millisecondsSinceEpoch + counter * 7919;
    final buffer = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buffer.write(alphabet[n % alphabet.length]);
      n ~/= alphabet.length;
    }
    return buffer.toString();
  }

  static const _friends = [
    (id: 'u-guest-1', name: 'Phương Linh'),
    (id: 'u-guest-2', name: 'Tuấn Kiệt'),
    (id: 'u-guest-3', name: 'Bảo Ngọc'),
  ];
}
