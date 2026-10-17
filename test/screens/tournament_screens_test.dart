import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/tournament_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_tournament_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/screens/tournament/tournament_detail_screen.dart';
import 'package:test1/screens/tournament/tournament_register_screen.dart';
import 'package:test1/screens/tournament/tournaments_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = wallet;
    AppRepositories.tournament = MockTournamentRepository(latency: Duration.zero, wallet: wallet);
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

  testWidgets('danh sách: khám phá, lọc theo môn, tab Giải của tôi', (tester) async {
    await pump(tester, const TournamentsScreen());
    expect(find.text('SportNexus Cup – Bóng Đá 5 Người'), findsOneWidget);
    expect(find.text('Giải Cầu Lông Đôi Mùa Thu 2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bóng Đá'));
    await tester.pumpAndSettle();
    expect(find.text('SportNexus Cup – Bóng Đá 5 Người'), findsOneWidget);
    expect(find.text('Giải Cầu Lông Đôi Mùa Thu 2026'), findsNothing);

    await tester.tap(find.text(TournamentStrings.tabMine));
    await tester.pumpAndSettle();
    expect(find.text('Pickleball Open Quận 7'), findsOneWidget);
    expect(find.text(TournamentStrings.registered), findsWidgets);
  });

  testWidgets('đăng ký giải đôi: thêm đồng đội, đồng ý điều lệ, trả bằng ví', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 't-hcm-caulong-doi-mua-thu'));
    await tester.tap(find.text(TournamentStrings.register));
    await tester.pumpAndSettle();
    expect(find.byType(TournamentRegisterScreen), findsOneWidget);

    await tester.tap(find.text(TournamentStrings.confirmPay));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.needPartner), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'phuonglinh@sportnexus.vn');
    await tester.tap(find.text(TournamentStrings.addMember));
    await tester.pumpAndSettle();
    expect(find.text('Phương Linh'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text(TournamentStrings.confirmPay));
    await tester.pumpAndSettle();

    expect(find.byType(TournamentDetailScreen), findsOneWidget);
    expect(find.text(TournamentStrings.yourEntry), findsOneWidget);
    expect(find.text('Khoa Cao / Phương Linh'), findsWidgets);
    expect(find.text(TournamentStrings.withdraw), findsOneWidget);
  });

  testWidgets('giải đang diễn ra: trận tiếp theo, lịch thi đấu và sơ đồ nhánh', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 't-hcm-pickleball-open-q7'));
    expect(find.textContaining(TournamentStrings.yourNextMatch), findsOneWidget);
    expect(find.text(TournamentStrings.register), findsNothing);

    await tester.tap(find.text(TournamentStrings.tabSchedule));
    await tester.pumpAndSettle();
    expect(find.text('Tứ kết'), findsOneWidget);
    expect(find.text('11-7, 11-9'), findsOneWidget);

    await tester.tap(find.text(TournamentStrings.tabBracket));
    await tester.pumpAndSettle();
    expect(find.text('Chung kết'), findsOneWidget);
    expect(find.text(TournamentStrings.tbd), findsNWidgets(2));
  });

  testWidgets('rút sau hạn đăng ký: cảnh báo không hoàn lệ phí', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 't-hcm-bongro-3x3'));
    await tester.tap(find.text(TournamentStrings.withdraw));
    await tester.pumpAndSettle();
    expect(find.textContaining('sẽ không được hoàn'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, TournamentStrings.withdraw));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.withdrawnMessage(0)), findsOneWidget);
    expect(find.text(TournamentStrings.withdraw), findsNothing);
  });

  testWidgets('giải chưa bốc thăm: báo lịch sẽ có sau hạn đăng ký', (tester) async {
    await pump(tester, const TournamentDetailScreen(tournamentId: 't-hcm-sportnexus-cup'));
    await tester.tap(find.text(TournamentStrings.tabBracket));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.notDrawnYet), findsOneWidget);
  });
}
