import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/constants/tournament_rules.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_host_tournament_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/mock/mock_host_tournament_repository.dart';
import 'package:test1/data/repositories/tournament_repository.dart';
import 'package:test1/models/organized_tournament.dart';
import 'package:test1/models/tournament_listing.dart';

class _FakeServer implements HttpClientAdapter {
  final Map<String, Object?> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) => routes['$method $path'] = data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    if (!routes.containsKey(key)) {
      return ResponseBody.fromString(
        jsonEncode({'statusCode': 400, 'message': 'Lỗi BE', 'data': null}),
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'statusCode': 200, 'message': 'OK', 'data': routes[key]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final today = DateTime(2026, 11, 27);

  group('luật ngày (như tournamentRules.js)', () {
    String? v(DateTime? s, DateTime? e, DateTime? d, {Set<String>? changed, bool require = true}) =>
        TournamentRules.validateDates(
          start: s,
          end: e,
          deadline: d,
          today: today,
          changed: changed,
          requireDates: require,
        );

    test('bắt đầu ≥ hôm nay + 2 ngày; kết thúc ≤ bắt đầu + 1 tháng; hạn ≤ bắt đầu − 48h', () {
      expect(v(null, null, null), contains('chọn ngày bắt đầu'));
      expect(v(DateTime(2026, 11, 28), DateTime(2026, 11, 30), null), contains('ít nhất 2 ngày'));
      expect(v(DateTime(2026, 11, 29), DateTime(2026, 11, 30), DateTime(2026, 11, 27)), isNull);
      expect(v(DateTime(2026, 12, 5), DateTime(2026, 12, 4), null), contains('từ ngày bắt đầu'));
      expect(v(DateTime(2026, 12, 5), DateTime(2027, 1, 6), null), contains('tối đa 1 tháng'));
      expect(v(DateTime(2026, 12, 5), DateTime(2027, 1, 5), null), isNull);
      expect(v(DateTime(2026, 12, 5), DateTime(2026, 12, 6), DateTime(2026, 12, 4)), contains('48 giờ'));
      expect(v(DateTime(2026, 12, 5), DateTime(2026, 12, 6), DateTime(2026, 12, 6)), contains('trước ngày bắt đầu'));
      expect(v(DateTime(2026, 12, 5), DateTime(2026, 12, 6), DateTime(2026, 11, 26)), contains('quá khứ'));
    });

    test('sửa giải: luật mới chỉ áp cho ô vừa đổi, thứ tự ngày luôn kiểm', () {
      // Giải cũ bắt đầu ngày mai (đã quá luật 2 ngày) vẫn sửa tên được.
      expect(v(DateTime(2026, 11, 28), DateTime(2026, 11, 29), null, changed: {}, require: false), isNull);
      expect(v(DateTime(2026, 11, 28), DateTime(2026, 11, 29), null, changed: {'start'}, require: false), isNotNull);
      expect(
        v(DateTime(2026, 11, 28), DateTime(2026, 11, 27), null, changed: {}, require: false),
        contains('từ ngày bắt đầu'),
      );
    });

    test('cộng tháng kẹp ngày cuối tháng; hạn mặc định 48h trước bắt đầu', () {
      expect(TournamentRules.addMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
      expect(TournamentRules.defaultDeadline(DateTime(2026, 12, 5)), DateTime(2026, 12, 3));
      expect(TournamentRules.minStart(DateTime(2026, 11, 27, 22)), DateTime(2026, 11, 29));
    });
  });

  group('thể thức, lịch sân, hủy, Fair Play, tìm cơ sở', () {
    test('gợi ý / giới hạn / cảnh báo thể thức', () {
      expect(TournamentRules.suggestFormat(8), BracketFormat.knockout);
      expect(TournamentRules.suggestFormat(9), BracketFormat.groupKnockout);
      expect(TournamentRules.formatError(BracketFormat.roundRobin, 9), contains('tối đa 8'));
      expect(TournamentRules.formatError(BracketFormat.groupKnockout, 5), contains('ít nhất 6'));
      expect(TournamentRules.formatError(BracketFormat.knockout, 4), isNull);
      expect(TournamentRules.estimateMatches(BracketFormat.roundRobin, 6), 15);
      expect(TournamentRules.estimateMatches(BracketFormat.groupKnockout, 12), 3 * 6 + 3);
      expect(TournamentRules.formatWarning(BracketFormat.roundRobin, 7), contains('21 trận'));
      expect(TournamentRules.formatWarning(BracketFormat.knockout, 9), contains('vòng bảng'));
    });

    test('lịch sân: trong thời gian giải, số sân ≥ 1, Cả ngày trùng mọi buổi', () {
      final s = DateTime(2026, 12, 5);
      final e = DateTime(2026, 12, 6);
      String? check(List<CourtScheduleRequest> rows) => TournamentRules.validateSchedule(rows, start: s, end: e);
      expect(check(const []), isNull);
      expect(TournamentRules.validateSchedule([CourtScheduleRequest(date: s)], start: null), contains('ngày bắt đầu'));
      expect(check([CourtScheduleRequest(date: DateTime(2026, 12, 7))]), contains('nằm ngoài'));
      expect(check([CourtScheduleRequest(date: s, courtCount: 0)]), contains('từ 1'));
      expect(
        check([CourtScheduleRequest(date: s), CourtScheduleRequest(date: s, session: CourtSession.afternoon)]),
        isNull,
      );
      expect(
        check([CourtScheduleRequest(date: s), CourtScheduleRequest(date: s, session: CourtSession.fullDay)]),
        contains('trùng buổi'),
      );
    });

    test('BTC hủy được tới 24h trước hạn đăng ký; Fair Play < 90 thì khóa', () {
      final deadline = DateTime(2026, 12, 3);
      expect(TournamentRules.canOrganizerCancel(deadline, DateTime(2026, 12, 1, 23)), isTrue);
      expect(TournamentRules.canOrganizerCancel(deadline, DateTime(2026, 12, 2, 1)), isFalse);
      expect(TournamentRules.canOrganizerCancel(null, today), isTrue);
      expect(TournamentRules.fairPlayBlock(89), contains('hiện tại 89'));
      expect(TournamentRules.fairPlayBlock(90), isNull);
      expect(TournamentRules.fairPlayBlock(null), isNull);
    });

    test('gõ không dấu, mọi từ phải có; tên khớp đầu lên trước', () {
      final hits = TournamentRules.matchFacilities(MockHostTournamentRepository.facilities, 'ha noi');
      expect(hits.map((f) => f.id), ['f-cau-giay']);
      expect(
        TournamentRules.matchFacilities(MockHostTournamentRepository.facilities, 'quan 7 sunrise').single.id,
        'f-sunrise',
      );
      final ordered = TournamentRules.matchFacilities(MockHostTournamentRepository.facilities, 'nha');
      expect(ordered.first.id, 'f-phutho');
      expect(TournamentRules.fold('Đường Trần Hưng Đạo'), 'duong tran hung dao');
    });
  });

  group('dữ liệu gửi / đọc BE', () {
    test('tạo giải: body như Web (ngày trơn, mã hình thức, Elo chỉ khi xét Elo, bỏ giải thưởng trống)', () {
      final body = NewTournament(
        facilityId: 'f1',
        categoryId: 'c1',
        name: '  Giải A ',
        start: DateTime(2026, 12, 5),
        end: DateTime(2026, 12, 6),
        deadline: DateTime(2026, 12, 3),
        type: DivisionType.premadeTeams,
        minRating: 1200,
        format: BracketFormat.roundRobin,
        maxParticipants: 6,
        entryFee: 50000,
        prizes: const [
          OrganizerPrize(position: 'Vô địch', amount: 500000),
          OrganizerPrize(position: '', amount: 1),
        ],
        rulesFiles: const [
          TournamentDocument(url: 'u1', name: 'a.pdf'),
          TournamentDocument(url: 'u2', name: 'b.pdf'),
        ],
        contract: const TournamentDocument(url: 'c', name: 'hd.pdf'),
        schedule: [CourtScheduleRequest(date: DateTime(2026, 12, 5), session: CourtSession.evening, courtCount: 2)],
      ).toJson();
      expect(body['name'], 'Giải A');
      expect(body['startDate'], '2026-12-05');
      expect(body['registrationDeadline'], '2026-12-03');
      expect(body['categoryType'], 1);
      expect(body['minRating'], isNull); // Phong trào không xét Elo
      expect(body['defaultBracketFormat'], 'ROUND_ROBIN');
      expect(body['minParticipants'], 4);
      expect(body['prizes'], [
        {'position': 'Vô địch', 'rewardAmount': 500000},
      ]);
      expect(body['rulesFileUrls'], ['u1', 'u2']);
      expect(body['rulesFileUrl'], 'u1');
      expect(body['contractFileUrl'], 'c');
      expect(body['requestedSchedule'], [
        {'date': '2026-12-05', 'session': 'EVENING', 'courtCount': 2},
      ]);
    });

    test('đọc giải: PENDING_ADMIN = chờ duyệt, lý do từ chối, tài liệu cũ 1 file, mã hình thức số', () {
      final t = OrganizedTournament.fromApi({
        'id': 't1',
        'name': 'Giải A',
        'status': 'OPEN',
        'approvalStatus': 'PENDING_ADMIN',
        'categoryType': 2,
        'format': 'GroupKnockout',
        'rulesFileUrl': 'https://f/1.pdf',
        'contractFileUrl': 'https://f/hd.pdf',
        'currentParticipants': 0,
        'requestedSchedule': [
          {'date': '2026-12-05', 'session': 'FULL_DAY', 'courtCount': 3},
        ],
      });
      expect(t.isPendingApproval, isTrue);
      expect(t.group, OrganizedGroup.pending);
      expect(t.statusLabel, 'Chờ Admin duyệt');
      expect(t.type, DivisionType.randomDoubles);
      expect(t.format, BracketFormat.groupKnockout);
      expect(t.documents.map((d) => d.name), ['Tài liệu giải', 'Hợp đồng với chủ sân']);
      expect(t.requestedSchedule.single.session, CourtSession.fullDay);
      expect(t.canDelete, isTrue);
      expect(t.canEditFee, isTrue);

      final r = OrganizedTournament.fromApi({
        'id': 't2',
        'approvalStatus': 'REJECTED',
        'approvalNote': 'Thiếu hợp đồng',
      });
      expect(r.statusLabel, 'Bị từ chối');
      expect(r.approvalNote, 'Thiếu hợp đồng');
      final busy = OrganizedTournament.fromApi({
        'id': 't3',
        'approvalStatus': 'APPROVED',
        'status': 'IN_PROGRESS',
        'registeredCount': 5,
      });
      expect(busy.group, OrganizedGroup.inProgress);
      expect(busy.canDelete, isFalse);
    });
  });

  group('ApiHostTournamentRepository', () {
    late _FakeServer server;
    late ApiHostTournamentRepository repo;

    setUp(() async {
      server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('token');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      repo = ApiHostTournamentRepository(
        api: ApiClient(tokens: tokens, dio: dio),
      );
    });

    test('danh sách / tạo / sửa / hủy / xóa đúng đường dẫn', () async {
      server.ok('GET', ApiHostTournamentRepository.minePath, {
        'items': [
          {'id': 't1', 'name': 'Giải A', 'approvalStatus': 'APPROVED'},
        ],
      });
      server.ok('POST', ApiHostTournamentRepository.basePath, {'tournamentId': 't9', 'approvalStatus': 'PENDING'});
      server.ok('PUT', ApiHostTournamentRepository.detailPath('t1'), null);
      server.ok('PATCH', ApiHostTournamentRepository.cancelPath('t1'), null);
      server.ok('DELETE', ApiHostTournamentRepository.detailPath('t1'), null);

      expect((await repo.getMine()).single.name, 'Giải A');
      final approval = await repo.create(
        NewTournament(
          facilityId: 'f',
          categoryId: 'c',
          name: 'G',
          start: DateTime(2026, 12, 5),
          end: DateTime(2026, 12, 5),
        ),
      );
      expect(approval, ApprovalStatus.pending);
      await repo.updateInfo('t1', const TournamentInfoUpdate(entryFee: 20000));
      expect(server.requests[2].data, {'entryFee': 20000});
      await repo.cancel('t1', '  Trời mưa  ');
      expect(server.requests[3].data, {'reason': 'Trời mưa'});
      await repo.delete('t1');
      expect(server.requests.last.method, 'DELETE');
    });

    test('cơ sở: bỏ cơ sở chưa duyệt; lỗi BE thành TournamentException', () async {
      server.ok('GET', ApiHostTournamentRepository.facilitiesPath, [
        {
          'id': 'f1',
          'name': 'Sân A',
          'streetAddress': '1 Lê Lợi',
          'provinceName': 'Hồ Chí Minh',
          'approvalStatus': 'APPROVED',
        },
        {'id': 'f2', 'name': 'Sân B', 'approvalStatus': 'PENDING'},
      ]);
      final list = await repo.getFacilities();
      expect(list.single.address, '1 Lê Lợi, Hồ Chí Minh');
      await expectLater(repo.getDetail('x'), throwsA(isA<TournamentException>()));
    });
  });

  group('MockHostTournamentRepository', () {
    test('giải mới chờ duyệt; xóa khi chưa ai đăng ký; hủy bị khóa gần hạn', () async {
      final repo = MockHostTournamentRepository(latency: Duration.zero, now: () => today);
      final status = await repo.create(
        NewTournament(
          facilityId: 'f-sunrise',
          categoryId: 'c-pickleball',
          name: 'Giải mới',
          start: DateTime(2026, 12, 5),
          end: DateTime(2026, 12, 6),
          deadline: DateTime(2026, 11, 28),
        ),
      );
      expect(status, ApprovalStatus.pending);
      final mine = await repo.getMine();
      expect(mine.first.isPendingApproval, isTrue);
      expect(mine.first.facilityName, 'Sân Pickleball Sunrise');
      await expectLater(repo.cancel(mine.first.id, 'x'), throwsA(isA<TournamentException>()));
      await repo.delete(mine.first.id);
      expect((await repo.getMine()).any((t) => t.name == 'Giải mới'), isFalse);
      await expectLater(repo.delete('ht-1'), throwsA(isA<TournamentException>())); // đã có 3 người
    });
  });
}
