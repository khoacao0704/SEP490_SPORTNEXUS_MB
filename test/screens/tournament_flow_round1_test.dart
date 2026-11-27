import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/player_tournament_strings.dart';
import 'package:test1/core/strings/report_strings.dart';
import 'package:test1/data/api/api_player_tournament_repository.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_player_tournament_repository.dart';
import 'package:test1/data/mock/mock_report_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/player_report.dart';
import 'package:test1/models/tournament_listing.dart';
import 'package:test1/screens/report/support_center_screen.dart';
import 'package:test1/screens/tournament/tournament_detail_screen.dart';
import 'package:test1/screens/tournament/tournament_ticket_screen.dart';
import 'package:test1/screens/tournament/tournaments_screen.dart';

import '../helpers/layout_check.dart';

/// Giải đấu đợt 1 (người chơi, luồng 26/11).
class _FakeTournaments extends MockPlayerTournamentRepository {
  bool checkedIn = false;
  List<MyTournamentMatch> matches = const [];

  _FakeTournaments(MockTeamRepository teams) : super(teams: teams, latency: Duration.zero);

  @override
  Future<TournamentTicket> getTicket(String divisionId) async =>
      TournamentTicket(tournamentName: 'Giải A', fullName: 'Khoa Cao', qrCode: 'TN-1', isCheckedIn: checkedIn);

  @override
  Future<List<MyTournamentMatch>> getMyMatches() async => matches;
}

void main() {
  late _FakeTournaments tournaments;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppRepositories.wallet = MockWalletRepository(latency: Duration.zero);
    final teams = MockTeamRepository(latency: Duration.zero);
    AppRepositories.team = teams;
    tournaments = _FakeTournaments(teams);
    AppRepositories.playerTournament = tournaments;
    AppRepositories.report = MockReportRepository(latency: Duration.zero);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: home));
    await tester.pumpAndSettle();
  }

  group('đọc dữ liệu BE (giải 1 tầng)', () {
    test('giải: BTC, giới thiệu, thể thức, điều kiện Elo; nội dung: số đã đăng ký, đủ người', () {
      final d = ApiPlayerTournamentRepository.detailsFromApi({
        'id': 't1',
        'name': 'Giải Cầu Lông',
        'status': 'OPEN',
        'categoryType': 'SINGLES',
        'maxParticipants': 8,
        'registeredCount': 8,
        'isFull': true,
        'organizerName': 'CLB Quận 7',
        'description': 'Giao lưu cuối năm',
        'format': 'ROUND_ROBIN',
        'tier': 'SEMI_PRO',
        'minRating': 1200,
        'maxRating': 1600,
        'minRatedMatches': 3,
      });
      expect(d.info.organizerName, 'CLB Quận 7');
      expect(d.info.description, 'Giao lưu cuối năm');
      expect(PlayerTournamentStrings.formatLabel(d.info.format), 'Vòng tròn');
      expect(PlayerTournamentStrings.eloCondition(d.info.minRating, d.info.maxRating, d.info.minRatedMatches),
          'từ 1200, đến 1600, ít nhất 3 trận giải');
      expect(d.divisions.single.registeredCount, 8);
      expect(d.divisions.single.isFull, isTrue);
      expect(d.info.tier!.label, 'Bán chuyên');
    });

    test('đăng ký đã điểm danh; trận có kết quả lúc nào; vé đã check-in', () {
      final r = ApiPlayerTournamentRepository.registrationFromApi({'tournamentId': 't1', 'checkedInAt': '2026-11-27T08:00:00Z'});
      expect(r.isCheckedIn, isTrue);
      final m = ApiPlayerTournamentRepository.myMatchFromApi({
        'matchId': 'm1',
        'status': 'FINISHED',
        'winnerName': 'A',
        'completedAt': '2026-11-27T09:00:00Z',
      });
      expect(m.resultAt, DateTime.parse('2026-11-27T09:00:00Z').toLocal());
    });
  });

  group('luật', () {
    test('khiếu nại kết quả trận chỉ trong 15 phút sau khi có kết quả', () {
      final at = DateTime(2026, 11, 27, 10);
      final m = MyTournamentMatch(matchId: 'm', tournamentName: 'G', mySide: 'A', opponent: 'B', winner: 'A', resultAt: at);
      expect(m.canComplainAt(at.add(const Duration(minutes: 14))), isTrue);
      expect(m.canComplainAt(at.add(const Duration(minutes: 16))), isFalse);
      const noResult = MyTournamentMatch(matchId: 'm', tournamentName: 'G', mySide: 'A', opponent: 'B');
      expect(noResult.canComplainAt(at), isFalse);
    });

    test('chuyển Admin: một lần, trong 24h sau BTC quyết định, hoặc BTC quá 24h chưa xử lý', () {
      final created = DateTime(2026, 11, 27, 10);
      PlayerReport r({DateTime? decided, bool escalated = false, ReportStatus status = ReportStatus.pending}) => PlayerReport(
            id: 'r',
            status: status,
            targetType: 'MATCH',
            reason: 'OTHER',
            description: 'x',
            createdAt: created,
            organizerDecidedAt: decided,
            isEscalatedToAdmin: escalated,
          );
      expect(r().canEscalateAt(created.add(const Duration(hours: 2))), isFalse);
      expect(r().canEscalateAt(created.add(const Duration(hours: 25))), isTrue);
      final decided = created.add(const Duration(hours: 1));
      expect(r(decided: decided).canEscalateAt(decided.add(const Duration(hours: 23))), isTrue);
      expect(r(decided: decided).canEscalateAt(decided.add(const Duration(hours: 25))), isFalse);
      expect(r(escalated: true).canEscalateAt(created.add(const Duration(hours: 30))), isFalse);
    });
  });

  testWidgets('chi tiết giải: khối Thông tin giải đủ các dòng, giải thưởng ghi BTC tự trao, không còn nút sơ đồ', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 'pt-pickle-q7'));
    expect(find.text(PlayerTournamentStrings.infoTitle), findsOneWidget);
    for (final label in [
      PlayerTournamentStrings.organizer,
      PlayerTournamentStrings.venue,
      PlayerTournamentStrings.playTime,
      PlayerTournamentStrings.regDeadline,
      PlayerTournamentStrings.tierTitle,
      PlayerTournamentStrings.purposeTitle,
      PlayerTournamentStrings.formatTitle,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.scrollUntilVisible(find.text(PlayerTournamentStrings.scheduleTitle), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text(PlayerTournamentStrings.scheduleTitle), findsOneWidget);
    expect(find.textContaining(PlayerTournamentStrings.prizesNote), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.bracket), findsNothing);
  });

  testWidgets('vé QR: đã điểm danh thì mã mờ và hiện Đã check-in', (tester) async {
    await pump(tester, const TournamentTicketScreen(divisionId: 'd1', autoRefresh: false));
    expect(find.text(PlayerTournamentStrings.checkedIn), findsNothing);
    tournaments.checkedIn = true;
    await pump(tester, const TournamentTicketScreen(divisionId: 'd1', autoRefresh: false));
    expect(find.text(PlayerTournamentStrings.checkedIn), findsOneWidget);
  });

  testWidgets('Lịch thi đấu: trận vừa có kết quả có nút Khiếu nại kết quả → gửi khiếu nại MATCH', (tester) async {
    tournaments.matches = [
      MyTournamentMatch(
        matchId: 'm1',
        tournamentName: 'Giải A',
        status: 'FINISHED',
        mySide: 'Khoa Cao',
        opponent: 'Đối thủ',
        winner: 'Đối thủ',
        resultAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ];
    await pump(tester, const TournamentsScreen());
    await tester.tap(find.text(PlayerTournamentStrings.tabMatches));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportStrings.matchComplaint));
    await tester.pumpAndSettle();
    expect(find.byType(ReportContentScreen), findsOneWidget);
    await tester.tap(find.text('Tỉ số ghi sai'));
    await tester.enterText(find.byType(TextField), 'Hiệp 2 trọng tài ghi nhầm 21-19 thành 19-21');
    await tester.tap(find.text(ReportStrings.submitReport));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.matchReportSent), findsOneWidget);
    final sent = (await tester.runAsync(AppRepositories.report.getMine))!.single;
    expect(sent.isMatch, isTrue);
  });

  testWidgets('bố cục: chi tiết giải, vé đã check-in, lịch thi đấu có nút khiếu nại', (tester) async {
    tournaments.checkedIn = true;
    tournaments.matches = [
      MyTournamentMatch(
        matchId: 'm1',
        tournamentName: 'Giải Cầu Lông Mở Rộng Quận 7 Lần Thứ Nhất',
        status: 'FINISHED',
        roundName: 'Bán kết',
        courtName: 'Sân 2',
        mySide: 'Khoa Cao',
        opponent: 'Đối thủ có tên rất dài',
        winner: 'Khoa Cao',
        start: DateTime.now().subtract(const Duration(hours: 1)),
        resultAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];
    Future<void> scrollToEnd(WidgetTester t) async {
      for (var i = 0; i < 8; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    await expectNoOverflow(tester, 'Chi tiết giải', () => const TournamentDetailScreen(tournamentId: 'pt-pickle-q7'),
        interact: scrollToEnd);
    await expectNoOverflow(tester, 'Vé đã check-in',
        () => const TournamentTicketScreen(divisionId: 'd1', autoRefresh: false));
    await expectNoOverflow(tester, 'Lịch thi đấu', () => const TournamentsScreen(), interact: (t) async {
      await t.tap(find.text(PlayerTournamentStrings.tabMatches));
      await settleFrames(t);
    });
  });
}
