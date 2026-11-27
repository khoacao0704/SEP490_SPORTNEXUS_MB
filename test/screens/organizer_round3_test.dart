import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/organizer_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_host_tournament_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_host_tournament_repository.dart';
import 'package:test1/data/mock/mock_identity_repository.dart';
import 'package:test1/models/organized_tournament.dart';
import 'package:test1/models/tournament_listing.dart';
import 'package:test1/models/tournament_management.dart';
import 'package:test1/screens/tournament/organized_tournament_screen.dart';

import '../helpers/layout_check.dart';

/// Giải đấu đợt 3: người tham gia + điểm danh, mời giải nội bộ, thiếu người, nhân sự, sinh sơ đồ.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) => routes['$method $path'] = (200, data);
  void fail(String method, String path, int code) => routes['$method $path'] = (code, null);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (code, data) = routes['${options.method} ${options.path}'] ?? (400, null);
    return ResponseBody.fromString(
      jsonEncode({'statusCode': code, 'message': code == 200 ? 'OK' : 'Lỗi', 'data': data}),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('đọc / gửi BE', () {
    late _FakeServer server;
    late ApiHostTournamentRepository repo;

    setUp(() async {
      server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('token');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      repo = ApiHostTournamentRepository(api: ApiClient(tokens: tokens, dio: dio));
    });

    test('người tham gia: đội kèm thành viên, đã điểm danh, lệ phí', () async {
      server.ok('GET', ApiHostTournamentRepository.participantsPath('t1'), [
        {
          'participantId': 'p1',
          'fullName': 'Khoa',
          'teamName': 'Smash',
          'teamMembers': [
            {'fullName': 'Khoa'},
            {'fullName': 'Tuấn'},
          ],
          'paymentStatus': 'PAID',
          'checkedInAt': '2026-11-27T08:00:00Z',
        },
        {'participantId': 'p2', 'fullName': 'Hà', 'username': 'ha', 'paymentStatus': 'PENDING'},
      ]);
      final list = await repo.getParticipants('t1');
      expect(list[0].displayName, 'Smash');
      expect(list[0].members, ['Khoa', 'Tuấn']);
      expect(list[0].isCheckedIn, isTrue);
      expect(list[0].paymentLabel, 'Đã đóng lệ phí');
      expect(list[1].isPaid, isFalse);
      expect(list[1].paymentLabel, 'Chưa đóng lệ phí');
    });

    test('mời / quyết định / điểm danh / sinh sơ đồ / nhân sự gửi đúng body', () async {
      server.ok('POST', ApiHostTournamentRepository.invitationsPath('t1'), null);
      server.ok('POST', ApiHostTournamentRepository.decisionPath('t1'), null);
      server.ok('POST', ApiHostTournamentRepository.checkInPath('t1'), null);
      server.ok('POST', ApiHostTournamentRepository.generatePath('t1'), null);
      server.ok('POST', ApiHostTournamentRepository.staffPath('t1'), null);
      server.ok('GET', ApiHostTournamentRepository.teamsPath, {
        'items': [
          {'id': 'team-1', 'name': 'Smash', 'captainName': 'Khoa', 'totalMembers': 2},
        ],
      });

      await repo.invite('t1', teamId: 'team-1');
      expect(server.requests.last.data, {'userId': null, 'phone': null, 'teamId': 'team-1', 'message': null});
      await repo.invite('t1', phone: ' 0912345678 ');
      expect((server.requests.last.data as Map)['phone'], '0912345678');
      await repo.decideRegistration('t1', proceed: false, reason: '  Ít người ');
      expect(server.requests.last.data, {'decision': 'CANCEL', 'newDeadline': null, 'reason': 'Ít người'});
      await repo.decideRegistration('t1', proceed: true);
      expect((server.requests.last.data as Map)['decision'], 'CONTINUE');
      await repo.checkIn('t1', 'p1');
      expect(server.requests.last.data, {'participantId': 'p1', 'qrCode': null});
      await repo.generateBracket('t1', BracketFormat.roundRobin);
      expect(server.requests.last.queryParameters, {'format': 'ROUND_ROBIN'});
      await repo.addStaff(
        't1',
        const StaffDraft(fullName: ' Minh ', phone: '0912', role: StaffRole.referee, accountId: 'u1'),
      );
      expect(server.requests.last.data, {
        'fullName': 'Minh',
        'phone': '0912',
        'role': 'REFEREE',
        'accountId': 'u1',
        'note': null,
      });
      final teams = await repo.searchTeams('smash', categoryId: 'c1');
      expect(teams.single.captainName, 'Khoa');
      expect(server.requests.last.queryParameters, {
        'keyword': 'smash',
        'pageSize': 20,
        'excludeLocked': true,
        'sportCategoryId': 'c1',
      });
    });

    test('tra cứu SĐT: có thì lấy id + họ tên; 404 = không có', () async {
      server.ok('GET', ApiHostTournamentRepository.lookupPath, {'id': 'u9', 'fullName': 'Trọng Tài', 'phoneMasked': '09***'});
      expect((await repo.lookupAccount('0912345678'))?.fullName, 'Trọng Tài');
      server.fail('GET', ApiHostTournamentRepository.lookupPath, 404);
      expect(await repo.lookupAccount('0999999999'), isNull);
    });

    test('thiếu người chỉ khi đã duyệt, còn mở, quá hạn và < 4', () {
      final now = DateTime(2026, 11, 27, 12);
      OrganizedTournament t({int count = 2, String approval = 'APPROVED', String deadline = '2026-11-27T10:00:00'}) =>
          OrganizedTournament.fromApi({
            'id': 't',
            'status': 'OPEN',
            'approvalStatus': approval,
            'registrationDeadline': deadline,
            'registeredCount': count,
          });
      expect(t().needsRegistrationDecision(now), isTrue);
      expect(t(count: 4).needsRegistrationDecision(now), isFalse);
      expect(t(approval: 'PENDING').needsRegistrationDecision(now), isFalse);
      expect(t(deadline: '2026-11-27T14:00:00').needsRegistrationDecision(now), isFalse);
    });
  });

  group('màn quản lý giải', () {
    late MockHostTournamentRepository host;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      host = MockHostTournamentRepository(latency: Duration.zero);
      AppRepositories.hostTournament = host;
      AppRepositories.identity = MockIdentityRepository(latency: Duration.zero);
      final auth = MockAuthRepository(latency: Duration.zero);
      AppRepositories.auth = auth;
      await auth.login('player@sportnexus.vn', 'Player@123');
    });

    Future<void> pump(WidgetTester tester, String id) async {
      tester.view.physicalSize = const Size(1600, 8000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: OrganizedTournamentScreen(tournamentId: id)));
      await tester.pumpAndSettle();
    }

    testWidgets('điểm danh (chưa đóng lệ phí thì BE chặn), xóa người, giải công khai không có ô mời', (tester) async {
      await pump(tester, 'ht-1');
      expect(find.text(OrganizerStrings.participantsTitle(false, 3, 8)), findsOneWidget);
      expect(find.text(OrganizerStrings.publicNote), findsOneWidget);
      expect(find.text(OrganizerStrings.checkedIn), findsOneWidget);

      await tester.tap(find.text(OrganizerStrings.checkIn).first); // Lê Minh Tuấn, đã đóng
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.checkedInDone('Lê Minh Tuấn')), findsOneWidget);
      expect(find.text(OrganizerStrings.checkedIn), findsNWidgets(2));

      await tester.tap(find.text(OrganizerStrings.checkIn)); // Phạm Thu Hà, chưa đóng
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa đóng lệ phí'), findsWidgets);

      await tester.tap(find.byTooltip(OrganizerStrings.remove).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.remove).last);
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.removed('Phạm Thu Hà')), findsOneWidget);
      expect(find.text(OrganizerStrings.participantsTitle(false, 2, 8)), findsOneWidget);
    });

    testWidgets('chốt danh sách & sinh nhánh: hỏi lại, giải sang Đang thi đấu, sơ đồ hiện "chưa điểm danh"', (tester) async {
      await pump(tester, 'ht-1');
      expect(find.text(OrganizerStrings.formatSummary('Loại trực tiếp', 3, false, 2)), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.generate));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.generateConfirm), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.generate).last);
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.generated), findsOneWidget);
      expect(find.text('Đang thi đấu'), findsOneWidget);
      expect(find.text(OrganizerStrings.bracketTitle), findsOneWidget);
      expect(find.text('Lê Minh Tuấn (chưa điểm danh)'), findsOneWidget);
      expect(find.text('Khoa Cao'), findsNWidgets(2)); // danh sách + sơ đồ (đã điểm danh)
      // Đã chốt: vẫn điểm danh được, không còn xóa người.
      expect(find.byTooltip(OrganizerStrings.remove), findsNothing);
    });

    testWidgets('giải nội bộ theo đội: tìm đội → mời → thu hồi; quá hạn thiếu người → hủy (hỏi lại)', (tester) async {
      await pump(tester, 'ht-3');
      expect(find.text(OrganizerStrings.shortTitle), findsOneWidget);
      expect(find.text(OrganizerStrings.publicNote), findsNothing);
      expect(find.text('Khoa Cao, Lê Minh Tuấn • Đã đóng lệ phí'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, OrganizerStrings.inviteTeamHint), 'cau long');
      await tester.pumpAndSettle();
      expect(find.text('Cầu Lông Phú Thọ'), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.invite));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.invitedTeam), findsOneWidget);
      expect(find.text('Cầu Lông Phú Thọ (Nguyễn Văn Nam)'), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.revoke));
      await tester.pumpAndSettle();
      expect(find.text(TournamentInvitationStatus.cancelled.label), findsOneWidget);

      await tester.tap(find.text(OrganizerStrings.cancelRefund));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.confirm));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.cancelRefundConfirm), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.confirm).last);
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.decided), findsOneWidget);
      expect((await host.getDetail('ht-3')).isCancelled, isTrue);
      expect(find.text(OrganizerStrings.shortTitle), findsNothing);
    });

    testWidgets('nhân sự: trọng tài phải tìm tài khoản; thêm, sửa, xóa', (tester) async {
      await pump(tester, 'ht-2');
      await tester.tap(find.text(OrganizerStrings.addStaff));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.staffNeedAccount), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, OrganizerStrings.phone), '0912345678');
      await tester.pump();
      await tester.tap(find.text(OrganizerStrings.find));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.accountLinked), findsOneWidget);
      expect(find.text('Trọng Tài Minh'), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.addStaff));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.staffAdded), findsOneWidget);
      expect(find.text(OrganizerStrings.staffTitle(1)), findsOneWidget);

      await tester.tap(find.text(OrganizerStrings.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, OrganizerStrings.note), 'Sân 1');
      await tester.tap(find.text(OrganizerStrings.save));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.staffUpdated), findsOneWidget);
      expect((await host.getStaff('ht-2')).single.note, 'Sân 1');

      await tester.tap(find.byTooltip(OrganizerStrings.remove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.remove).last);
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.staffTitle(0)), findsOneWidget);
    });

    testWidgets('bố cục: giải công khai, giải nội bộ theo đội (thiếu người), sau khi sinh sơ đồ', (tester) async {
      Future<void> scrollToEnd(WidgetTester t) async {
        for (var i = 0; i < 16; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
          await t.pump(const Duration(milliseconds: 200));
        }
      }

      await expectNoOverflow(
        tester,
        'Giải công khai',
        () => const OrganizedTournamentScreen(tournamentId: 'ht-1'),
        interact: scrollToEnd,
      );
      await expectNoOverflow(
        tester,
        'Giải nội bộ theo đội',
        () => const OrganizedTournamentScreen(tournamentId: 'ht-3'),
        interact: (t) async {
          await t.enterText(find.widgetWithText(TextField, OrganizerStrings.inviteTeamHint), 'smash');
          await settleFrames(t);
          await scrollToEnd(t);
        },
      );
      await host.generateBracket('ht-1', null);
      await expectNoOverflow(
        tester,
        'Sau khi sinh sơ đồ',
        () => const OrganizedTournamentScreen(tournamentId: 'ht-1'),
        interact: scrollToEnd,
      );
    });
  });
}
