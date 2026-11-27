import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/tournament_rules.dart';
import 'package:test1/core/strings/match_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_host_tournament_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_host_tournament_repository.dart';
import 'package:test1/data/mock/mock_identity_repository.dart';
import 'package:test1/data/mock/mock_player_tournament_repository.dart';
import 'package:test1/data/mock/mock_report_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/models/match_scoring.dart';
import 'package:test1/models/tournament_listing.dart';
import 'package:test1/models/tournament_management.dart';
import 'package:test1/screens/tournament/match_score_screen.dart';
import 'package:test1/screens/tournament/organized_tournament_screen.dart';
import 'package:test1/widgets/tournament/organizer_match_sections.dart';

import '../helpers/layout_check.dart';

/// Giải đấu đợt 4: nhập tỉ số + luật điểm danh, lịch sân / xếp sân / trọng tài, khiếu nại phía BTC, nhà vô địch.
class _FakeServer implements HttpClientAdapter {
  final Map<String, Object?> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) => routes['$method $path'] = data;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    final found = routes.containsKey(key);
    return ResponseBody.fromString(
      jsonEncode({'statusCode': found ? 200 : 400, 'message': found ? 'OK' : 'Lỗi', 'data': routes[key]}),
      found ? 200 : 400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _a = MatchSide(id: 'p1', name: 'An');
const _b = MatchSide(id: 'p2', name: 'Bình');

OrganizerParticipant _p(String id, String name, {bool checked = false}) =>
    OrganizerParticipant(participantId: id, name: name, paymentStatus: 'PAID', isCheckedIn: checked);

void main() {
  group('luật tỉ số & điểm danh (như tournamentRules.js)', () {
    test('điểm danh: đủ hai bên / thiếu một bên chỉ xử thắng / thiếu cả hai / chưa có danh sách', () {
      expect(TournamentRules.checkInGate([_a, _b], null), isNull);
      expect(
        TournamentRules.checkInGate([_a, _b], [_p('p1', 'An', checked: true), _p('p2', 'Bình', checked: true)])!.mode,
        CheckInGateMode.ok,
      );
      final one = TournamentRules.checkInGate([_a, _b], [_p('p1', 'An', checked: true), _p('p2', 'Bình')])!;
      expect(one.mode, CheckInGateMode.walkoverOnly);
      expect(one.message, 'Bình chưa điểm danh: chỉ được xử thắng cho An, hoặc điểm danh trước khi nhập tỉ số.');
      final none = TournamentRules.checkInGate([_a, _b], [_p('p1', 'An'), _p('p2', 'Bình')])!;
      expect(none.mode, CheckInGateMode.blocked);
      // Thiếu id thì so theo tên.
      final byName = TournamentRules.checkInGate(
        [const MatchSide(id: '', name: 'An'), const MatchSide(id: '', name: 'Bình')],
        [_p('x1', 'An', checked: true), _p('x2', 'Bình', checked: true)],
      )!;
      expect(byName.mode, CheckInGateMode.ok);
    });

    test('body tỉ số: bình thường / xử thắng / bỏ cuộc / luân lưu', () {
      var (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.normal, sets: [('21', '15'), ('', ''), ('19', '21')]);
      expect(error, isNull);
      expect(body!['sets'], [
        {'setNumber': 1, 'scoreP1': 21, 'scoreP2': 15},
        {'setNumber': 2, 'scoreP1': 19, 'scoreP2': 21},
      ]);
      expect(body['resultType'], 'NORMAL');
      expect(body['winnerId'], isNull);

      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.normal, sets: [('', '')]);
      expect(error, 'Nhập tỉ số ít nhất 1 hiệp.');
      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.walkover, sets: const []);
      expect(error, 'Chọn bên được xử thắng.');
      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.walkover, sets: [('3', '1')], winnerId: 'p1');
      expect(body, {'sets': [], 'winnerId': 'p1', 'tiebreakP1': null, 'tiebreakP2': null, 'resultType': 'WALKOVER'});
      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.retired, sets: [('11', '5')]);
      expect(error, 'Chọn bên thắng (bên còn lại bỏ cuộc).');
      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.retired, sets: [('11', '5')], winnerId: 'p2');
      expect(body!['winnerId'], 'p2');
      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.normal, sets: [('1', '1')], tiebreak: ('4', '4'));
      expect(error, contains('luân lưu'));
      (body, error) = TournamentRules.buildScorePayload(kind: ScoreKind.normal, sets: [('1', '1')], tiebreak: ('5', '4'));
      expect((body!['tiebreakP1'], body['tiebreakP2']), (5, 4));
    });

    test('đọc trận / lịch sân / ca xếp được / khiếu nại', () {
      final m = MatchDetail.fromApi({
        'id': 'm1',
        'tournamentId': 't1',
        'roundName': 'Tứ kết (miễn đấu)',
        'participant1Id': 'p1',
        'participant1Name': 'An',
        'participant2Id': 'p2',
        'participant2Name': 'Bình',
        'sportName': 'Bóng Đá',
        'stage': 'GROUP',
        'scores': [
          {'setNumber': 1, 'scoreP1': 2, 'scoreP2': 2},
          {'setNumber': 2, 'scoreP1': 5, 'scoreP2': 4, 'isTiebreak': true},
        ],
      });
      expect(m.roundName, 'Tứ kết');
      expect(m.sides.map((s) => s.id), ['p1', 'p2']);
      expect(m.sets.length, 1);
      expect(m.isFootball, isTrue);
      expect(m.stage, MatchStage.group);

      final s = CourtSchedule.fromApi({
        'blocks': [
          {'courtName': 'Sân 1', 'startTime': '2026-12-05T08:00:00', 'endTime': '2026-12-05T12:00:00', 'slotCount': 4},
        ],
        'matches': [
          {'matchId': 'm1', 'courtName': 'Sân 1', 'startTime': '2026-12-05T08:00:00'},
          {'matchId': 'm2', 'startTime': '2026-12-05T09:00:00'}, // chưa có sân: bỏ
        ],
      });
      expect(s.blocks.single.slotCount, 4);
      expect(s.matches.single.matchId, 'm1');
      expect(s.of('m1')?.courtName, 'Sân 1');

      final slots = AssignableSlot.fromFacilitySlots({
        'courts': [
          {
            'courtName': 'Sân 2',
            'slots': [
              {'id': 's1', 'startTime': '2026-12-05T10:00:00', 'endTime': '2026-12-05T11:00:00', 'status': 'AVAILABLE'},
              {'id': 's2', 'startTime': '2026-12-05T08:00:00', 'endTime': '2026-12-05T09:00:00', 'tournamentId': 't1', 'status': 'BLOCKED'},
              {'id': 's3', 'startTime': '2026-12-05T09:00:00', 'endTime': '2026-12-05T10:00:00', 'status': 'AVAILABLE', 'bookingId': 'b1'},
              {'id': 's4', 'startTime': '2026-12-05T07:00:00', 'endTime': '2026-12-05T08:00:00', 'status': 'AVAILABLE', 'isPast': true},
              {'id': 's5', 'startTime': '2026-12-05T12:00:00', 'endTime': '2026-12-05T13:00:00', 'tournamentId': 'khác', 'status': 'BLOCKED'},
            ],
          },
        ],
      }, 't1');
      expect(slots.map((x) => x.id), ['s2', 's1']);
      expect(slots.first.reservedForTournament, isTrue);

      final c = MatchComplaintItem.fromApi({'id': 'c1', 'matchId': 'm1', 'status': 'OWNER_RESPONDED', 'participant1Name': 'An'});
      expect(c.canAct, isFalse);
      expect(c.statusLabel, 'BTC đã quyết định, chờ Admin');
      expect(c.sideB, '—');
    });

    test('API: đường dẫn + body như Web', () async {
      final server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('token');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      final repo = ApiHostTournamentRepository(api: ApiClient(tokens: tokens, dio: dio));
      server.ok('PUT', ApiHostTournamentRepository.scorePath('m1'), null);
      server.ok('PUT', ApiHostTournamentRepository.assignCourtPath('m1'), {'courtName': 'Sân 1'});
      server.ok('PUT', ApiHostTournamentRepository.officialsPath('m1'), null);
      server.ok('POST', ApiHostTournamentRepository.autoSchedulePath('t1'), null);
      server.ok('GET', ApiHostTournamentRepository.complaintsPath('t1'), {'items': []});
      server.ok('POST', ApiHostTournamentRepository.decideComplaintPath('c1'), null);
      server.ok('POST', ApiHostTournamentRepository.resolveComplaintPath('c1'), null);
      server.ok('GET', ApiHostTournamentRepository.facilitySlotsPath('f1'), {'courts': []});

      await repo.updateScore('m1', {'resultType': 'NORMAL'});
      expect(server.requests.last.data, {'resultType': 'NORMAL'});
      await repo.assignCourt('m1', 's9');
      expect(server.requests.last.data, {'courtSlotId': 's9'});
      await repo.assignOfficials('m1', ['st1']);
      expect(server.requests.last.data, {'staffIds': ['st1']});
      await repo.autoSchedule('t1');
      await repo.getMatchComplaints('t1', openOnly: false);
      expect(server.requests.last.queryParameters, {'status': 'ALL'});
      await repo.decideComplaint('c1', accept: false, note: ' Đã xem biên bản ');
      expect(server.requests.last.data, {'decision': 'REJECT', 'note': 'Đã xem biên bản'});
      await repo.resolveComplaintWithScore('c1', {'resultType': 'NORMAL'}, '');
      expect(server.requests.last.data, {'action': 'UPDATE_SCORE', 'score': {'resultType': 'NORMAL'}, 'note': null});
      await repo.getAssignableSlots('f1', 't1', DateTime(2026, 12, 5));
      expect(server.requests.last.queryParameters, {'date': '2026-12-05'});
    });
  });

  group('màn BTC', () {
    late MockHostTournamentRepository host;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      host = MockHostTournamentRepository(latency: Duration.zero);
      AppRepositories.hostTournament = host;
      AppRepositories.identity = MockIdentityRepository(latency: Duration.zero);
      AppRepositories.report = MockReportRepository(latency: Duration.zero);
      AppRepositories.playerTournament = MockPlayerTournamentRepository(
        teams: MockTeamRepository(latency: Duration.zero),
        latency: Duration.zero,
      );
      final auth = MockAuthRepository(latency: Duration.zero);
      AppRepositories.auth = auth;
      await auth.login('player@sportnexus.vn', 'Player@123');
    });

    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1600, 9000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: home));
      await tester.pumpAndSettle();
    }

    testWidgets('nhập tỉ số: thiếu một bên điểm danh chỉ được xử thắng; đủ hai bên nhập bình thường', (tester) async {
      await host.generateBracket('ht-1', null);
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'ht-1'));
      expect(find.text(MatchStrings.tapToScore), findsOneWidget);

      await tester.tap(find.text('Lê Minh Tuấn (chưa điểm danh)'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchScoreScreen), findsOneWidget);
      expect(find.textContaining('Lê Minh Tuấn chưa điểm danh: chỉ được xử thắng cho Khoa Cao'), findsOneWidget);
      expect(find.text(MatchStrings.wins('Lê Minh Tuấn')), findsNothing);
      expect(find.text(MatchStrings.wins('Khoa Cao')), findsOneWidget);
      await tester.tap(find.text(MatchStrings.saveScore));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.scoreSaved), findsOneWidget);
      expect((await host.getBracket('ht-1')).first.winner, 'Khoa Cao');
    });

    testWidgets('nhập tỉ số đủ điểm danh: 2 hiệp, lưu; trận miễn đấu không bấm được', (tester) async {
      await host.checkIn('ht-1', 'p-2');
      await host.generateBracket('ht-1', null);
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'ht-1'));
      await tester.tap(find.text('Lê Minh Tuấn').last); // ô trong sơ đồ (sau danh sách người tham gia)
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa điểm danh'), findsNothing);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '21');
      await tester.enterText(fields.at(1), '15');
      await tester.tap(find.text(MatchStrings.addSet));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '18');
      await tester.enterText(find.byType(TextField).at(3), '21');
      await tester.tap(find.text(MatchStrings.addSet));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(4), '21');
      await tester.enterText(find.byType(TextField).at(5), '19');
      await tester.tap(find.text(MatchStrings.saveScore));
      await tester.pumpAndSettle();
      final m = (await host.getBracket('ht-1')).first;
      expect(m.winner, 'Khoa Cao');
      expect(m.scores.length, 3);
      // Trận miễn đấu (Phạm Thu Hà vs chưa xác định): bấm không mở màn nhập.
      await tester.tap(find.text('Chưa xác định'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchScoreScreen), findsNothing);
    });

    testWidgets('nhập tỉ số: cả hai chưa điểm danh thì không lưu được', (tester) async {
      await host.removeParticipant('ht-1', 'p-1');
      await host.generateBracket('ht-1', null); // Lê Minh Tuấn vs Phạm Thu Hà, cả hai chưa điểm danh
      final id = (await host.getBracket('ht-1')).first.id;
      await pump(
        tester,
        MatchScoreScreen(matchId: id, requireCheckIn: true, onSubmit: (p, n) => host.updateScore(id, p)),
      );
      expect(find.textContaining('cần điểm danh trước khi nhập kết quả'), findsOneWidget);
      final save = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, MatchStrings.saveScore));
      expect(save.onPressed, isNull);
    });

    testWidgets('chung kết xong → giải kết thúc, hiện nhà vô địch', (tester) async {
      await host.removeParticipant('ht-1', 'p-3');
      await host.checkIn('ht-1', 'p-2');
      await host.generateBracket('ht-1', null);
      final id = (await host.getBracket('ht-1')).single.id;
      await host.updateScore(id, {
        'sets': [
          {'setNumber': 1, 'scoreP1': 11, 'scoreP2': 5},
        ],
        'winnerId': null,
        'resultType': 'NORMAL',
      });
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'ht-1'));
      expect(find.text(MatchStrings.champion('Khoa Cao')), findsOneWidget);
      expect(find.text('Đã kết thúc'), findsOneWidget);
    });

    testWidgets('lịch sân: tự xếp ca + trọng tài, phân trọng tài, xếp sân từng trận', (tester) async {
      await host.addStaff(
        'ht-1',
        const StaffDraft(fullName: 'Trọng Tài Minh', phone: '0912345678', role: StaffRole.referee, accountId: 'u-ref-1'),
      );
      await host.generateBracket('ht-1', null);
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'ht-1'));
      expect(find.text(MatchStrings.scheduleEmpty), findsOneWidget);
      expect(find.text(MatchStrings.notScheduled), findsNWidgets(2));

      await tester.tap(find.text(MatchStrings.autoSchedule));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.autoScheduled), findsOneWidget);
      expect(find.text(MatchStrings.scheduleEmpty), findsNothing);
      expect(find.textContaining('✓ đã giữ'), findsOneWidget);
      expect(find.text(MatchStrings.notScheduled), findsOneWidget); // trận miễn đấu đã có kết quả, không xếp
      final matchId = (await host.getBracket('ht-1')).first.id;
      expect(host.officialsOf(matchId), isNotEmpty);

      // Phân trọng tài tay cho trận đầu.
      await tester.tap(find.text(MatchStrings.pickReferee).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trọng Tài Minh').last);
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.refereeSet), findsOneWidget);

      // Đổi sân trận đầu (chờ thông báo cũ tắt để không che nút).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MatchStrings.changeCourt).first);
      await tester.pumpAndSettle();
      expect(find.byType(AssignCourtScreen), findsOneWidget);
      expect(find.text(MatchStrings.reserved), findsWidgets);
      await tester.tap(find.textContaining('Sân 2').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, MatchStrings.assignCourt));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã xếp Sân 2'), findsOneWidget);
      expect((await host.getCourtSchedule('ht-1')).of(matchId)?.courtName, 'Sân 2');
    });

    testWidgets('khiếu nại: giữ kết quả cần lý do; sửa tỉ số & đóng', (tester) async {
      await host.checkIn('ht-1', 'p-2');
      await host.generateBracket('ht-1', null);
      final id = (await host.getBracket('ht-1')).first.id;
      for (final c in ['c1', 'c2']) {
        host.seedComplaint(
          'ht-1',
          MatchComplaintItem(
            id: c,
            matchId: id,
            sideA: 'Khoa Cao',
            sideB: 'Lê Minh Tuấn',
            reporterName: 'Lê Minh Tuấn',
            reason: 'WRONG_SCORE',
            description: 'Hiệp 2 ghi nhầm',
            createdAt: DateTime(2026, 11, 27, 9),
          ),
        );
      }
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'ht-1'));
      expect(find.text(MatchStrings.complaintsTitle(2)), findsOneWidget);
      expect(find.textContaining('Tỉ số ghi sai'), findsNWidgets(2));

      await tester.tap(find.text(MatchStrings.keepResult).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(MatchStrings.confirmKeep));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.noteRequired), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, MatchStrings.keepHint), 'Đã đối chiếu biên bản');
      await tester.tap(find.text(MatchStrings.confirmKeep));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.kept), findsOneWidget);
      expect(find.text(MatchStrings.complaintsTitle(1)), findsOneWidget);

      await tester.tap(find.text(MatchStrings.fixScore));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.fixTitle), findsOneWidget);
      expect(find.textContaining('chưa điểm danh'), findsNothing); // khiếu nại không áp luật điểm danh
      await tester.enterText(find.byType(TextField).at(0), '21');
      await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.enterText(find.widgetWithText(TextField, MatchStrings.note), 'Sửa set 1');
      await tester.tap(find.widgetWithText(ElevatedButton, MatchStrings.fixScore));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.fixed), findsOneWidget);
      expect(find.text(MatchStrings.noOpenComplaints), findsOneWidget);
      final all = await host.getMatchComplaints('ht-1', openOnly: false);
      expect(all.map((c) => c.status), [ComplaintStatus.rejected, ComplaintStatus.resolved]);
    });

    testWidgets('bố cục: màn nhập tỉ số, màn xếp sân, màn quản lý khi đang thi đấu', (tester) async {
      await host.addStaff(
        'ht-1',
        const StaffDraft(fullName: 'Trọng Tài Có Tên Rất Dài', phone: '0912345678', role: StaffRole.referee, accountId: 'u'),
      );
      await host.generateBracket('ht-1', null);
      await host.autoSchedule('ht-1');
      final matches = await host.getBracket('ht-1');
      host.seedComplaint(
        'ht-1',
        MatchComplaintItem(
          id: 'c1',
          matchId: matches.first.id,
          sideA: 'Khoa Cao',
          sideB: 'Lê Minh Tuấn',
          reason: 'WRONG_SCORE',
          description: 'Mô tả khiếu nại khá dài để kiểm tra xuống dòng trên máy nhỏ',
          createdAt: DateTime(2026, 11, 27, 9),
        ),
      );
      final t = await host.getDetail('ht-1');
      Future<void> scrollToEnd(WidgetTester t) async {
        for (var i = 0; i < 20; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
          await t.pump(const Duration(milliseconds: 200));
        }
      }

      await expectNoOverflow(
        tester,
        'Nhập tỉ số (chỉ xử thắng)',
        () => MatchScoreScreen(matchId: matches.first.id, requireCheckIn: true, onSubmit: (p, n) async {}),
      );
      await expectNoOverflow(
        tester,
        'Sửa tỉ số kèm ghi chú',
        () => MatchScoreScreen(matchId: matches.first.id, withNote: true, onSubmit: (p, n) async {}),
        interact: (t) async {
          for (var i = 0; i < 4; i++) {
            final add = find.text(MatchStrings.addSet);
            if (add.evaluate().isEmpty) break;
            await t.ensureVisible(add);
            await settleFrames(t);
            await t.tap(add);
            await settleFrames(t);
          }
          await scrollToEnd(t);
        },
      );
      await expectNoOverflow(tester, 'Xếp sân', () => AssignCourtScreen(tournament: t, match: matches.first, initialDate: t.start));
      await expectNoOverflow(
        tester,
        'Quản lý khi đang thi đấu',
        () => const OrganizedTournamentScreen(tournamentId: 'ht-1'),
        interact: scrollToEnd,
      );
    });
  });
}
