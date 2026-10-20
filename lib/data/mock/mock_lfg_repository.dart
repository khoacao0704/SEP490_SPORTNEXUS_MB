import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/fair_play_rules.dart';
import '../../core/constants/lfg_rules.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/geo_utils.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/lfg_match.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/lfg_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/wallet_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_facility_data.dart';
import 'mock_review_repository.dart';
import 'mock_wallet_repository.dart';

/// Bản giả lập [LfgRepository].
///
/// - Kèo mẫu sinh theo ngày hôm nay (bắt đầu sau 3–5 ngày) nên lúc nào mở app cũng có kèo để thử.
///   Kèo nào đã thay đổi (có người vào/rời/hủy) hoặc do người dùng tạo thì lưu lại.
/// - Việc BE chạy định kỳ (chốt kèo đủ người / hủy kèo thiếu người tại T−48h và hoàn tiền)
///   được làm lúc đọc dữ liệu.
/// - Tiền cọc trừ/hoàn qua ví giả lập; giữ chỗ Flash Claim lưu trong bộ nhớ, hết hạn sau 10 phút.
class MockLfgRepository implements LfgRepository, SandboxLfgSimulator {
  /// Đổi tên key khi đổi cấu trúc dữ liệu (bỏ cờ locked / lý do HostCancelled) để bỏ dữ liệu cũ.
  static const String keyMatches = 'lfg_matches_v2';

  /// matchId -> {userId: số tiền cọc đã trả qua ví} để biết cần hoàn bao nhiêu cho ai.
  static const String keyPayments = 'lfg_payments';

  final Duration latency;
  final DateTime Function() _now;
  final MockWalletRepository _wallet;
  final ReviewRepository _review;
  final List<_Claim> _claims = [];
  int _counter = 0;

  MockLfgRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
    MockWalletRepository? wallet,
    ReviewRepository? review,
  })  : _now = now ?? DateTime.now,
        _wallet = wallet ?? MockWalletRepository(latency: Duration.zero),
        _review = review ?? MockReviewRepository(latency: Duration.zero);

  @override
  Future<List<LfgFeedItem>> getFeed(LfgFeedQuery query) async {
    await _delay();
    final now = _now();
    final me = await _currentUser();
    final items = (await _all(me?.id))
        .where((m) => m.isClaimable(now) || (me != null && m.isMember(me.id) && m.status(now) == LfgStatus.open))
        .where((m) => m.city == query.city)
        .where((m) => query.district == null || m.district == query.district)
        .where((m) => query.sport == null || m.sport == query.sport)
        .where((m) => query.format == null || m.format == query.format)
        .where((m) => query.courtType == null || m.courtType == query.courtType)
        .map((m) => LfgFeedItem(
              match: m,
              distanceKm: query.userLocation == null ? null : GeoUtils.distanceKm(query.userLocation!, m.location),
            ))
        .toList()
      ..sort((a, b) => a.match.start.compareTo(b.match.start));
    return items;
  }

  @override
  Future<LfgMatch> getMatch(String matchId) async {
    await _delay();
    return _find(matchId, (await _currentUser())?.id);
  }

  @override
  Future<List<LfgMatch>> getMyMatches() async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    bool isPast(LfgMatch m) => const [LfgStatus.cancelled, LfgStatus.completed].contains(m.status(now));

    final mine = (await _all(me.id)).where((m) => m.isMember(me.id)).toList();
    final upcoming = mine.where((m) => !isPast(m)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final past = mine.where(isPast).toList()..sort((a, b) => b.start.compareTo(a.start));
    return [...upcoming, ...past];
  }

  @override
  Future<LfgClaim> claimSlot(String matchId) async {
    await _delay();
    final me = await _requireUser();
    await _ensureFairPlay();
    final now = _now();
    _purgeExpiredClaims();

    final existing = _claims.where((c) => c.matchId == matchId && c.userId == me.id).firstOrNull;
    final match = await _find(matchId, me.id);
    if (existing != null) {
      return LfgClaim(claimId: existing.id, match: match, amount: match.depositPerSlot, expiresAt: existing.expiresAt);
    }
    if (match.isMember(me.id)) throw const LfgException(LfgStrings.alreadyJoined);
    if (match.status(now) != LfgStatus.open || !now.isBefore(match.fillDeadline)) {
      throw const LfgException(LfgStrings.closed);
    }
    if (match.slotsLeft <= 0) throw const LfgException(LfgStrings.full);

    final claim = _Claim('claim-${++_counter}', matchId, me.id, now.add(LfgRules.claimHold));
    _claims.add(claim);
    return LfgClaim(
      claimId: claim.id,
      match: match.copyWith(heldSlots: match.heldSlots + 1),
      amount: match.depositPerSlot,
      expiresAt: claim.expiresAt,
    );
  }

  @override
  Future<LfgMatch> confirmClaim(String claimId) async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    final claim = _claims.where((c) => c.id == claimId && c.userId == me.id).firstOrNull;
    if (claim == null || !claim.expiresAt.isAfter(now)) {
      _claims.removeWhere((c) => c.id == claimId);
      throw const LfgException(LfgStrings.claimExpired);
    }

    final match = await _find(claim.matchId, me.id);
    if (match.isMember(me.id)) throw const LfgException(LfgStrings.alreadyJoined);
    if (match.status(now) != LfgStatus.open || !now.isBefore(match.fillDeadline)) {
      throw const LfgException(LfgStrings.closed);
    }

    final amount = match.depositPerSlot;
    await _pay(amount, TransactionType.flashClaim, 'Cọc Flash Claim ${match.sport.label} • ${match.facilityName}', match.id);
    _claims.remove(claim);

    final updated = match.copyWith(
      members: [
        ...match.members,
        LfgMember(userId: me.id, name: me.name, fairPlayScore: await _myFairPlay(), joinedAt: now),
      ],
      heldSlots: 0,
    );
    await _saveMatch(updated);
    await _recordPayment(match.id, me.id, amount);
    return _withHeldSlots(updated, me.id);
  }

  @override
  Future<void> releaseClaim(String claimId) async {
    _claims.removeWhere((c) => c.id == claimId);
  }

  @override
  Future<LfgMatch> createMatch({
    required SlotHold hold,
    required Facility facility,
    required LfgFormat format,
    String note = '',
  }) async {
    await _delay();
    final me = await _requireUser();
    await _ensureFairPlay();
    final now = _now();

    if (hold.slots.length != 1) throw const LfgException(LfgStrings.singleSlotOnly);
    if (!hold.expiresAt.isAfter(now)) throw const LfgException(LfgStrings.claimExpired);
    final slot = hold.slots.single;
    if (!LfgRules.canCreateFor(slot.start, now)) throw const LfgException(LfgStrings.createWindow);
    if (!LfgFormat.forSport(slot.sport).contains(format)) throw const LfgException(LfgStrings.invalidFormat);

    final deposit = LfgRules.depositPerSlot(slot.price, format.totalSlots);
    final id = 'lfg-u-${now.millisecondsSinceEpoch}-${++_counter}';
    await _pay(deposit, TransactionType.lfgDeposit, 'Cọc tạo kèo ${slot.sport.label} • ${facility.name}', id);

    final match = LfgMatch(
      id: id,
      facilityId: facility.id,
      facilityName: facility.name,
      city: facility.city,
      district: facility.district,
      location: facility.location,
      sport: slot.sport,
      format: format,
      courtType: slot.courtType,
      courtName: slot.courtName,
      start: slot.start,
      end: slot.end,
      courtPrice: slot.price,
      members: [LfgMember(userId: me.id, name: me.name, fairPlayScore: await _myFairPlay(), joinedAt: now, isHost: true)],
      createdAt: now,
      note: note.trim(),
    );
    await _saveMatch(match);
    await _recordPayment(id, me.id, deposit);
    return match;
  }

  // ---- Khác biệt với BE thật ----

  @override
  bool get supportsAreaFilter => true;

  @override
  bool get hostCanLeave => true;

  /// Host chỉ cọc phần của mình.
  @override
  bool get hostPaysCourt => false;

  @override
  int createCost(int courtPrice, LfgFormat format) => LfgRules.depositPerSlot(courtPrice, format.totalSlots);

  /// Bản giả lập: host rời kèo thay cho hủy kèo; không có lời mời.
  @override
  Future<LfgMatch> cancelMatch(String matchId) async => throw const LfgException(LfgStrings.notFound);

  @override
  Future<LfgMatch> acceptInvitation(String matchId) async => throw const LfgException(LfgStrings.notFound);

  @override
  Future<void> declineInvitation(String matchId) async => throw const LfgException(LfgStrings.notFound);

  @override
  Future<String> getTicketCode(LfgMatch match, String userId) async => match.ticketCode(userId);

  @override
  Future<int> leaveMatch(String matchId) async {
    await _delay();
    final me = await _requireUser();
    final match = await _find(matchId, me.id);
    if (!match.isMember(me.id)) throw const LfgException(LfgStrings.notMember);
    _ensureNotEnded(match);
    // Trước T−48h ai cũng rời được (kể cả kèo đã đủ người); sau đó phải gửi yêu cầu hủy.
    if (!_now().isBefore(match.leaveDeadline)) throw const LfgException(LfgStrings.leaveTooLate);

    final payments = await _payments();
    final refund = payments[matchId]?.remove(me.id) ?? match.depositPerSlot;
    await _savePayments(payments);
    await _wallet.creditRefund(
      amount: refund,
      description: 'Hoàn 100% cọc • rời kèo ${match.sport.label} • ${match.facilityName}',
      reference: matchId,
    );

    final rest = match.members.where((m) => m.userId != me.id).toList();
    if (rest.isEmpty) {
      // Người cuối cùng rời: kèo bị hủy (giữ danh sách để còn hiện trong "Kèo của tôi").
      await _saveMatch(match.copyWith(cancelReason: LfgCancelReason.everyoneLeft));
    } else if (match.isHostedBy(me.id)) {
      // Chuyển quyền host cho người vào sớm nhất.
      rest.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      final members = [
        for (var i = 0; i < rest.length; i++)
          LfgMember(
            userId: rest[i].userId,
            name: rest[i].name,
            fairPlayScore: rest[i].fairPlayScore,
            joinedAt: rest[i].joinedAt,
            isHost: i == 0,
          ),
      ];
      await _saveMatch(match.copyWith(members: members));
    } else {
      await _saveMatch(match.copyWith(members: rest));
    }
    return refund;
  }

  @override
  Future<LfgMatch> requestCancel(String matchId) async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    final match = await _find(matchId, me.id);
    if (!match.isMember(me.id)) throw const LfgException(LfgStrings.notMember);
    _ensureNotEnded(match);
    if (match.status(now) != LfgStatus.confirmed) throw const LfgException(LfgStrings.cancelOnlyConfirmed);
    if (!now.isBefore(match.cancelRequestDeadline)) throw const LfgException(LfgStrings.tooLateToCancel);
    if (match.cancelRequest != null) throw const LfgException(LfgStrings.cancelRequestExists);

    final updated = match.copyWith(
      cancelRequest: LfgCancelRequest(requestedBy: me.id, requestedByName: me.name, createdAt: now, approvals: [me.id]),
    );
    return _finishIfAllApproved(updated, me.id);
  }

  @override
  Future<LfgMatch> respondCancel(String matchId, {required bool approve}) async {
    await _delay();
    final me = await _requireUser();
    final match = await _find(matchId, me.id);
    if (!match.isMember(me.id)) throw const LfgException(LfgStrings.notMember);
    final request = match.activeCancelRequest(_now());
    if (request == null) throw const LfgException(LfgStrings.noCancelRequest);
    if (request.hasApproved(me.id)) throw const LfgException(LfgStrings.alreadyResponded);

    if (!approve) {
      final rejected = match.copyWith(clearCancelRequest: true);
      await _saveMatch(rejected);
      return _withHeldSlots(rejected, me.id);
    }
    return _finishIfAllApproved(match.copyWith(cancelRequest: request.approve(me.id)), me.id);
  }

  /// Lưu yêu cầu hủy; nếu mọi thành viên đã đồng ý thì hủy kèo và hoàn 100% cho tất cả.
  Future<LfgMatch> _finishIfAllApproved(LfgMatch match, String? myId) async {
    final request = match.cancelRequest!;
    if (!match.members.every((m) => request.hasApproved(m.userId))) {
      await _saveMatch(match);
      return _withHeldSlots(match, myId);
    }
    final payments = await _payments();
    final paid = payments.remove(match.id) ?? {};
    // Kèo mẫu không có bản ghi thanh toán: vẫn hoàn phần của người dùng hiện tại.
    if (myId != null && match.isMember(myId)) paid.putIfAbsent(myId, () => match.depositPerSlot);
    for (final amount in paid.values) {
      await _wallet.creditRefund(
        amount: amount,
        description: 'Hoàn 100% cọc • cả kèo đồng ý hủy ${match.sport.label} • ${match.facilityName}',
        reference: match.id,
      );
    }
    await _savePayments(payments);
    final cancelled = match.copyWith(cancelReason: LfgCancelReason.mutualAgreement, clearCancelRequest: true);
    await _saveMatch(cancelled);
    return _withHeldSlots(cancelled, myId);
  }

  @override
  Future<LfgMatch> simulatePlayerJoined(String matchId) async {
    final me = await _currentUser();
    final match = await _find(matchId, me?.id);
    if (match.status(_now()) != LfgStatus.open || match.isFull) throw const LfgException(LfgStrings.full);

    final taken = match.members.map((m) => m.userId).toSet();
    final guest = _guestPool.firstWhere((g) => !taken.contains(g.id));
    final updated = match.copyWith(members: [
      ...match.members,
      LfgMember(
        userId: guest.id,
        name: match.format.isTeam ? guest.team : guest.name,
        fairPlayScore: guest.fairPlay,
        joinedAt: _now(),
      ),
    ]);
    await _saveMatch(updated);
    return _withHeldSlots(updated, me?.id);
  }

  @override
  Future<LfgMatch> simulateOthersRespond(String matchId, {required bool approve}) async {
    final me = await _currentUser();
    final match = await _find(matchId, me?.id);
    final request = match.activeCancelRequest(_now());
    if (request == null) throw const LfgException(LfgStrings.noCancelRequest);
    if (!approve) {
      final rejected = match.copyWith(clearCancelRequest: true);
      await _saveMatch(rejected);
      return _withHeldSlots(rejected, me?.id);
    }
    var approved = request;
    for (final m in match.members) {
      if (m.userId != me?.id) approved = approved.approve(m.userId);
    }
    return _finishIfAllApproved(match.copyWith(cancelRequest: approved), me?.id);
  }

  // ---------------- Nội bộ ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<({String id, String name})?> _currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (id: json['id'] as String, name: json['fullName'] as String);
  }

  Future<({String id, String name})> _requireUser() async =>
      await _currentUser() ?? (throw const LfgException(LfgStrings.loginRequired));

  Future<int> _myFairPlay() async => (await _review.getFairPlay()).score;

  Future<void> _ensureFairPlay() async {
    if (!FairPlayRules.canJoinLfg(await _myFairPlay())) throw const LfgException(LfgStrings.blocked);
  }

  void _ensureNotEnded(LfgMatch match) {
    final status = match.status(_now());
    if (status == LfgStatus.cancelled || status == LfgStatus.completed) {
      throw const LfgException(LfgStrings.alreadyEnded);
    }
  }

  Future<void> _pay(int amount, TransactionType type, String description, String reference) async {
    try {
      await _wallet.pay(amount: amount, type: type, description: description, reference: reference);
    } on WalletException catch (e) {
      throw LfgException(e.message);
    }
  }

  void _purgeExpiredClaims() {
    final now = _now();
    _claims.removeWhere((c) => !c.expiresAt.isAfter(now));
  }

  LfgMatch _withHeldSlots(LfgMatch match, String? myId) {
    final held = _claims.where((c) => c.matchId == match.id && c.userId != myId).length;
    return match.copyWith(heldSlots: held);
  }

  Future<LfgMatch> _find(String matchId, String? myId) async {
    final match = (await _all(myId)).where((m) => m.id == matchId).firstOrNull;
    return match ?? (throw const LfgException(LfgStrings.notFound));
  }

  /// Kèo mẫu + kèo đã lưu, đã chạy bước chốt/hủy T−48h, kèm số chỗ người khác đang giữ.
  Future<List<LfgMatch>> _all(String? myId) async {
    _purgeExpiredClaims();
    final stored = await _storedMatches();
    final merged = {for (final m in _seedMatches()) m.id: m, ...stored};

    final settled = <LfgMatch>[];
    for (final match in merged.values) {
      final result = await _settle(match);
      if (!identical(result, match) && stored.containsKey(match.id)) await _saveMatch(result);
      settled.add(_withHeldSlots(result, myId));
    }
    return settled;
  }

  /// Việc BE làm tại T−48h: đủ người thì chốt, thiếu người thì hủy và hoàn 100% cho tất cả.
  Future<LfgMatch> _settle(LfgMatch match) async {
    if (match.cancelReason != null) return match;
    // Tới T−24h mà chưa đủ tất cả đồng ý: yêu cầu hủy hết hạn, kèo vẫn diễn ra.
    if (match.cancelRequest != null && !_now().isBefore(match.cancelRequestDeadline)) {
      return match.copyWith(clearCancelRequest: true);
    }
    if (match.isFull || _now().isBefore(match.fillDeadline)) return match;

    final payments = await _payments();
    final paid = payments.remove(match.id) ?? {};
    for (final amount in paid.values) {
      await _wallet.creditRefund(
        amount: amount,
        description: 'Hoàn 100% cọc • kèo ${match.sport.label} • ${match.facilityName} không đủ người',
        reference: match.id,
      );
    }
    if (paid.isNotEmpty) await _savePayments(payments);
    return match.copyWith(cancelReason: LfgCancelReason.notEnoughPlayers);
  }

  Future<Map<String, LfgMatch>> _storedMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyMatches);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((id, json) => MapEntry(id, LfgMatch.fromJson(json as Map<String, dynamic>)));
  }

  Future<void> _saveMatch(LfgMatch match) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = await _storedMatches();
    stored[match.id] = match.copyWith(heldSlots: 0);
    await prefs.setString(keyMatches, jsonEncode(stored.map((id, m) => MapEntry(id, m.toJson()))));
  }

  Future<Map<String, Map<String, int>>> _payments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyPayments);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((matchId, byUser) => MapEntry(matchId, Map<String, int>.from(byUser as Map)));
  }

  Future<void> _savePayments(Map<String, Map<String, int>> payments) async {
    final prefs = await SharedPreferences.getInstance();
    payments.removeWhere((_, byUser) => byUser.isEmpty);
    await prefs.setString(keyPayments, jsonEncode(payments));
  }

  Future<void> _recordPayment(String matchId, String userId, int amount) async {
    final payments = await _payments();
    payments.putIfAbsent(matchId, () => {})[userId] = amount;
    await _savePayments(payments);
  }

  // ---------------- Dữ liệu mẫu ----------------

  static const _guestPool = [
    (id: 'u-guest-1', name: 'Phương Linh', team: 'Đội Phương Linh', fairPlay: 97),
    (id: 'u-guest-2', name: 'Tuấn Kiệt', team: 'Kiệt FC', fairPlay: 89),
    (id: 'u-guest-3', name: 'Bảo Ngọc', team: 'Ngọc Team', fairPlay: 100),
    (id: 'u-guest-4', name: 'Gia Huy', team: 'Huy United', fairPlay: 83),
  ];

  /// Kèo mẫu của ngày hôm nay; id gắn theo ngày nên mỗi ngày có một bộ mới.
  List<LfgMatch> _seedMatches() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final dayKey = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final createdAt = today.subtract(const Duration(hours: 3));
    final facilities = {for (final f in MockFacilityData.facilities) f.id: f};

    LfgMember member(String id, String name, int fp, {bool host = false}) =>
        LfgMember(userId: id, name: name, fairPlayScore: fp, joinedAt: createdAt, isHost: host);

    LfgMatch seed(int n, String facilityId, Sport sport, LfgFormat format, int dayOffset, int hour,
        List<LfgMember> members, {String note = '', CourtType courtType = CourtType.standard}) {
      final f = facilities[facilityId]!;
      final start = today.add(Duration(days: dayOffset, hours: hour));
      final base = f.offeringFor(sport, courtType: courtType)!.priceFrom;
      return LfgMatch(
        id: 'lfg-$dayKey-$n',
        facilityId: f.id,
        facilityName: f.name,
        city: f.city,
        district: f.district,
        location: f.location,
        sport: sport,
        format: format,
        courtType: courtType,
        courtName: 'Sân ${n % f.offeringFor(sport, courtType: courtType)!.courtCount + 1}',
        start: start,
        end: start.add(Duration(minutes: sport == Sport.football ? 90 : 60)),
        // Giờ cao điểm (từ 17:00) giá x1.4, giống bản giả lập khung giờ.
        courtPrice: hour >= 17 ? ((base * 1.4) / 10000).round() * 10000 : base,
        members: members,
        createdAt: createdAt,
        note: note,
      );
    }

    return [
      seed(1, 'f-hcm-thientrieu', Sport.badminton, LfgFormat.doubles, 3, 19, [
        member('u-minhtuan', 'Minh Tuấn', 95, host: true),
        member('u-hoangnam', 'Hoàng Nam', 100),
      ], note: 'Trình độ trung bình, đánh vui là chính.'),
      seed(2, 'f-hcm-eco-q7', Sport.pickleball, LfgFormat.singles, 3, 18, [
        member('u-quocbao', 'Quốc Bảo', 88, host: true),
      ]),
      seed(3, 'f-hcm-govap', Sport.badminton, LfgFormat.doubles, 3, 20, [
        member('u-ductri', 'Đức Trí', 72, host: true),
        member('u-player-001', 'Khoa Cao', 93),
        member('u-lananh', 'Lan Anh', 85),
      ]),
      seed(4, 'f-hcm-hoalu', Sport.football, LfgFormat.teamVsTeam, 4, 19, [
        member('u-fcsaigon', 'FC Sài Gòn', 98, host: true),
      ], note: 'Cần 1 đội giao lưu. Mặc áo tối màu.', courtType: CourtType.football7),
      seed(5, 'f-hcm-chuvanan', Sport.basketball, LfgFormat.teamVsTeam, 4, 17, [
        member('u-ballers', 'Ballers Bình Thạnh', 90, host: true),
      ], courtType: CourtType.basketballFull),
      seed(6, 'f-hcm-kyhoa', Sport.tennis, LfgFormat.singles, 5, 6, [
        member('u-thutrang', 'Thu Trang', 100, host: true),
      ], note: 'Đánh đơn tập luyện, trình độ khá.'),
      seed(7, 'f-hcm-thaodien', Sport.pickleball, LfgFormat.doubles, 5, 8, [
        member('u-lananh', 'Lan Anh', 85, host: true),
      ]),
      seed(8, 'f-hn-caugiay', Sport.badminton, LfgFormat.doubles, 4, 19, [
        member('u-ngocha', 'Ngọc Hà', 94, host: true),
        member('u-vietanh', 'Việt Anh', 90),
      ]),
      // Kèo đã chốt (đủ người) có Khoa Cao: thử gửi yêu cầu hủy.
      seed(9, 'f-hcm-thaodien', Sport.pickleball, LfgFormat.doubles, 4, 18, [
        member('u-hoangnam', 'Hoàng Nam', 100, host: true),
        member('u-player-001', 'Khoa Cao', 93),
        member('u-lananh', 'Lan Anh', 85),
        member('u-quocbao', 'Quốc Bảo', 88),
      ]),
      // Kèo đã chốt, host đã gửi yêu cầu hủy: Khoa Cao cần đồng ý / từ chối.
      seed(10, 'f-hcm-kyhoa', Sport.tennis, LfgFormat.singles, 3, 7, [
        member('u-thutrang', 'Thu Trang', 100, host: true),
        member('u-player-001', 'Khoa Cao', 93),
      ]).copyWith(
        cancelRequest: LfgCancelRequest(
          requestedBy: 'u-thutrang',
          requestedByName: 'Thu Trang',
          createdAt: createdAt.add(const Duration(hours: 1)),
          approvals: const ['u-thutrang'],
        ),
      ),
    ];
  }
}

class _Claim {
  final String id;
  final String matchId;
  final String userId;
  final DateTime expiresAt;

  _Claim(this.id, this.matchId, this.userId, this.expiresAt);
}
