import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/core/strings/owner_tournament_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_tournament_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/tournament.dart';
import 'package:test1/screens/owner/operations_edit_screen.dart';
import 'package:test1/screens/owner/tournament_form_screen.dart';

/// Các lỗi tìm ra khi rà soát màn hình Chủ sân trước khi nối API.
void main() {
  late MockOwnerRepository owner;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    owner = MockOwnerRepository(latency: Duration.zero);
    AppRepositories.owner = owner;
    final tournaments = MockTournamentRepository(
      latency: Duration.zero,
      wallet: MockWalletRepository(latency: Duration.zero),
      owner: owner,
      random: Random(1),
    );
    AppRepositories.tournament = tournaments;
    AppRepositories.organizer = tournaments;
    await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 5000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('thêm tiện ích qua hộp thoại không lỗi ô nhập đã hủy', (tester) async {
    final facility = await owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OperationsEditScreen(facility: facility));

    await tester.tap(find.widgetWithText(TextButton, OwnerFacilityStrings.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Wifi miễn phí');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OwnerFacilityStrings.add)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Wifi miễn phí'), findsOneWidget);
  });

  testWidgets('sửa giải khi loại sân thi đấu đã bị khóa vẫn mở được form', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final t = await AppRepositories.organizer.createTournament(TournamentDraft(
      name: 'Pickleball Đôi Thiên Triều',
      facilityId: 'f-hcm-thientrieu',
      sport: Sport.pickleball,
      entryType: TournamentEntryType.pair,
      minMembers: 2,
      maxMembers: 2,
      maxEntries: 8,
      entryFee: 100000,
      registrationDeadline: day.add(const Duration(days: 20)),
      startDate: day.add(const Duration(days: 25, hours: 7)),
      endDate: day.add(const Duration(days: 25, hours: 18)),
    ));
    // Sau khi tạo giải, chủ sân khóa loại sân pickleball (Thiên Triều không còn môn nào khác ngoài cầu lông).
    await owner.lockCourt('f-hcm-thientrieu', Sport.pickleball, CourtType.standard);
    await pump(tester, TournamentFormScreen(tournament: t));

    expect(tester.takeException(), isNull);
    expect(find.text(Sport.pickleball.label), findsOneWidget);
  });

  testWidgets('thêm giải thưởng qua hộp thoại', (tester) async {
    await pump(tester, const TournamentFormScreen());
    await tester.ensureVisible(find.text(OwnerTournamentStrings.prizes));
    await tester.tap(find.widgetWithText(TextButton, OwnerTournamentStrings.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, OwnerTournamentStrings.prizeTitle), 'Vô địch');
    await tester.enterText(find.widgetWithText(TextField, OwnerTournamentStrings.prizeAmount), '2000000');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OwnerTournamentStrings.add)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Vô địch'), findsOneWidget);
    expect(find.text('2.000.000 đ'), findsOneWidget);
  });
}
