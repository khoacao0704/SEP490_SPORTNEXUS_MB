import '../../core/constants/fair_play_rules.dart';
import '../../core/constants/lfg_rules.dart';
import '../../core/strings/lfg_strings.dart';
import '../../models/facility.dart';
import '../../models/geo_point.dart';
import '../../models/lfg_match.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../repositories/lfg_repository.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// [LfgRepository] gọi Backend thật.
///
/// - Host tạo kèo = đặt cả sân (trả 100% tiền sân, BE tạo luôn đơn đặt sân); người vào kèo trả `pricePerPerson`,
///   tiền tạm giữ rồi chuyển cho host khi check-in / sau giờ chơi.
/// - `totalSlots` / `remainingSlots` của BE KHÔNG tính host → app cộng thêm 1 chỗ của host.
/// - Kèo tạo trên app luôn ghép lẻ (không chia phe), không cần duyệt; Team vs Team = 1 vs 1 giữa 2 đại diện.
/// - BE chưa có: giữ chỗ khi Flash Claim (app đếm 10 phút trên máy, vào kèo + trừ tiền ở bước xác nhận),
///   yêu cầu hủy cần tất cả đồng ý, chuyển quyền host (host chỉ hủy kèo), lọc tỉnh/quận.
class ApiLfgRepository implements LfgRepository {
  static const String feedPath = '/api/v1/lfgs';
  static const String myCardsPath = '/api/v1/lfgs/my-cards';
  static const String joinedPath = '/api/v1/lfgs/joined';
  static String cardPath(String id) => '/api/v1/lfgs/$id';
  static String claimPath(String id) => '/api/v1/lfgs/$id/claim';
  static String leavePath(String id) => '/api/v1/lfgs/$id/leave';
  static String cancelPath(String id) => '/api/v1/lfgs/$id/cancel';
  static String acceptPath(String id) => '/api/v1/lfgs/$id/invitation/accept';
  static String declinePath(String id) => '/api/v1/lfgs/$id/invitation/decline';
  static String ticketPath(String id) => '/api/v1/lfgs/$id/qr-ticket';
  static String bookingTicketPath(String bookingId) => '/api/v1/bookings/$bookingId/qr-ticket';

  /// Trạng thái của mình trong kèo được giữ lại ở "Kèo của tôi" (rời / bị loại / từ chối thì bỏ).
  /// CANCELLED chỉ giữ khi chính kèo bị hủy (còn lại là mình tự rút yêu cầu).
  static const Set<String> keptJoinedStatuses = {'ACCEPTED', 'PENDING', 'INVITED'};

  static bool _keepJoined(Map<String, dynamic> j) {
    final mine = (j['myStatus'] as String? ?? '').toUpperCase();
    return keptJoinedStatuses.contains(mine) ||
        (mine == 'CANCELLED' && (j['status'] as String? ?? '').toUpperCase() == 'CANCELLED');
  }

  final ApiClient _api;
  final ApiFacilityRepository _facility;

  /// Chỗ đang giữ trên máy: claimId → matchId.
  final Map<String, String> _claims = {};
  int _claimCounter = 0;

  ApiLfgRepository({required this._api, required this._facility});

  @override
  bool get supportsAreaFilter => false;

  @override
  bool get hostCanLeave => false;

  @override
  bool get hostPaysCourt => true;

  @override
  int createCost(int courtPrice, LfgFormat format) => courtPrice;

  // ---------------- Bảng tin & chi tiết ----------------

  /// BE chỉ trả kèo còn nhận người, chưa tới giờ chơi; sớm nhất trước.
  @override
  Future<List<LfgFeedItem>> getFeed(LfgFeedQuery query) async {
    final location = query.userLocation;
    final params = <String, dynamic>{
      'page': 1,
      'pageSize': 50,
      'sortBy': 'soonest',
      if (location != null) 'lat': location.latitude,
      if (location != null) 'lng': location.longitude,
    };
    final sport = query.sport;
    if (sport != null) {
      final categoryId = await _facility.categoryIdOf(sport);
      if (categoryId == null) return [];
      params['categoryId'] = categoryId;
    }
    final data = await _call(() => _api.get(feedPath, query: params));
    final myId = await _myId();
    return _items(data)
        .map((json) => (json: json, match: matchFromApi(json, myId: myId)))
        .where((e) => e.match != null && (query.format == null || e.match!.format == query.format))
        .map((e) => LfgFeedItem(match: e.match!, distanceKm: (e.json['distanceKm'] as num?)?.toDouble()))
        .toList();
  }

  @override
  Future<LfgMatch> getMatch(String matchId) async {
    final match = matchFromApi(await _call(() => _api.get(cardPath(matchId))) as Map<String, dynamic>, myId: await _myId());
    if (match == null) throw const LfgException(LfgStrings.notFound);
    return match;
  }

  /// Kèo mình tạo (my-cards) + kèo mình tham gia / được mời / đang chờ duyệt (joined); sắp diễn ra trước.
  @override
  Future<List<LfgMatch>> getMyMatches() async {
    final myId = await _myId();
    final hosted = _items(await _call(() => _api.get(myCardsPath)));
    final joined = _items(await _call(() => _api.get(joinedPath))).where(_keepJoined);
    final all = [...hosted, ...joined].map((j) => matchFromApi(j, myId: myId)).whereType<LfgMatch>().toList();
    final now = DateTime.now();
    bool upcoming(LfgMatch m) => m.end.isAfter(now) && m.cancelReason == null;
    return [
      ...all.where(upcoming).toList()..sort((a, b) => a.start.compareTo(b.start)),
      ...all.where((m) => !upcoming(m)).toList()..sort((a, b) => b.start.compareTo(a.start)),
    ];
  }

  // ---------------- Vào kèo ----------------

  /// BE chưa có giữ chỗ: kiểm tra kèo còn nhận người rồi đếm 10 phút trên máy (BE không khóa chỗ).
  @override
  Future<LfgClaim> claimSlot(String matchId) async {
    final match = await getMatch(matchId);
    final myId = await _myId();
    if (match.isMember(myId) || match.myStatus != null) throw const LfgException(LfgStrings.alreadyJoined);
    if (!match.isClaimable(DateTime.now())) {
      throw LfgException(match.slotsLeft <= 0 ? LfgStrings.full : LfgStrings.closed);
    }
    final claimId = 'local-${++_claimCounter}';
    _claims[claimId] = matchId;
    return LfgClaim(
      claimId: claimId,
      match: match,
      amount: match.depositPerSlot,
      expiresAt: DateTime.now().add(LfgRules.claimHold),
    );
  }

  /// Vào kèo + tạm giữ tiền trong một lần gọi. Hết chỗ / Fair Play thấp / ví không đủ: BE trả câu tiếng Việt.
  /// Kèo cần duyệt (tạo trên Web) thì chưa trừ tiền, trạng thái chờ chủ kèo duyệt.
  @override
  Future<LfgMatch> confirmClaim(String claimId) async {
    final matchId = _claims[claimId];
    if (matchId == null) throw const LfgException(LfgStrings.claimExpired);
    await _call(() => _api.post(claimPath(matchId), body: const <String, dynamic>{}));
    _claims.remove(claimId);
    return getMatch(matchId);
  }

  @override
  Future<void> releaseClaim(String claimId) async => _claims.remove(claimId);

  // ---------------- Tạo / rời / hủy ----------------

  /// Ghép lẻ, không duyệt: cần thêm (số người − 1) người. Host trả cả tiền sân.
  @override
  Future<LfgMatch> createMatch({
    required SlotHold hold,
    required Facility facility,
    required LfgFormat format,
    String note = '',
  }) async {
    if (hold.slots.length != 1) throw const LfgException(LfgStrings.singleSlotOnly);
    final slot = hold.slots.single;
    final me = await SessionStore.readUser();
    if (me == null) throw const LfgException(LfgStrings.loginRequired);
    // BE không kiểm tra Fair Play / giới hạn 5 ngày của host: app tự chặn theo quy tắc nhóm.
    if (!FairPlayRules.canJoinLfg(me.fairPlayScore)) throw const LfgException(LfgStrings.blocked);
    if (!LfgRules.canCreateFor(slot.start, DateTime.now())) throw const LfgException(LfgStrings.createWindow);

    final text = note.trim();
    final data = await _call(() => _api.post(feedPath, body: {
          'courtSlotId': slot.id,
          'slotsNeeded': format.totalSlots - 1,
          'requireApproval': false,
          if (text.isNotEmpty) 'description': text,
        })) as Map<String, dynamic>;
    final match = matchFromApi(data, myId: me.id);
    if (match == null) throw const LfgException(LfgStrings.loadError);
    return match;
  }

  /// Hoàn 100% số đang tạm giữ (BE chỉ ghi số tiền trong câu thông báo → lấy từ chi tiết trước khi rời).
  @override
  Future<int> leaveMatch(String matchId) async {
    final match = await getMatch(matchId);
    if (!DateTime.now().isBefore(match.leaveDeadline)) throw const LfgException(LfgStrings.leaveTooLate);
    await _call(() => _api.post(leavePath(matchId)));
    return match.myStatus == null ? match.depositPerSlot : 0;
  }

  @override
  Future<LfgMatch> requestCancel(String matchId) async =>
      throw const LfgException(LfgStrings.mutualCancelUnavailable);

  @override
  Future<LfgMatch> respondCancel(String matchId, {required bool approve}) async =>
      throw const LfgException(LfgStrings.mutualCancelUnavailable);

  @override
  Future<LfgMatch> cancelMatch(String matchId) async {
    await _call(() => _api.post(cancelPath(matchId), body: const <String, dynamic>{}));
    return getMatch(matchId);
  }

  @override
  Future<LfgMatch> acceptInvitation(String matchId) async {
    await _call(() => _api.post(acceptPath(matchId)));
    return getMatch(matchId);
  }

  @override
  Future<void> declineInvitation(String matchId) => _call(() => _api.post(declinePath(matchId)));

  /// Người vào kèo: vé LFG cố định. Host: vé của đơn đặt sân (đổi mã mỗi 30 giây).
  @override
  Future<String> getTicketCode(LfgMatch match, String userId) async {
    final bookingId = match.bookingId;
    final isHost = match.isHostedBy(userId);
    final data = await _call(
        () => _api.get(isHost && bookingId != null ? bookingTicketPath(bookingId) : ticketPath(match.id)));
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data['qrCode'] is String) return data['qrCode'] as String;
    throw const LfgException(LfgStrings.loadError);
  }

  // ---------------- Chuyển đổi dữ liệu BE ----------------

  /// Một kèo của BE (bảng tin / chi tiết / my-cards / joined) → [LfgMatch]; môn app chưa có thì `null`.
  ///
  /// Danh sách không có người tham gia: thành viên ngoài host là chỗ trống có tên rỗng (đủ để đếm số người);
  /// kèo mình đã vào (myStatus ACCEPTED) thì một chỗ trong đó là mình.
  static LfgMatch? matchFromApi(Map<String, dynamic> json, {required String myId}) {
    final sport = ApiFacilityRepository.sportFromName(json['sportName'] as String?);
    if (sport == null) return null;
    final start = DateTime.parse(json['startTime'] as String).toLocal();
    final end = DateTime.parse(json['endTime'] as String).toLocal();
    final createdAt = _time(json['createdAt']) ?? start;
    final players = ((json['totalSlots'] as num?)?.toInt() ?? 1) + 1; // + host
    final remaining = (json['remainingSlots'] as num?)?.toInt() ?? 0;
    final price = _money(json['pricePerPerson']);
    final sideSize = (json['sideSize'] as num?)?.toInt();
    final format = sport == Sport.football || sport == Sport.basketball
        ? LfgFormat.teamVsTeam
        : players >= 4
            ? LfgFormat.doubles
            : LfgFormat.singles;
    final formatLabel = sideSize != null
        ? json['format'] as String? ?? '${sideSize}v$sideSize'
        : players == format.totalSlots
            ? null
            : LfgStrings.playersLabel(players);

    final host = LfgMember(
      userId: json['hostId']?.toString() ?? '',
      name: json['hostName'] as String? ?? '',
      fairPlayScore: _money(json['hostFairPlayScore']),
      joinedAt: createdAt,
      isHost: true,
    );
    final participants = (json['participants'] as List?)?.cast<Map<String, dynamic>>();
    final List<LfgMember> others;
    var held = 0;
    if (participants != null) {
      others = [
        for (final p in participants)
          if ((p['status'] as String? ?? '').toUpperCase() == 'ACCEPTED')
            LfgMember(
              userId: p['userId'].toString(),
              name: p['fullName'] as String? ?? '',
              fairPlayScore: _money(p['fairPlayScore']),
              joinedAt: _time(p['joinedAt']) ?? createdAt,
            ),
      ];
      held = participants.where((p) => (p['status'] as String? ?? '').toUpperCase() == 'INVITED').length;
    } else {
      final count = (players - 1 - remaining).clamp(0, players - 1);
      final meIn = (json['myStatus'] as String? ?? '').toUpperCase() == 'ACCEPTED';
      others = [
        for (var i = 0; i < count; i++)
          LfgMember(userId: meIn && i == 0 ? myId : '', name: '', fairPlayScore: 0, joinedAt: createdAt),
      ];
    }

    final myStatus = switch ((json['myStatus'] as String? ?? '').toUpperCase()) {
      'PENDING' => LfgMyStatus.pendingApproval,
      'INVITED' => LfgMyStatus.invited,
      _ => null,
    };
    return LfgMatch(
      id: json['id'].toString(),
      facilityId: json['facilityId']?.toString() ?? '',
      facilityName: json['facilityName'] as String? ?? '',
      city: '',
      district: json['facilityAddress'] as String? ?? '',
      location: _location(json),
      sport: sport,
      format: format,
      courtName: json['courtName'] as String?,
      start: start,
      end: end,
      courtPrice: json.containsKey('bookingTotalAmount') ? _money(json['bookingTotalAmount']) : price * players,
      members: [host, ...others],
      createdAt: createdAt,
      heldSlots: held,
      note: json['description'] as String? ?? '',
      cancelReason: (json['status'] as String? ?? '').toUpperCase() == 'CANCELLED' ? LfgCancelReason.cancelled : null,
      totalSlotsOverride: players,
      slotsLeftOverride: remaining,
      pricePerPersonOverride: price,
      formatLabelOverride: formatLabel,
      myStatus: myStatus,
      bookingId: json['bookingId']?.toString(),
    );
  }

  static List<Map<String, dynamic>> _items(Object? data) {
    final list = data is Map<String, dynamic> ? data['items'] : data;
    return list is List ? list.cast<Map<String, dynamic>>() : const [];
  }

  static GeoPoint _location(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    return lat == null || lng == null ? Facility.noLocation : GeoPoint(lat, lng);
  }

  static DateTime? _time(Object? value) => value is String ? DateTime.parse(value).toLocal() : null;

  /// Tiền / điểm BE là decimal; app dùng số nguyên.
  static int _money(Object? value) => value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;

  Future<String> _myId() async => (await SessionStore.readUser())?.id ?? '';

  /// Gọi BE; lỗi thành [LfgException] mang câu tiếng Việt của BE.
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw LfgException(e.message);
    }
  }
}
