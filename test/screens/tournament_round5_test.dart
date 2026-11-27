import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/match_strings.dart';
import 'package:test1/core/strings/organizer_strings.dart';
import 'package:test1/core/strings/player_tournament_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_host_tournament_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_host_tournament_repository.dart';
import 'package:test1/data/mock/mock_identity_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_player_tournament_repository.dart';
import 'package:test1/data/mock/mock_report_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/match_scoring.dart';
import 'package:test1/models/organized_tournament.dart';
import 'package:test1/models/owner_court.dart';
import 'package:test1/screens/owner/owner_main_screen.dart';
import 'package:test1/screens/owner/owner_tournament_hub_screen.dart';
import 'package:test1/screens/tournament/match_score_screen.dart';
import 'package:test1/screens/tournament/organized_tournament_screen.dart';
import 'package:test1/screens/tournament/referee_screens.dart';
import 'package:test1/screens/tournament/tournaments_screen.dart';

import '../helpers/layout_check.dart';

/// Giải đấu đợt 5: trang trọng tài, Chủ sân (menu trái, Giải đấu 2 tab, giữ / trả ca).
class _FakeServer implements HttpClientAdapter {
  final Map<String, Object?> routes = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
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

/// Chủ sân: sân của cơ sở cố định; một giải người khác tổ chức tại sân.
class _Host extends MockHostTournamentRepository {
  _Host() : super(latency: Duration.zero);

  @override
  Future<OrganizedTournament> getDetail(String tournamentId) async {
    if (tournamentId != 'other') return super.getDetail(tournamentId);
    final d = DateTime.now().add(const Duration(days: 10));
    return OrganizedTournament(
      id: 'other',
      name: 'Giải Phong trào CLB Bạn',
      approval: ApprovalStatus.approved,
      facilityId: 'f-sunrise',
      facilityName: 'Sân Pickleball Sunrise',
      organizerName: 'Nguyễn Văn Nam',
      start: d,
      end: d,
      deadline: d.subtract(const Duration(days: 3)),
      isOrganizer: false,
    );
  }

  @override
  Future<List<OrganizedTournament>> getMine({bool facilityScope = false}) async {
    if (!facilityScope) return super.getMine();
    return [await getDetail('other')];
  }
}

class _Owner extends MockOwnerRepository {
  _Owner() : super(latency: Duration.zero);

  @override
  Future<List<OwnerCourt>> getCourts(String facilityId) async => const [
    OwnerCourt(id: 'Sân 1', categoryId: 'c', categoryName: 'Pickleball', name: 'Sân 1', defaultPrice: 100000),
    OwnerCourt(id: 'Sân 2', categoryId: 'c', categoryName: 'Pickleball', name: 'Sân 2', defaultPrice: 100000),
  ];
}

void main() {
  group('đọc / gửi BE', () {
    test('trận trọng tài, giữ ca: đọc / gửi như Web', () async {
      final m = StaffMatch.fromApi({
        'matchId': 'm1',
        'rootTournamentId': 'root',
        'tournamentId': 'child',
        'tournamentName': 'Giải A',
        'participant1Name': 'An',
        'participant2Name': 'TBD',
        'roundName': 'Tứ kết (miễn đấu)',
        'staffRole': 'SCORER',
        'isAssignedOfficial': true,
      });
      expect(m.tournamentId, 'root');
      expect(m.sideB, ''); // TBD = chưa xác định
      expect(m.isBye, isTrue);
      expect(m.isReady, isFalse);
      expect(m.roleLabel, 'Người nhập điểm');

      final body = CourtBlockRequest(
        courtIds: const ['c1'],
        dateFrom: DateTime(2026, 12, 5),
        dateTo: DateTime(2026, 12, 6),
        startTime: '08:00',
      ).toJson();
      expect(body, {'courtIds': ['c1'], 'dateFrom': '2026-12-05', 'dateTo': '2026-12-06', 'startTime': '08:00:00', 'endTime': null});
      expect(CourtBlockRequest(dateFrom: DateTime(2026, 12, 5), dateTo: DateTime(2026, 12, 5)).toJson()['courtIds'], isNull);

      final r = CourtBlockResult.fromApi({
        'blockedSlots': 6,
        'alreadyBlockedSlots': 2,
        'conflicts': [
          {'slotId': 's', 'courtName': 'Sân 1', 'startTime': '2026-12-05T08:00:00', 'reason': 'Đã có khách đặt'},
        ],
      });
      expect((r.slots, r.alreadyBlocked, r.conflicts.single.reason), (6, 2, 'Đã có khách đặt'));

      final server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('token');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      final repo = ApiHostTournamentRepository(api: ApiClient(tokens: tokens, dio: dio));
      server.routes['GET ${ApiHostTournamentRepository.staffMatchesPath}'] = {
        'items': [
          {'matchId': 'm1', 'tournamentId': 't1'},
        ],
      };
      expect((await repo.getMyStaffMatches()).single.matchId, 'm1');
      await repo.blockCourts('t1', CourtBlockRequest(courtIds: const ['c1'], dateFrom: DateTime(2026, 12, 5), dateTo: DateTime(2026, 12, 5)));
      expect(server.requests.last.path, ApiHostTournamentRepository.courtBlocksPath('t1'));
      await repo.releaseCourts('t1', CourtBlockRequest(dateFrom: DateTime(2026, 12, 5), dateTo: DateTime(2026, 12, 5)));
      expect(server.requests.last.path, ApiHostTournamentRepository.releaseBlocksPath('t1'));
    });
  });

  group('màn hình', () {
    late _Host host;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      host = _Host();
      AppRepositories.hostTournament = host;
      AppRepositories.identity = MockIdentityRepository(latency: Duration.zero);
      AppRepositories.report = MockReportRepository(latency: Duration.zero);
      AppRepositories.wallet = MockWalletRepository(latency: Duration.zero);
      final teams = MockTeamRepository(latency: Duration.zero);
      AppRepositories.team = teams;
      AppRepositories.playerTournament = MockPlayerTournamentRepository(teams: teams, latency: Duration.zero);
      AppRepositories.owner = _Owner();
      AppRepositories.ownerWallet = MockWalletRepository(latency: Duration.zero, keyPrefix: MockOwnerRepository.ownerWalletPrefix);
      final auth = MockAuthRepository(latency: Duration.zero);
      AppRepositories.auth = auth;
      await auth.login('player@sportnexus.vn', 'Player@123');
    });

    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1600, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: home));
      await tester.pumpAndSettle();
    }

    /// Trọng tài của giải ht-1 (đã sinh sơ đồ): trận thường, trận miễn đấu (ẩn).
    Future<List<StaffMatch>> staffSetup() async {
      await host.generateBracket('ht-1', null);
      final b = await host.getBracket('ht-1');
      return host.staffMatches = [
        StaffMatch(
          matchId: b[1].id,
          tournamentId: 'ht-1',
          tournamentName: 'Giải Pickleball Giao lưu Quận 7',
          facilityName: 'Sân Pickleball Sunrise',
          roundName: 'Bán kết (miễn đấu)',
          sideA: 'Phạm Thu Hà',
          status: 'FINISHED',
          staffRole: 'REFEREE',
        ),
        StaffMatch(
          matchId: b[0].id,
          tournamentId: 'ht-1',
          tournamentName: 'Giải Pickleball Giao lưu Quận 7',
          facilityName: 'Sân Pickleball Sunrise',
          roundName: 'Bán kết',
          sideA: 'Khoa Cao',
          sideB: 'Lê Minh Tuấn',
          staffRole: 'REFEREE',
          isAssignedOfficial: true,
        ),
      ];
    }

    testWidgets('tab "Trận tôi làm trọng tài" chỉ hiện khi có trận để chấm', (tester) async {
      await pump(tester, const TournamentsScreen());
      expect(find.text(MatchStrings.tabReferee), findsNothing);
      await staffSetup();
      await pump(tester, const TournamentsScreen());
      expect(find.text(MatchStrings.tabReferee), findsOneWidget);
      await tester.ensureVisible(find.text(MatchStrings.tabReferee));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MatchStrings.tabReferee));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.refereeIntro(1)), findsOneWidget);
      expect(find.text(MatchStrings.waiting(1)), findsOneWidget);
      expect(find.text(MatchStrings.doneCount(0, 1)), findsOneWidget); // trận miễn đấu bị ẩn
      expect(find.text(PlayerTournamentStrings.tabExplore), findsOneWidget);
    });

    testWidgets('trọng tài: Nhập tỉ số (áp luật điểm danh) và Điểm danh (tìm tên, x/y)', (tester) async {
      final matches = await staffSetup();
      final group = RefereeTournamentGroup.group(matches).single;
      await pump(tester, RefereeTournamentScreen(group: group));
      expect(find.text(MatchStrings.assignedToYou), findsOneWidget);
      expect(find.textContaining('miễn đấu'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, MatchStrings.enterScore));
      await tester.pumpAndSettle();
      expect(find.byType(MatchScoreScreen), findsOneWidget);
      expect(find.text(MatchStrings.scoreOf('Khoa Cao', 'Lê Minh Tuấn')), findsOneWidget);
      expect(find.textContaining('Lê Minh Tuấn chưa điểm danh'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text(MatchStrings.tabCheckIn));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.checkedInCount(1, 3)), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'tuan');
      await tester.pumpAndSettle();
      expect(find.text('Phạm Thu Hà'), findsNothing);
      expect(find.text('Lê Minh Tuấn'), findsOneWidget); // gõ không dấu vẫn ra
      await tester.tap(find.widgetWithText(OutlinedButton, OrganizerStrings.checkIn));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.checkedInDone('Lê Minh Tuấn')), findsOneWidget);
      expect(find.text(MatchStrings.checkedInCount(2, 3)), findsOneWidget);
    });

    testWidgets('Chủ sân: menu trái → Giải đấu, 2 tab; tạo giải tại cơ sở đang quản lý', (tester) async {
      final auth = MockAuthRepository(latency: Duration.zero);
      AppRepositories.auth = auth;
      AppRepositories.owner = _Owner();
      final owner = await auth.login('owner@sportnexus.vn', 'Owner@123');
      await pump(tester, OwnerMainScreen(user: owner));
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.ownerTitle));
      await tester.pumpAndSettle();
      expect(find.byType(OwnerTournamentHubScreen), findsOneWidget);
      expect(find.text(OrganizerStrings.ownerMine), findsOneWidget);
      expect(find.text(OrganizerStrings.ownerAtFacility), findsOneWidget);
      final create = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, OrganizerStrings.createNew));
      expect(create.onPressed, isNotNull); // chủ sân không xét Fair Play / CCCD
      await tester.tap(find.text(OrganizerStrings.createNew));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.contract), findsNothing); // không có ô hợp đồng
      expect(find.text(OrganizerStrings.change), findsNothing); // cơ sở cố định
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.ownerAtFacility));
      await tester.pumpAndSettle();
      expect(find.text('Giải Phong trào CLB Bạn'), findsOneWidget);
      expect(find.text(OrganizerStrings.createNew), findsNothing); // tab giải tại sân không có nút tạo
    });

    testWidgets('Chủ sân xem giải người khác tại sân: chỉ xem + giữ / trả ca, không quản lý', (tester) async {
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'other', ownerMode: true));
      expect(find.text(OrganizerStrings.atFacilityNote('Nguyễn Văn Nam')), findsOneWidget);
      expect(find.text(OrganizerStrings.editInfo), findsNothing);
      expect(find.text(OrganizerStrings.addStaff), findsNothing);
      expect(find.text(MatchStrings.blockTitle), findsOneWidget);
      expect(find.text(MatchStrings.scheduleEmpty), findsOneWidget);

      await tester.tap(find.text(MatchStrings.blockAction));
      await tester.pumpAndSettle();
      expect(find.text(MatchStrings.pickCourt), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Sân 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MatchStrings.blockAction));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã giữ'), findsWidgets);
      expect(find.text(MatchStrings.conflictsTitle(1)), findsOneWidget);
      expect(find.textContaining('✓ đã giữ'), findsWidgets); // lịch sân + chip sân
      expect(find.text(MatchStrings.scheduleEmpty), findsNothing);

      await tester.tap(find.text(MatchStrings.release));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã trả'), findsOneWidget);
      expect(find.text(MatchStrings.scheduleEmpty), findsOneWidget);
    });

    testWidgets('bố cục: tab trọng tài, màn trọng tài 2 tab, Giải đấu Chủ sân, giữ ca', (tester) async {
      final matches = await staffSetup();
      final group = RefereeTournamentGroup.group(matches).single;
      Future<void> scrollToEnd(WidgetTester t) async {
        for (var i = 0; i < 12; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
          await t.pump(const Duration(milliseconds: 200));
        }
      }

      await expectNoOverflow(
        tester,
        'Tab trọng tài',
        () => Scaffold(body: RefereeMatchesTab(matches: matches, onRefresh: () async {})),
      );
      await expectNoOverflow(tester, 'Trọng tài: nhập tỉ số', () => RefereeTournamentScreen(group: group));
      await expectNoOverflow(tester, 'Trọng tài: điểm danh', () => RefereeTournamentScreen(group: group), interact: (t) async {
        await t.tap(find.text(MatchStrings.tabCheckIn));
        await settleFrames(t);
      });
      await expectNoOverflow(
        tester,
        'Giải đấu Chủ sân',
        () => const OwnerTournamentHubScreen(facility: FacilityOption(id: 'f-sunrise', name: 'Sân Pickleball Sunrise')),
      );
      await expectNoOverflow(
        tester,
        'Giữ ca (giải tại sân)',
        () => const OrganizedTournamentScreen(tournamentId: 'other', ownerMode: true),
        interact: scrollToEnd,
      );
    });
  });
}
