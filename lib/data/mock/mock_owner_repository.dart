import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/owner_rules.dart';
import '../../core/strings/owner_facility_strings.dart';
import '../../core/strings/owner_finance_strings.dart';
import '../../core/strings/owner_review_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../models/court_session.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';
import '../../models/owner_facility.dart';
import '../../models/owner_finance.dart';
import '../../models/sport.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/owner_repository.dart';
import '../repositories/wallet_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_owner_facility_data.dart';
import 'mock_owner_finance_data.dart';
import 'mock_owner_review_data.dart';
import 'mock_wallet_repository.dart';

/// Bản giả lập [OwnerRepository].
///
/// - Chủ sân demo có Thiên Triều, Hoa Lư (đã duyệt), một hồ sơ chờ duyệt và một hồ sơ bị từ chối.
/// - Lượt sân mẫu tạo theo giờ hiện tại (đủ các trạng thái). Tất cả chỉ lưu trong bộ nhớ.
/// - Admin duyệt trên Web nên bản giả lập không tự duyệt: hồ sơ mới nộp nằm ở "Chờ duyệt".
/// - Check-out giải ngân và tiền phạt vắng mặt cộng vào ví giả lập của Chủ sân ([wallet]).
/// - Chưa nối với phía Player (tìm sân / đặt sân): khi có BE, cả hai cùng đọc một nguồn.
class MockOwnerRepository implements OwnerRepository {
  final Duration latency;
  final DateTime Function() _now;
  List<CourtSession>? _sessions;

  /// ownerId -> cơ sở của chủ sân đó.
  final Map<String, List<OwnerFacility>> _facilities = {};
  int _counter = 0;

  static const String ownerWalletPrefix = 'owner_';

  /// Ví giả lập của Chủ sân (tách với ví người chơi).
  final MockWalletRepository wallet;
  List<RevenueItem>? _revenue;

  /// Lượt vắng mặt đã ghi nhận tiền phạt.
  final Set<String> _settledNoShows = {};

  /// billId -> thời điểm trả.
  Map<String, DateTime>? _paidFees;
  List<FacilityReview>? _reviews;

  MockOwnerRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
    MockWalletRepository? wallet,
  })  : _now = now ?? DateTime.now,
        wallet = wallet ??
            MockWalletRepository(latency: Duration.zero, now: now, keyPrefix: ownerWalletPrefix, initialBalance: 3200000);

  @override
  Future<List<Facility>> getMyFacilities() async {
    await _delay();
    return (await _mine()).where((f) => f.isApproved).map((f) => f.toFacility()).toList();
  }

  @override
  Future<List<CourtSession>> getSessions({required DateTime day, String? facilityId}) async {
    await _delay();
    final ids = await _myFacilityIds();
    await _settleNoShows(ids);
    return _all()
        .where((s) => ids.contains(s.facilityId))
        .where((s) => facilityId == null || s.facilityId == facilityId)
        .where((s) => s.start.year == day.year && s.start.month == day.month && s.start.day == day.day)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<CourtSession> getSession(String sessionId) async {
    await _delay();
    return _find(sessionId, await _myFacilityIds());
  }

  @override
  Future<TicketLookup> lookupTicket(String code) async {
    await _delay();
    final ids = await _myFacilityIds();
    final normalized = code.trim().toUpperCase();
    for (final s in _all().where((s) => ids.contains(s.facilityId))) {
      for (final p in s.players) {
        if (p.ticketCode.toUpperCase() == normalized) return TicketLookup(session: s, player: p);
      }
    }
    throw const OwnerException(OwnerStrings.ticketNotFound);
  }

  @override
  Future<CourtSession> checkIn({required String sessionId, required String userId}) async {
    await _delay();
    final session = _find(sessionId, await _myFacilityIds());
    final now = _now();
    final player = session.players.where((p) => p.userId == userId).firstOrNull;
    if (player == null) throw const OwnerException(OwnerStrings.ticketNotFound);

    final block = session.checkInBlock(player, now);
    if (block != null) throw OwnerException(OwnerStrings.checkInBlocked(session, block));

    // Sân con do người chơi chọn lúc đặt: check-in chỉ ghi nhận giờ vào sân.
    final updated = session.copyWith(
      players: [
        for (final p in session.players) p.userId == userId ? p.copyWith(checkedInAt: now) : p,
      ],
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<CourtSession> checkOut(String sessionId) async {
    await _delay();
    final session = _find(sessionId, await _myFacilityIds());
    final now = _now();
    final status = session.status(now);
    if (status == SessionStatus.cancelled) throw const OwnerException(OwnerStrings.sessionCancelled);
    if (status == SessionStatus.completed) throw const OwnerException(OwnerStrings.sessionCompleted);
    if (!session.canCheckOut(now)) throw const OwnerException(OwnerStrings.checkOutNeedsCheckIn);

    final updated = session.copyWith(checkedOutAt: now);
    _replace(updated);
    _revenueItems().add(_courtFeeItem(updated));
    if (updated.paidViaApp > 0) {
      await wallet.credit(
        type: TransactionType.escrowRelease,
        amount: updated.paidViaApp,
        description: 'Giải ngân ${updated.facilityName} • ${updated.sportLabel}',
        reference: updated.id,
      );
    }
    return updated;
  }

  // ---------------- Quản lý cơ sở & sân ----------------

  @override
  Future<List<OwnerFacility>> getOwnerFacilities() async {
    await _delay();
    return List.of(await _mine());
  }

  @override
  Future<OwnerFacility> getOwnerFacility(String facilityId) async {
    await _delay();
    return _facility(await _mine(), facilityId);
  }

  @override
  Future<OwnerFacility> submitFacility(FacilitySubmission submission) async {
    await _delay();
    _validateSubmission(submission);
    final mine = await _mine();
    final created = OwnerFacility(
      id: 'f-own-${_now().millisecondsSinceEpoch}-${++_counter}',
      status: ApprovalStatus.pending,
      profile: submission.profile,
      operations: submission.operations,
      courts: [for (final c in submission.courts) CourtConfig(sport: c.sport, courtType: c.courtType, courtCount: c.courtCount)],
      submittedAt: _now(),
    );
    mine.insert(0, created);
    return created;
  }

  @override
  Future<OwnerFacility> resubmitFacility(String facilityId, FacilitySubmission submission) async {
    await _delay();
    final mine = await _mine();
    final f = _facility(mine, facilityId);
    if (f.status != ApprovalStatus.rejected) throw const OwnerException(OwnerFacilityStrings.notRejected);
    _validateSubmission(submission);
    return _save(
      mine,
      f.copyWith(
        status: ApprovalStatus.pending,
        profile: submission.profile,
        operations: submission.operations,
        courts: [for (final c in submission.courts) CourtConfig(sport: c.sport, courtType: c.courtType, courtCount: c.courtCount)],
        submittedAt: _now(),
        clearRejectReason: true,
      ),
    );
  }

  @override
  Future<OwnerFacility> requestProfileChange(String facilityId, FacilityProfile profile) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    if (f.hasPendingChange) throw const OwnerException(OwnerFacilityStrings.changeAlreadyPending);
    _validateProfile(profile);
    return _save(
      mine,
      f.copyWith(change: ProfileChange(profile: profile, status: ApprovalStatus.pending, submittedAt: _now())),
    );
  }

  @override
  Future<OwnerFacility> updateOperations(String facilityId, FacilityOperations operations) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    _validateOperations(operations);
    // Giờ mở cửa mới phải còn chứa giờ cao điểm của các loại sân đã cài giá.
    for (final c in f.courts) {
      final p = c.pricing;
      if (p != null && (p.peakStart < operations.openMinutes || p.peakEnd > operations.closeMinutes)) {
        throw const OwnerException(OwnerFacilityStrings.invalidPeak);
      }
    }
    return _save(mine, f.copyWith(operations: operations));
  }

  @override
  Future<OwnerFacility> saveCourt(String facilityId, CourtConfig court) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    if (f.courtFor(court.sport, court.courtType)?.isLocked ?? false) {
      throw const OwnerException(OwnerFacilityStrings.courtLocked);
    }
    if (court.courtCount < 1) throw const OwnerException(OwnerFacilityStrings.invalidCourtCount);
    final p = court.pricing;
    if (p != null) {
      if ([p.weekdayPrice, p.weekdayPeakPrice, p.weekendPrice, p.weekendPeakPrice].any((x) => x <= 0)) {
        throw const OwnerException(OwnerFacilityStrings.invalidPrice);
      }
      if (p.peakEnd <= p.peakStart ||
          p.peakStart < f.operations.openMinutes ||
          p.peakEnd > f.operations.closeMinutes) {
        throw const OwnerException(OwnerFacilityStrings.invalidPeak);
      }
    }

    // Không giảm số sân con dưới sân con đang được lượt sân sắp tới / đang chơi sử dụng.
    final now = _now();
    final highestInUse = _all()
        .where((s) =>
            s.facilityId == facilityId &&
            s.sport == court.sport &&
            s.courtType == court.courtType &&
            _stillActive(s, now))
        .map((s) => int.tryParse(s.assignedCourt.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    if (court.courtCount < highestInUse) throw const OwnerException(OwnerFacilityStrings.courtInUse);

    final exists = f.courtFor(court.sport, court.courtType) != null;
    return _save(
      mine,
      f.copyWith(
        courts: exists
            ? [for (final c in f.courts) c.sameKind(court.sport, court.courtType) ? court : c]
            : [...f.courts, court],
      ),
    );
  }

  @override
  Future<OwnerFacility> lockCourt(String facilityId, Sport sport, CourtType courtType) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    final court = f.courtFor(sport, courtType);
    if (court == null) throw const OwnerException(OwnerFacilityStrings.notFound);
    if (court.isLocked) throw const OwnerException(OwnerFacilityStrings.courtLocked);

    final now = _now();
    final upcoming = _all()
        .where((s) =>
            s.facilityId == facilityId &&
            s.sport == sport &&
            s.courtType == courtType &&
            _stillActive(s, now))
        .length;
    if (upcoming > 0) throw OwnerException(OwnerFacilityStrings.lockBlocked(upcoming));

    return _save(
      mine,
      f.copyWith(courts: [for (final c in f.courts) c.sameKind(sport, courtType) ? c.copyWith(lockedAt: now) : c]),
    );
  }

  @override
  Future<OwnerFacility> unlockCourt(String facilityId, Sport sport, CourtType courtType) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    final court = f.courtFor(sport, courtType);
    if (court == null) throw const OwnerException(OwnerFacilityStrings.notFound);
    if (!court.isLocked) throw const OwnerException(OwnerFacilityStrings.notLocked);
    return _save(
      mine,
      f.copyWith(courts: [for (final c in f.courts) c.sameKind(sport, courtType) ? c.copyWith(unlock: true) : c]),
    );
  }

  @override
  Future<OwnerFacility> addClosure(
    String facilityId, {
    Sport? sport,
    CourtType? courtType,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    if (reason.trim().isEmpty || to.isBefore(from)) throw const OwnerException(OwnerFacilityStrings.missingInfo);

    final closure = FacilityClosure(
      id: 'cl-${_now().millisecondsSinceEpoch}-${++_counter}',
      sport: sport,
      courtType: sport == null ? null : (courtType ?? CourtType.standard),
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      reason: reason.trim(),
    );
    // Chặn nếu trong khoảng đó đã có lượt đặt còn hiệu lực.
    final booked = _all()
        .where((s) =>
            s.facilityId == facilityId &&
            s.cancelledAt == null &&
            s.checkedOutAt == null &&
            closure.blocks(s.sport, s.courtType, s.start, s.end))
        .length;
    if (booked > 0) throw OwnerException(OwnerFacilityStrings.closureBlocked(booked));
    return _save(mine, f.copyWith(closures: [...f.closures, closure]));
  }

  @override
  Future<OwnerFacility> removeClosure(String facilityId, String closureId) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    return _save(mine, f.copyWith(closures: f.closures.where((c) => c.id != closureId).toList()));
  }

  // ---------------- Doanh thu & phí duy trì ----------------

  @override
  Future<MonthlyRevenue> getMonthlyRevenue(DateTime month, {String? facilityId}) async {
    await _delay();
    final ids = await _myFacilityIds();
    await _settleNoShows(ids);
    return MonthlyRevenue(
      month: DateTime(month.year, month.month, 1),
      items: _revenueItems()
          .where((i) => ids.contains(i.facilityId) && (facilityId == null || i.facilityId == facilityId))
          .where((i) => i.date.year == month.year && i.date.month == month.month)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  @override
  Future<List<ListingFeeBill>> getListingFees() async {
    await _delay();
    return _bills(await _myFacilityIds());
  }

  @override
  Future<ListingFeeBill> payListingFee(String billId) async {
    await _delay();
    final bill = _bills(await _myFacilityIds()).where((b) => b.id == billId).firstOrNull;
    if (bill == null) throw const OwnerException(OwnerFinanceStrings.billNotFound);
    if (bill.paidAt != null) throw const OwnerException(OwnerFinanceStrings.alreadyPaid);
    try {
      await wallet.pay(
        amount: bill.amount,
        type: TransactionType.listingFee,
        description: 'Phí duy trì ${OwnerFinanceStrings.monthShort(bill.month)}',
        reference: bill.id,
      );
    } on WalletException catch (e) {
      throw OwnerException(e.message);
    }
    final now = _now();
    _fees()[bill.id] = now;
    return bill.copyWith(paidAt: now);
  }

  /// Lệ phí giải đấu về ví Chủ sân khi giải kết thúc và tính vào doanh thu.
  /// Chỉ bản giả lập giải đấu gọi; bản thật do BE tự làm.
  Future<void> recordTournamentPayout({
    required String tournamentId,
    required String tournamentName,
    required String facilityId,
    required String facilityName,
    required int amount,
  }) async {
    if (amount <= 0) return;
    _revenueItems().add(RevenueItem(
      id: 'rv-tour-$tournamentId',
      date: _now(),
      facilityId: facilityId,
      facilityName: facilityName,
      kind: RevenueKind.tournamentFee,
      amount: amount,
      viaApp: amount,
      description: 'Lệ phí giải $tournamentName',
    ));
    await wallet.credit(
      type: TransactionType.escrowRelease,
      amount: amount,
      description: 'Lệ phí giải $tournamentName',
      reference: tournamentId,
    );
  }

  // ---------------- Đánh giá ----------------

  @override
  Future<List<FacilityReview>> getFacilityReviews({String? facilityId}) async {
    await _delay();
    final ids = await _myFacilityIds();
    return _allReviews()
        .where((r) => ids.contains(r.facilityId) && (facilityId == null || r.facilityId == facilityId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<FacilityReview> replyToReview(String reviewId, String text) async {
    await _delay();
    final review = await _findReview(reviewId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const OwnerException(OwnerReviewStrings.replyEmpty);
    if (!review.canReply) throw const OwnerException(OwnerReviewStrings.cannotReplyHidden);
    final cut = trimmed.length > OwnerReviewStrings.replyMaxLength
        ? trimmed.substring(0, OwnerReviewStrings.replyMaxLength)
        : trimmed;
    return _saveReview(review.copyWith(reply: ReviewReply(text: cut, updatedAt: _now())));
  }

  @override
  Future<FacilityReview> reportReview(String reviewId, ReportReason reason, {String note = ''}) async {
    await _delay();
    final review = await _findReview(reviewId);
    if (!review.canReport) throw const OwnerException(OwnerReviewStrings.alreadyReported);
    return _saveReview(
      review.copyWith(report: ReviewReport(reason: reason, note: note.trim(), createdAt: _now())),
    );
  }

  List<FacilityReview> _allReviews() => _reviews ??= MockOwnerReviewData.seed(_now());

  Future<FacilityReview> _findReview(String reviewId) async {
    final ids = await _myFacilityIds();
    final r = _allReviews().where((r) => r.id == reviewId && ids.contains(r.facilityId)).firstOrNull;
    if (r == null) throw const OwnerException(OwnerReviewStrings.notFound);
    return r;
  }

  FacilityReview _saveReview(FacilityReview updated) {
    final list = _allReviews();
    list[list.indexWhere((r) => r.id == updated.id)] = updated;
    return updated;
  }

  List<RevenueItem> _revenueItems() => _revenue ??= [
        ...MockOwnerFinanceData.seed(_now()),
        for (final s in _all().where((s) => s.checkedOutAt != null)) _courtFeeItem(s),
      ];

  /// Mặc định: phí tháng đầu tiên đã trả, các tháng sau chưa trả.
  Map<String, DateTime> _fees() {
    final first = MockOwnerFinanceData.firstMonth(_now());
    return _paidFees ??= {_billId(first): DateTime(first.year, first.month + 1, 3, 9)};
  }

  static String _billId(DateTime month) => 'fee-${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// Hóa đơn cho các tháng đã kết thúc, mới nhất trước.
  List<ListingFeeBill> _bills(Set<String> facilityIds) {
    final now = _now();
    final current = DateTime(now.year, now.month, 1);
    final items = _revenueItems().where((i) => facilityIds.contains(i.facilityId)).toList();
    if (items.isEmpty) return [];
    final earliest = items.map((i) => i.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final bills = <ListingFeeBill>[];
    for (var m = DateTime(earliest.year, earliest.month, 1); m.isBefore(current); m = DateTime(m.year, m.month + 1, 1)) {
      final revenue = items
          .where((i) => i.date.year == m.year && i.date.month == m.month)
          .fold(0, (sum, i) => sum + i.amount);
      final id = _billId(m);
      bills.add(ListingFeeBill(
        id: id,
        month: m,
        revenue: revenue,
        amount: ListingFeeRules.feeFor(revenue),
        paidAt: _fees()[id],
      ));
    }
    return bills.reversed.toList();
  }

  RevenueItem _courtFeeItem(CourtSession s) => RevenueItem(
        id: 'rv-${s.id}',
        date: s.start,
        facilityId: s.facilityId,
        facilityName: s.facilityName,
        kind: RevenueKind.courtFee,
        amount: s.totalPrice,
        viaApp: s.paidViaApp,
        description: s.sportLabel,
      );

  /// Vắng mặt: tiền đã trả qua app về chủ sân như tiền phạt (BE tự làm khi đánh vắng).
  Future<void> _settleNoShows(Set<String> facilityIds) async {
    final now = _now();
    for (final s in _all()) {
      if (!facilityIds.contains(s.facilityId) || _settledNoShows.contains(s.id)) continue;
      if (s.status(now) != SessionStatus.noShow || s.paidViaApp <= 0) continue;
      _settledNoShows.add(s.id);
      _revenueItems().add(RevenueItem(
        id: 'rv-noshow-${s.id}',
        date: s.start,
        facilityId: s.facilityId,
        facilityName: s.facilityName,
        kind: RevenueKind.penalty,
        amount: s.paidViaApp,
        viaApp: s.paidViaApp,
        description: 'Vắng mặt • ${s.sportLabel}',
      ));
      await wallet.credit(
        type: TransactionType.penaltyIncome,
        amount: s.paidViaApp,
        description: 'Vắng mặt ${s.facilityName} • ${s.sportLabel}',
        reference: s.id,
      );
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<String> _requireOwnerId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) throw const OwnerException(OwnerStrings.loginRequired);
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
  }

  /// Cơ sở của chủ sân đang đăng nhập (danh sách sửa trực tiếp được).
  Future<List<OwnerFacility>> _mine() async {
    final ownerId = await _requireOwnerId();
    return _facilities.putIfAbsent(
      ownerId,
      () => ownerId == MockAuthRepository.ownerId ? MockOwnerFacilityData.seed(_now()) : [],
    );
  }

  /// Lượt sân chỉ thuộc cơ sở đã duyệt.
  Future<Set<String>> _myFacilityIds() async =>
      (await _mine()).where((f) => f.isApproved).map((f) => f.id).toSet();

  OwnerFacility _facility(List<OwnerFacility> mine, String id) {
    final f = mine.where((f) => f.id == id).firstOrNull;
    if (f == null) throw const OwnerException(OwnerFacilityStrings.notFound);
    return f;
  }

  OwnerFacility _requireApproved(List<OwnerFacility> mine, String id) {
    final f = _facility(mine, id);
    if (!f.isApproved) throw const OwnerException(OwnerFacilityStrings.notApproved);
    return f;
  }

  OwnerFacility _save(List<OwnerFacility> mine, OwnerFacility updated) {
    mine[mine.indexWhere((f) => f.id == updated.id)] = updated;
    return updated;
  }

  void _validateProfile(FacilityProfile p) {
    if ([p.name, p.city, p.ward, p.address, p.licenseNumber].any((s) => s.trim().isEmpty)) {
      throw const OwnerException(OwnerFacilityStrings.missingInfo);
    }
    if (p.licenseImages.isEmpty) throw const OwnerException(OwnerFacilityStrings.missingLicenseImage);
  }

  void _validateOperations(FacilityOperations o) {
    if (o.phone.trim().isEmpty) throw const OwnerException(OwnerFacilityStrings.missingInfo);
    if (o.closeMinutes <= o.openMinutes) throw const OwnerException(OwnerFacilityStrings.invalidHours);
    if (o.images.isEmpty) throw const OwnerException(OwnerFacilityStrings.missingPhoto);
  }

  void _validateSubmission(FacilitySubmission s) {
    _validateProfile(s.profile);
    _validateOperations(s.operations);
    if (s.courts.isEmpty) throw const OwnerException(OwnerFacilityStrings.missingCourt);
    if (s.courts.any((c) => c.courtCount < 1)) throw const OwnerException(OwnerFacilityStrings.invalidCourtCount);
    final kinds = s.courts.map((c) => '${c.sport.apiValue}/${c.courtType.apiValue}').toSet();
    if (kinds.length != s.courts.length) throw const OwnerException(OwnerFacilityStrings.duplicateCourt);
  }

  /// Lượt sân còn giữ sân: chưa hủy, chưa check-out và chưa kết thúc (hoặc đã check-in, chờ check-out).
  static bool _stillActive(CourtSession s, DateTime now) =>
      s.cancelledAt == null && s.checkedOutAt == null && (s.end.isAfter(now) || s.checkedInCount > 0);

  CourtSession _find(String sessionId, Set<String> myFacilityIds) {
    final s = _all().where((s) => s.id == sessionId && myFacilityIds.contains(s.facilityId)).firstOrNull;
    if (s == null) throw const OwnerException(OwnerStrings.ticketNotFound);
    return s;
  }

  void _replace(CourtSession updated) {
    final list = _all();
    list[list.indexWhere((s) => s.id == updated.id)] = updated;
  }

  List<CourtSession> _all() => _sessions ??= _seed(_now());

  /// Lượt sân mẫu quanh giờ hiện tại để có đủ trạng thái khi demo.
  static List<CourtSession> _seed(DateTime now) {
    DateTime at(int minutes) => now.add(Duration(minutes: minutes));
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    const tt = 'f-hcm-thientrieu';
    const ttName = 'Sân Cầu Lông Thiên Triều';
    const hl = 'f-hcm-hoalu';
    const hlName = 'Sân Bóng Hoa Lư';

    SessionPlayer bookingPlayer(String id, String name, {DateTime? checkedInAt}) =>
        SessionPlayer(userId: 'u-$id', name: name, ticketCode: 'SPN-BK-$id', checkedInAt: checkedInAt);
    SessionPlayer lfgPlayer(String match, String user, String name, {DateTime? checkedInAt}) =>
        SessionPlayer(userId: user, name: name, ticketCode: 'SPN-LFG-$match-$user', checkedInAt: checkedInAt);

    return [
      // Đã check-out sáng nay.
      CourtSession(
        id: 'OW1005',
        kind: SessionKind.booking,
        facilityId: tt,
        facilityName: ttName,
        sport: Sport.pickleball,
        start: at(-240),
        end: at(-180),
        totalPrice: 150000,
        paidViaApp: 150000,
        players: [bookingPlayer('OW1005', 'Lê Hoàng Nam', checkedInAt: at(-245))],
        assignedCourt: 'Sân 1',
        checkedOutAt: at(-178),
      ),
      // Hết giờ, đang chờ chủ sân check-out.
      CourtSession(
        id: 'OW1003',
        kind: SessionKind.booking,
        facilityId: hl,
        facilityName: hlName,
        sport: Sport.football,
        courtType: CourtType.football7,
        start: at(-120),
        end: at(-30),
        totalPrice: 800000,
        paidViaApp: 800000,
        players: [bookingPlayer('OW1003', 'Trần Quốc Bảo', checkedInAt: at(-125))],
        assignedCourt: 'Sân 1',
      ),
      // Quá T+15 không ai check-in: hệ thống đánh vắng.
      CourtSession(
        id: 'OW1004',
        kind: SessionKind.booking,
        facilityId: hl,
        facilityName: hlName,
        sport: Sport.football,
        courtType: CourtType.football5,
        start: at(-60),
        end: at(0),
        totalPrice: 500000,
        paidViaApp: 125000,
        players: [bookingPlayer('OW1004', 'Phạm Đức Huy')],
        assignedCourt: 'Sân 2',
      ),
      // Kèo LFG đang chơi: 3/4 check-in, 1 người vắng.
      CourtSession(
        id: 'LFGOW1',
        kind: SessionKind.lfg,
        facilityId: tt,
        facilityName: ttName,
        sport: Sport.badminton,
        start: at(-30),
        end: at(30),
        totalPrice: 160000,
        paidViaApp: 160000,
        players: [
          lfgPlayer('LFGOW1', 'u-lfg-11', 'Võ Thanh Tùng', checkedInAt: at(-35)),
          lfgPlayer('LFGOW1', 'u-lfg-12', 'Ngô Mỹ Linh', checkedInAt: at(-33)),
          lfgPlayer('LFGOW1', 'u-lfg-13', 'Đặng Gia Huy', checkedInAt: at(-28)),
          lfgPlayer('LFGOW1', 'u-lfg-14', 'Bùi Khánh Vy'),
        ],
        assignedCourt: 'Sân 2',
      ),
      // Đang trong khung check-in, đặt cọc 1/4.
      CourtSession(
        id: 'OW1001',
        kind: SessionKind.booking,
        facilityId: tt,
        facilityName: ttName,
        sport: Sport.badminton,
        start: at(20),
        end: at(80),
        totalPrice: 160000,
        paidViaApp: 40000,
        players: [bookingPlayer('OW1001', 'Nguyễn Minh Anh')],
        assignedCourt: 'Sân 3',
      ),
      // Kèo Team vs Team chiều nay, chưa mở check-in.
      CourtSession(
        id: 'LFGOW2',
        kind: SessionKind.lfg,
        facilityId: hl,
        facilityName: hlName,
        sport: Sport.football,
        courtType: CourtType.football5,
        start: at(180),
        end: at(270),
        totalPrice: 500000,
        paidViaApp: 500000,
        players: [
          lfgPlayer('LFGOW2', 'u-lfg-21', 'Đội FC Sao Mai (Hùng)'),
          lfgPlayer('LFGOW2', 'u-lfg-22', 'Đội Q1 United (Khoa)'),
        ],
        assignedCourt: 'Sân 1',
      ),
      // Ngày mai.
      CourtSession(
        id: 'OW1006',
        kind: SessionKind.booking,
        facilityId: tt,
        facilityName: ttName,
        sport: Sport.badminton,
        start: tomorrow.add(const Duration(hours: 18)),
        end: tomorrow.add(const Duration(hours: 19)),
        totalPrice: 160000,
        paidViaApp: 160000,
        players: [bookingPlayer('OW1006', 'Hồ Thị Thu')],
        assignedCourt: 'Sân 1',
      ),
      CourtSession(
        id: 'OW1007',
        kind: SessionKind.booking,
        facilityId: hl,
        facilityName: hlName,
        sport: Sport.basketball,
        courtType: CourtType.basketballHalf,
        start: tomorrow.add(const Duration(hours: 17)),
        end: tomorrow.add(const Duration(hours: 18)),
        totalPrice: 150000,
        paidViaApp: 38000,
        players: [bookingPlayer('OW1007', 'Lý Minh Khang')],
        assignedCourt: 'Sân 1',
        cancelledAt: now,
      ),
    ];
  }
}
