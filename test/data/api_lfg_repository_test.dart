import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_facility_repository.dart';
import 'package:test1/data/api/api_lfg_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/lfg_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/models/user_role.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) =>
      routes['$method $path'] = (200, {'statusCode': 200, 'message': 'OK', 'data': data});

  void fail(String method, String path, int code, String message) =>
      routes['$method $path'] = (code, {'statusCode': code, 'message': message, 'data': null});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _me = 'u-me';
const _badminton = 'cat-badminton';

/// Một kèo như BE trả (bảng tin / my-cards); [extra] ghi đè trường.
Map<String, dynamic> _card({
  String id = 'c1',
  int totalSlots = 3,
  int remaining = 2,
  String hostId = 'u-host',
  String sport = 'Cầu lông',
  int daysAhead = 4,
  Map<String, dynamic> extra = const {},
}) {
  final start = DateTime.now().add(Duration(days: daysAhead)).toUtc();
  return {
    'id': id,
    'bookingId': 'b-$id',
    'hostId': hostId,
    'hostName': 'Chủ Kèo',
    'hostFairPlayScore': 92.5,
    'facilityId': 'f1',
    'facilityName': 'Hà Nội Badminton Center',
    'facilityAddress': '36 Trần Duy Hưng, Cầu Giấy, Hà Nội',
    'latitude': 21.01,
    'longitude': 105.8,
    'distanceKm': 1.5,
    'courtName': 'Sân 1',
    'sportName': sport,
    'startTime': start.toIso8601String(),
    'endTime': start.add(const Duration(hours: 1)).toIso8601String(),
    'description': 'Trình độ trung bình',
    'totalSlots': totalSlots,
    'remainingSlots': remaining,
    'sideSize': null,
    'format': null,
    'pricePerPerson': 50000,
    'requireApproval': false,
    'status': remaining == 0 ? 'FILLED' : 'PENDING',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    ...extra,
  };
}

void main() {
  late _FakeServer server;
  late ApiLfgRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.save(
      const AppUser(id: _me, fullName: 'Khoa Cao', email: 'k@x.com', phone: '0978809952', role: UserRole.player, fairPlayScore: 90),
      rememberMe: true,
    );
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    final api = ApiClient(tokens: tokens, dio: dio);
    repo = ApiLfgRepository(api: api, facility: ApiFacilityRepository(api: api));
    server.ok('GET', ApiFacilityRepository.sportsPath, [
      {'id': _badminton, 'name': 'Cầu lông'},
    ]);
  });

  test('khác bản giả lập: không lọc khu vực, host trả cả sân và chỉ hủy kèo', () {
    expect(repo.supportsAreaFilter, isFalse);
    expect(repo.hostPaysCourt, isTrue);
    expect(repo.hostCanLeave, isFalse);
    expect(repo.createCost(200000, LfgFormat.doubles), 200000);
  });

  test('chuyển dữ liệu: cộng chỗ của host, ghép 4 = host + 3 suất, giá mỗi người của BE', () {
    final m = ApiLfgRepository.matchFromApi(_card(), myId: _me)!;
    expect(m.totalSlots, 4);
    expect(m.format, LfgFormat.doubles);
    expect(m.formatLabel, LfgFormat.doubles.label);
    expect(m.slotsLeft, 2);
    expect(m.members.length, 2); // host + 1 người đã vào
    expect(m.host.name, 'Chủ Kèo');
    expect(m.host.fairPlayScore, 93);
    expect(m.depositPerSlot, 50000);
    expect(m.isFull, isFalse);
    expect(m.district, '36 Trần Duy Hưng, Cầu Giấy, Hà Nội');
    expect(m.bookingId, 'b-c1');

    final filled = ApiLfgRepository.matchFromApi(_card(remaining: 0), myId: _me)!;
    expect(filled.isFull, isTrue);

    // Kèo tạo trên Web: 5v5, hoặc ghép lẻ 3 người.
    final team = ApiLfgRepository.matchFromApi(
        _card(sport: 'Bóng đá', totalSlots: 9, remaining: 5, extra: {'sideSize': 5, 'format': '5v5'}), myId: _me)!;
    expect(team.format, LfgFormat.teamVsTeam);
    expect(team.totalSlots, 10);
    expect(team.formatLabel, '5v5');
    final three = ApiLfgRepository.matchFromApi(_card(totalSlots: 2, remaining: 2), myId: _me)!;
    expect(three.formatLabel, LfgStrings.playersLabel(3));

    // Môn app chưa có thì bỏ qua; kèo đã hủy.
    expect(ApiLfgRepository.matchFromApi(_card(sport: 'Bóng chuyền'), myId: _me), isNull);
    final cancelled = ApiLfgRepository.matchFromApi(_card(extra: {'status': 'CANCELLED'}), myId: _me)!;
    expect(cancelled.cancelReason, LfgCancelReason.cancelled);
  });

  test('chi tiết: thành viên là người ACCEPTED, người được mời là chỗ đang giữ; trạng thái của mình', () {
    final m = ApiLfgRepository.matchFromApi(
      _card(remaining: 1, extra: {
        'myStatus': 'INVITED',
        'participants': [
          {'userId': 'u-a', 'fullName': 'An', 'fairPlayScore': 88.0, 'status': 'ACCEPTED', 'joinedAt': DateTime.now().toUtc().toIso8601String()},
          {'userId': _me, 'fullName': 'Khoa Cao', 'fairPlayScore': 90.0, 'status': 'INVITED'},
          {'userId': 'u-b', 'fullName': 'Bình', 'fairPlayScore': 70.0, 'status': 'LEFT'},
        ],
      }),
      myId: _me,
    )!;
    expect(m.members.map((x) => x.name), ['Chủ Kèo', 'An']);
    expect(m.heldSlots, 1);
    expect(m.myStatus, LfgMyStatus.invited);
    expect(m.isMember(_me), isFalse);
  });

  test('bảng tin: gửi môn + vị trí, sớm nhất trước; lọc hình thức trên máy', () async {
    server.ok('GET', ApiLfgRepository.feedPath, {
      'items': [_card(id: 'c1'), _card(id: 'c2', totalSlots: 1, remaining: 1)],
    });

    final all = await repo.getFeed(const LfgFeedQuery(city: '', sport: Sport.badminton));
    final request = server.requests.last;
    expect(request.queryParameters['categoryId'], _badminton);
    expect(request.queryParameters['sortBy'], 'soonest');
    expect(all.map((i) => i.match.id), ['c1', 'c2']);
    expect(all.first.distanceKm, 1.5);

    final singles = await repo.getFeed(const LfgFeedQuery(city: '', format: LfgFormat.singles));
    expect(singles.map((i) => i.match.id), ['c2']);
  });

  test('kèo của tôi: kèo mình tạo + kèo tham gia; bỏ kèo đã rời / bị từ chối', () async {
    server.ok('GET', ApiLfgRepository.myCardsPath, [_card(id: 'host', hostId: _me, daysAhead: 5)]);
    server.ok('GET', ApiLfgRepository.joinedPath, [
      _card(id: 'joined', daysAhead: 3, extra: {'myStatus': 'ACCEPTED'}),
      _card(id: 'left', extra: {'myStatus': 'LEFT'}),
      _card(id: 'pending', daysAhead: 4, extra: {'myStatus': 'PENDING'}),
      _card(id: 'withdrawn', extra: {'myStatus': 'CANCELLED'}), // mình rút yêu cầu, kèo vẫn mở
      _card(id: 'gone', daysAhead: 2, extra: {'myStatus': 'CANCELLED', 'status': 'CANCELLED'}), // kèo bị hủy
    ]);

    final mine = await repo.getMyMatches();
    expect(mine.map((m) => m.id), ['joined', 'pending', 'host', 'gone']);
    expect(mine.last.cancelReason, LfgCancelReason.cancelled);
    expect(mine.first.isMember(_me), isTrue);
    expect(mine[1].myStatus, LfgMyStatus.pendingApproval);
    expect(mine[2].isHostedBy(_me), isTrue);
  });

  test('vào kèo: giữ chỗ trên máy rồi gọi claim khi xác nhận thanh toán; hết chỗ thì báo ngay', () async {
    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card());
    server.ok('POST', ApiLfgRepository.claimPath('c1'), {'lfgCardId': 'c1', 'status': 'ACCEPTED', 'amountPaid': 50000});

    final claim = await repo.claimSlot('c1');
    expect(claim.amount, 50000);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);

    await repo.confirmClaim(claim.claimId);
    expect(server.requests.where((r) => r.method == 'POST').single.path, ApiLfgRepository.claimPath('c1'));
    await expectLater(repo.confirmClaim(claim.claimId), throwsA(isA<LfgException>()));

    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card(remaining: 0));
    await expectLater(
      repo.claimSlot('c1'),
      throwsA(isA<LfgException>().having((e) => e.message, 'message', LfgStrings.full)),
    );
  });

  test('vào kèo bị BE chặn (Fair Play / ví không đủ): hiện câu của BE', () async {
    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card());
    server.fail('POST', ApiLfgRepository.claimPath('c1'), 403, 'Điểm Fair Play của bạn (25) thấp hơn mức tối thiểu 30');
    final claim = await repo.claimSlot('c1');
    await expectLater(
      repo.confirmClaim(claim.claimId),
      throwsA(isA<LfgException>().having((e) => e.message, 'message', contains('Fair Play'))),
    );
  });

  test('tạo kèo: ghép lẻ không duyệt, cần thêm (số người − 1); chặn Fair Play thấp / ngoài 48h–5 ngày', () async {
    final start = DateTime.now().add(const Duration(days: 3));
    final slot = TimeSlot(
      id: 's1',
      facilityId: 'f1',
      sport: Sport.badminton,
      courtName: 'Sân 1',
      start: start,
      end: start.add(const Duration(hours: 1)),
      price: 200000,
      isAvailable: true,
    );
    final facility = Facility(
      id: 'f1',
      name: 'Hà Nội Badminton Center',
      address: '36 Trần Duy Hưng',
      city: '',
      district: '',
      location: Facility.noLocation,
      offerings: const [],
      rating: 0,
      reviewCount: 0,
      imageUrls: const [],
      openTime: '06:00',
      closeTime: '22:00',
      phone: '',
    );
    server.routes['POST ${ApiLfgRepository.feedPath}'] = (
      201,
      {'statusCode': 201, 'message': 'OK', 'data': _card(hostId: _me, totalSlots: 3, remaining: 3, extra: {'bookingTotalAmount': 200000})},
    );

    final match = await repo.createMatch(
      hold: SlotHold(holdId: 'local-1', slots: [slot], expiresAt: start),
      facility: facility,
      format: LfgFormat.doubles,
      note: ' Trình độ khá ',
    );
    expect(server.requests.last.data, {
      'courtSlotId': 's1',
      'slotsNeeded': 3,
      'requireApproval': false,
      'description': 'Trình độ khá',
    });
    expect(match.isHostedBy(_me), isTrue);
    expect(match.courtPrice, 200000);

    final tooSoon = TimeSlot(
      id: 's2',
      facilityId: 'f1',
      sport: Sport.badminton,
      courtName: 'Sân 1',
      start: DateTime.now().add(const Duration(hours: 20)),
      end: DateTime.now().add(const Duration(hours: 21)),
      price: 200000,
      isAvailable: true,
    );
    await expectLater(
      repo.createMatch(hold: SlotHold(holdId: 'x', slots: [tooSoon], expiresAt: start), facility: facility, format: LfgFormat.doubles),
      throwsA(isA<LfgException>().having((e) => e.message, 'message', LfgStrings.createWindow)),
    );

    await SessionStore.save(
      const AppUser(id: _me, fullName: 'Khoa Cao', email: 'k@x.com', phone: '0978809952', role: UserRole.player, fairPlayScore: 25),
      rememberMe: true,
    );
    await expectLater(
      repo.createMatch(hold: SlotHold(holdId: 'x', slots: [slot], expiresAt: start), facility: facility, format: LfgFormat.doubles),
      throwsA(isA<LfgException>().having((e) => e.message, 'message', LfgStrings.blocked)),
    );
  });

  test('rời kèo gửi kèm lý do; trước T−48h hoàn đủ phần đã trả, sau T−48h vẫn rời được nhưng không hoàn', () async {
    expect(repo.lateLeaveAllowed, isTrue);
    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card(daysAhead: 4));
    server.ok('POST', ApiLfgRepository.leavePath('c1'), null);
    expect(await repo.leaveMatch('c1', reason: ' Bận việc '), 50000);
    expect(server.requests.last.data, {'reason': 'Bận việc'});

    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card(daysAhead: 1));
    expect(await repo.leaveMatch('c1', reason: 'Bận việc'), 0);
    expect(server.requests.last.path, ApiLfgRepository.leavePath('c1'));
  });

  test('lý do rời kèo: dạng {code, label, isCustom} hoặc chuỗi', () async {
    server.ok('GET', ApiLfgRepository.leaveReasonsPath, [
      {'code': 1, 'label': 'Bận việc đột xuất', 'isCustom': false},
      {'code': 6, 'label': 'Khác', 'isCustom': true},
    ]);
    expect((await repo.getLeaveReasons()).map((r) => (r.code, r.label, r.isCustom)), [
      (1, 'Bận việc đột xuất', false),
      (6, 'Khác', true),
    ]);
    server.ok('GET', ApiLfgRepository.leaveReasonsPath, ['Ốm', 'Bận']);
    expect((await repo.getLeaveReasons()).map((r) => r.label), ['Ốm', 'Bận']);
  });

  test('yêu cầu hủy kèo đã chốt: chỉ host gửi, người tham gia bỏ phiếu theo id yêu cầu mới nhất', () async {
    expect(repo.onlyHostRequestsCancel, isTrue);
    // Kèo đủ người, còn ~48 giờ: đã qua hạn tự rời, chưa tới T−24h.
    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card(hostId: _me, remaining: 0, daysAhead: 2));
    server.ok('POST', ApiLfgRepository.cancelRequestsPath('c1'), {'id': 'r1', 'status': 'PENDING'});
    server.ok('GET', ApiLfgRepository.latestCancelRequestPath('c1'),
        {'id': 'r1', 'status': 'PENDING', 'myVote': null, 'canVote': false, 'createdAt': DateTime.now().toUtc().toIso8601String()});
    server.ok('POST', ApiLfgRepository.votePath('c1', 'r1'), null);

    final requested = await repo.requestCancel('c1', reason: 'Trời mưa');
    expect(server.requests.firstWhere((r) => r.method == 'POST').data, {'reason': 'Trời mưa'});
    expect(requested.cancelRequest, isNotNull);
    expect(requested.cancelRequest!.requestedBy, _me);
    expect(requested.cancelRequest!.hasApproved(_me), isTrue);

    server.requests.clear();
    await repo.respondCancel('c1', approve: false);
    final vote = server.requests.firstWhere((r) => r.method == 'POST');
    expect(vote.path, ApiLfgRepository.votePath('c1', 'r1'));
    expect(vote.data, {'approve': false});

    // Yêu cầu đã bị bác / hết hạn: không còn hiện.
    server.ok('GET', ApiLfgRepository.latestCancelRequestPath('c1'), {'id': 'r1', 'status': 'REJECTED'});
    expect((await repo.getMatch('c1')).cancelRequest, isNull);
  });

  test('yêu cầu hủy: có danh sách phiếu thì biết ai đã đồng ý; không có thì chỉ biết phiếu của mình', () {
    final match = ApiLfgRepository.matchFromApi(_card(remaining: 0), myId: _me)!;
    final withVotes = ApiLfgRepository.cancelRequestFromApi({
      'status': 'PENDING',
      'votes': [
        {'userId': 'u-a', 'approve': true},
        {'userId': 'u-b', 'approve': null},
      ],
    }, match, myId: _me)!;
    expect(withVotes.approvals.toSet(), {'u-host', 'u-a'});

    final mine = ApiLfgRepository.cancelRequestFromApi({'status': 'PENDING', 'myVote': true}, match, myId: _me)!;
    expect(mine.approvals.toSet(), {'u-host', _me});
  });

  test('host hủy kèo, chấp nhận / từ chối lời mời: gọi đúng API', () async {
    server.ok('GET', ApiLfgRepository.cardPath('c1'), _card());
    server.ok('POST', ApiLfgRepository.cancelPath('c1'), {'lfgCardId': 'c1'});
    server.ok('POST', ApiLfgRepository.acceptPath('c1'), {'status': 'ACCEPTED', 'amountPaid': 50000});
    server.ok('POST', ApiLfgRepository.declinePath('c1'), null);

    await repo.cancelMatch('c1');
    await repo.acceptInvitation('c1');
    await repo.declineInvitation('c1');

    expect(server.requests.where((r) => r.method == 'POST').map((r) => r.path), [
      ApiLfgRepository.cancelPath('c1'),
      ApiLfgRepository.acceptPath('c1'),
      ApiLfgRepository.declinePath('c1'),
    ]);
  });

  test('vé: người vào kèo dùng vé LFG; host dùng vé của đơn đặt sân', () async {
    final m = ApiLfgRepository.matchFromApi(_card(), myId: _me)!;
    server.ok('GET', ApiLfgRepository.ticketPath('c1'), {'lfgCardId': 'c1', 'qrCode': 'LFG_c1_u-me'});
    expect(await repo.getTicketCode(m, _me), 'LFG_c1_u-me');

    server.ok('GET', ApiLfgRepository.bookingTicketPath('b-c1'), 'TICKET_b-c1_u-host_123');
    expect(await repo.getTicketCode(m, 'u-host'), 'TICKET_b-c1_u-host_123');
  });
}
