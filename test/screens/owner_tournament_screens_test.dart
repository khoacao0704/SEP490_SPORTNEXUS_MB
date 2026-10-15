import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/core/strings/owner_tournament_strings.dart';
import 'package:test1/core/strings/tournament_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_tournament_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/tournament.dart';
import 'package:test1/screens/owner/owner_account_screen.dart';
import 'package:test1/screens/owner/owner_tournament_detail_screen.dart';
import 'package:test1/screens/owner/tournament_form_screen.dart';

void main() {
  const seeded = 't-own-bongda-hoalu';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    final owner = MockOwnerRepository(latency: Duration.zero);
    AppRepositories.owner = owner;
    final tournaments = MockTournamentRepository(
      latency: Duration.zero,
      wallet: MockWalletRepository(latency: Duration.zero),
      owner: owner,
      random: Random(3),
    );
    AppRepositories.tournament = tournaments;
    AppRepositories.organizer = tournaments;
    await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<Tournament> seededTournament() async =>
      (await AppRepositories.organizer.getOrganizedTournaments()).firstWhere((t) => t.id == seeded);

  testWidgets('tab Tài khoản mở Giải đấu của tôi', (tester) async {
    final user = (await AppRepositories.auth.getCurrentUser())!;
    await pump(tester, OwnerAccountScreen(user: user));
    await tester.tap(find.text(OwnerStrings.menuTournaments));
    await tester.pumpAndSettle();
    expect(find.text(OwnerTournamentStrings.title), findsOneWidget);
    expect(find.text('Hoa Lư Cup – Bóng Đá 5 Người'), findsOneWidget);
    expect(find.text(OwnerTournamentStrings.create), findsOneWidget);
  });

  testWidgets('tạo giải mới từ form', (tester) async {
    await pump(tester, const TournamentFormScreen());
    await tester.enterText(find.widgetWithText(TextFormField, OwnerTournamentStrings.name), 'Giải Cầu Lông Đơn Thiên Triều');
    await tester.enterText(find.widgetWithText(TextFormField, OwnerTournamentStrings.entryFee), '150000');
    await tester.tap(find.text(OwnerTournamentStrings.publish));
    await tester.pumpAndSettle();

    final mine = await AppRepositories.organizer.getOrganizedTournaments();
    final created = mine.firstWhere((t) => t.name == 'Giải Cầu Lông Đơn Thiên Triều');
    expect(created.entryFee, 150000);
    expect(created.entryType, TournamentEntryType.single);
    expect(created.closureId, isNotNull);
  });

  testWidgets('bốc thăm rồi nhập kết quả một trận', (tester) async {
    await pump(tester, OwnerTournamentDetailScreen(tournament: await seededTournament()));
    expect(find.text('Hoa Lư Cup – Bóng Đá 5 Người'), findsOneWidget);
    expect(find.text(OwnerTournamentStrings.holding(3000000)), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, OwnerTournamentStrings.draw));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 đơn được miễn thi đấu vòng 1'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OwnerTournamentStrings.draw)));
    await tester.pumpAndSettle();

    expect(find.text(OwnerTournamentStrings.drawn), findsOneWidget);
    expect(find.text(TournamentStrings.bye), findsWidgets);

    final t = await seededTournament();
    final match = t.matchesInRound(1).firstWhere((m) => !m.isBye);
    final teamA = t.entryById(match.entryAId)!.name;
    await tester.ensureVisible(find.text(teamA).last);
    await tester.tap(find.text(teamA).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(RadioListTile<String>, teamA));
    await tester.enterText(find.widgetWithText(TextField, OwnerTournamentStrings.score), '3 - 1');
    await tester.tap(find.text(OwnerTournamentStrings.saveResult));
    await tester.pumpAndSettle();

    final after = await seededTournament();
    expect(after.matches.firstWhere((m) => m.id == match.id).winnerId, match.entryAId);
  });

  testWidgets('hủy giải', (tester) async {
    await pump(tester, OwnerTournamentDetailScreen(tournament: await seededTournament()));
    await tester.tap(find.widgetWithText(OutlinedButton, OwnerTournamentStrings.cancelTournament));
    await tester.pumpAndSettle();
    expect(find.text(OwnerTournamentStrings.cancelConfirm(6, 500000)), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(OwnerTournamentStrings.cancelTournament),
    ));
    await tester.pumpAndSettle();

    expect(find.text(OwnerTournamentStrings.cancelled), findsOneWidget);
    expect(find.text(TournamentStrings.statusCancelled), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, OwnerTournamentStrings.cancelTournament), findsNothing);
  });
}
