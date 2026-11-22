import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/screens/lfg/create_lfg_match_screen.dart';

import '../helpers/layout_check.dart';

/// Bản giả lập bật kèo Đội vs Đội để kiểm giao diện chọn đội.
class _TeamLfg extends MockLfgRepository {
  _TeamLfg({required super.wallet, required super.review}) : super(latency: Duration.zero);

  @override
  bool get supportsTeamMatch => true;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.review = review;
    AppRepositories.lfg = _TeamLfg(wallet: wallet, review: review);
    AppRepositories.team = MockTeamRepository(latency: Duration.zero);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.facility = AppRepositories.lfgFacility = MockFacilityRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  testWidgets('chọn Team vs Team: thấy bước số người mỗi đội và dropdown chọn đội', (tester) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CreateLfgMatchScreen()));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.pickTeamTitle), findsNothing);

    await tester.tap(find.text('Team vs Team'));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.stepSideSize), findsOneWidget);
    expect(find.text(LfgStrings.sideSizeLabel(2)), findsOneWidget);
    expect(find.text(LfgStrings.pickTeamHint), findsOneWidget);
  });

  testWidgets('chọn Team vs Team: hiện số người mỗi đội + dropdown chọn đội; không tràn chữ', (tester) async {
    final problems = await collectLayoutProblems(
      tester,
      'Tạo kèo đội',
      () => const CreateLfgMatchScreen(),
      interact: (tester) async {
        await tester.tap(find.text('Team vs Team'));
        await settleFrames(tester, frames: 10);
        expect(find.text(LfgStrings.stepSideSize), findsOneWidget);
        expect(find.text(LfgStrings.pickTeamTitle), findsWidgets);
      },
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
