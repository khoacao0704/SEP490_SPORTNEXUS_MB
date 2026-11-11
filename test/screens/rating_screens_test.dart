import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/rating_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_player_profile_repository.dart';
import 'package:test1/data/mock/mock_rating_repository.dart';
import 'package:test1/data/repositories/team_repository.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/rating/leaderboard_screen.dart';
import 'package:test1/screens/rating/my_elo_screen.dart';
import 'package:test1/screens/rating/skill_assessment_screen.dart';
import 'package:test1/widgets/common/rating_required.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.rating = MockRatingRepository();
    AppRepositories.playerProfile = MockPlayerProfileRepository();
    AppRepositories.sportOfCategory = AppRepositories.mockSportOfCategory;
    await auth.login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Elo của tôi: thấy Elo cầu lông có sẵn; môn chưa có Elo thì làm khảo sát, nộp xong có Elo', (tester) async {
    await pump(tester, const MyEloScreen());
    expect(find.textContaining('1240', findRichText: true), findsOneWidget);
    expect(find.text('Bạc'), findsOneWidget);
    // Khảo sát người chơi demo chỉ có cầu lông → không còn môn chưa có Elo.
    expect(find.text(RatingStrings.sportsWithoutRating), findsNothing);

    await tester.tap(find.text(RatingStrings.retakeAssessment));
    await tester.pumpAndSettle();
    expect(find.byType(SkillAssessmentScreen), findsOneWidget);

    // Chưa trả lời đủ thì không nộp.
    await tester.tap(find.text(RatingStrings.submit));
    await tester.pump();
    expect(find.text(RatingStrings.unanswered(MockRatingRepository.questions.length)), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Trên 5 năm'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Giải quốc gia'));
    for (final chip in find.widgetWithText(ChoiceChip, '5').evaluate().toList()) {
      await tester.tap(find.byWidget(chip.widget));
    }
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text(RatingStrings.submit));
    await tester.pump();
    expect(find.text(RatingStrings.invalidUrl), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://a.vn/huy-chuong.jpg');
    await tester.tap(find.text(RatingStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(RatingStrings.resultTitle), findsOneWidget);
    expect(find.text(RatingStrings.assigned(1400)), findsOneWidget);
    expect(find.text(RatingStrings.computed(1600)), findsOneWidget);
    await tester.tap(find.text(RatingStrings.done));
    await tester.pumpAndSettle();

    expect(find.byType(MyEloScreen), findsOneWidget);
    expect(find.textContaining('1400', findRichText: true), findsOneWidget);
  });

  testWidgets('Bảng xếp hạng: vị trí #1.., đổi sang Đội; kéo xuống tải trang tiếp', (tester) async {
    await pump(tester, const LeaderboardScreen(initialSport: Sport.football));
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Người chơi 1'), findsOneWidget);

    await tester.tap(find.text('Đội'));
    await tester.pumpAndSettle();
    expect(find.text('Đội Bóng Đá 1'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('#25'), findsOneWidget);
  });

  testWidgets('Thiếu Elo khi tạo đội: mình thiếu thì mời làm khảo sát đúng môn', (tester) async {
    late BuildContext ctx;
    await pump(
      tester,
      Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold();
        },
      ),
    );
    const error = TeamException(
      'Bạn chưa có Elo môn Tennis',
      code: 'RATING_REQUIRED',
      detail: {'sportCategoryId': 'mock-tennis', 'missingUserIds': ['u-player-001', 'u-khac']},
    );
    final handled = handleRatingRequired(ctx, error);
    await tester.pumpAndSettle();
    expect(find.text(RatingStrings.ratingRequiredTitle), findsOneWidget);
    expect(find.textContaining(RatingStrings.ratingRequiredOthers(1)), findsOneWidget);
    await tester.tap(find.text(RatingStrings.takeAssessment));
    await tester.pumpAndSettle();
    expect(find.text(RatingStrings.assessmentTitle(Sport.tennis.label)), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await handled, isTrue);
    expect(await handleRatingRequired(ctx, const TeamException('khác')), isFalse);
  });
}
