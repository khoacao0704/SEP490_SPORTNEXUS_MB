import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/player_tournament_strings.dart';
import 'package:test1/core/strings/team_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_player_tournament_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/team_repository.dart';
import 'package:test1/screens/tournament/tournament_bracket_screen.dart';
import 'package:test1/screens/tournament/tournament_detail_screen.dart';
import 'package:test1/screens/tournament/tournament_ticket_screen.dart';
import 'package:test1/screens/tournament/tournaments_screen.dart';

void main() {
  late MockTeamRepository teams;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
    teams = MockTeamRepository(latency: Duration.zero);
    AppRepositories.team = teams;
    AppRepositories.playerTournament = MockPlayerTournamentRepository(teams: teams, latency: Duration.zero);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('khám phá: giải nổi bật trước, lọc môn / đang nhận đăng ký; tab Đã đăng ký và Lịch đấu', (tester) async {
    await pump(tester, const TournamentsScreen());
    expect(find.text('Giải Pickleball Mở Rộng Quận 7'), findsOneWidget);
    expect(find.text('Giải Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text('Giải Bóng Đá Hoa Lư'), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.promoted), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cầu Lông'));
    await tester.pumpAndSettle();
    expect(find.text('Giải Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text('Giải Pickleball Mở Rộng Quận 7'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, PlayerTournamentStrings.allSports));
    await tester.tap(find.widgetWithText(ChoiceChip, PlayerTournamentStrings.registrationOpenOnly));
    await tester.pumpAndSettle();
    expect(find.text('Giải Pickleball Mở Rộng Quận 7'), findsOneWidget);
    expect(find.text('Giải Bóng Đá Hoa Lư'), findsNothing);

    await tester.tap(find.text(PlayerTournamentStrings.tabMine));
    await tester.pumpAndSettle();
    expect(find.text('Giải Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.ticket), findsOneWidget);
    // Giải đang diễn ra thì không rút được.
    expect(find.text(PlayerTournamentStrings.withdraw), findsNothing);

    await tester.tap(find.text(PlayerTournamentStrings.tabMatches));
    await tester.pumpAndSettle();
    expect(find.text(PlayerTournamentStrings.versus('Khoa Cao', 'Minh Tuấn')), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.versus('Khoa Cao', 'Quốc Bảo')), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.winner('Khoa Cao')), findsOneWidget);
  });

  testWidgets('đăng ký nội dung đơn rồi rút trước hạn (được hoàn tiền)', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 'pt-pickle-q7'));
    expect(find.text('Đơn mở rộng'), findsOneWidget);
    expect(find.text('Đôi cố định'), findsOneWidget);
    expect(find.text('Đôi ngẫu nhiên'), findsOneWidget);
    expect(find.textContaining('2/16 người'), findsOneWidget);
    expect(find.textContaining('1/8 đội'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(ElevatedButton, PlayerTournamentStrings.register).first);
    expect(find.text(PlayerTournamentStrings.registerTitle), findsOneWidget);
    await tester.tap(find.text(PlayerTournamentStrings.confirmRegister));
    await tester.pumpAndSettle();

    expect(find.text(PlayerTournamentStrings.registerSuccess), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.registered), findsOneWidget);
    expect(find.textContaining('3/16 người'), findsOneWidget);

    await tapVisible(tester, find.text(PlayerTournamentStrings.withdraw));
    expect(find.text(PlayerTournamentStrings.withdrawRefund(150000)), findsOneWidget);
    await tester.tap(find.text(PlayerTournamentStrings.withdrawConfirm));
    await tester.pumpAndSettle();
    expect(find.text(PlayerTournamentStrings.withdrawn), findsOneWidget);
    expect(find.text(PlayerTournamentStrings.registered), findsNothing);
  });

  testWidgets('đăng ký đôi cố định bằng đội: chọn đội đủ người; đội đang dự giải thì không giải tán được', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 'pt-pickle-q7'));
    await tapVisible(tester, find.widgetWithText(ElevatedButton, PlayerTournamentStrings.register).at(1));

    expect(find.text(PlayerTournamentStrings.chooseTeam), findsOneWidget);
    expect(find.text('Pickleball Q7'), findsOneWidget);
    await tester.tap(find.text(PlayerTournamentStrings.confirmRegister));
    await tester.pumpAndSettle();

    expect(find.text(PlayerTournamentStrings.registered), findsOneWidget);
    expect(find.textContaining('Pickleball Q7'), findsWidgets);
    expect(
      () => teams.disband('team-pickle-q7'),
      throwsA(isA<TeamException>().having((e) => e.message, 'message', TeamStrings.inTournament)),
    );
  });

  testWidgets('sơ đồ: gom theo vòng, người thắng, tỉ số; chưa bốc thăm thì báo', (tester) async {
    await pump(tester, const TournamentBracketScreen(divisionId: 'pd-bm-singles', title: 'Đơn nam'));
    expect(find.text('Bán kết'), findsOneWidget);
    expect(find.text('Chung kết'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsNWidgets(2));
    expect(find.text('21'), findsWidgets);

    await pump(tester, const TournamentBracketScreen(key: ValueKey('empty'), divisionId: 'pd-pickle-singles', title: 'Đơn mở rộng'));
    expect(find.text(PlayerTournamentStrings.bracketEmpty), findsOneWidget);
  });

  testWidgets('vé QR: mã tĩnh của người đăng ký', (tester) async {
    await pump(tester, const TournamentTicketScreen(divisionId: 'pd-bm-singles'));
    expect(find.text('TN-tp-b1'), findsOneWidget);
    expect(find.text('Khoa Cao'), findsOneWidget);
  });
}
