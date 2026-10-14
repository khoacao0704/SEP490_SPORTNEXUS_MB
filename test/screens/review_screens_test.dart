import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/review_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/models/review.dart';
import 'package:test1/screens/fair_play/fair_play_screen.dart';
import 'package:test1/screens/review/pending_reviews_screen.dart';
import 'package:test1/screens/review/submit_review_screen.dart';
import 'package:test1/widgets/review/fair_play_guard.dart';

void main() {
  late MockReviewRepository review;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    review = MockReviewRepository(latency: Duration.zero);
    AppRepositories.review = review;
    await loginAs('player@sportnexus.vn');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('Đánh giá trận LFG: chấm sân + 1 người, người còn lại bỏ qua, gửi xong biến khỏi danh sách',
      (tester) async {
    await pump(tester, const PendingReviewsScreen());
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text('Pickleball Thảo Điền'), findsOneWidget);

    await tester.tap(find.text('Sân Cầu Lông Thiên Triều'));
    await tester.pumpAndSettle();
    expect(find.byType(SubmitReviewScreen), findsOneWidget);
    expect(find.text(ReviewStrings.anonymousNote), findsOneWidget);

    // Chưa chấm gì thì nút gửi bị khóa.
    final submit = find.widgetWithText(ElevatedButton, ReviewStrings.submit);
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

    // Sân 5 sao (hàng sao đầu tiên), Minh Tuấn 4 sao + thẻ "Đúng giờ".
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('4 sao').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReviewTag.onTime.label));
    await tester.pumpAndSettle();

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.textContaining(ReviewStrings.confirmSkipped(2)), findsOneWidget);
    await tester.tap(find.text(ReviewStrings.send));
    await tester.pumpAndSettle();

    expect(find.byType(PendingReviewsScreen), findsOneWidget);
    expect(find.text(ReviewStrings.submitted), findsOneWidget);
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsNothing);
  });

  testWidgets('Fair Play: hiện điểm, trạng thái và lịch sử', (tester) async {
    await pump(tester, const FairPlayScreen());
    expect(find.text('93'), findsOneWidget);
    expect(find.text(ReviewStrings.eligible), findsOneWidget);
    expect(find.text('Vắng mặt trận Cầu Lông • Eco Sport Quận 7'), findsOneWidget);
    expect(find.text('-10'), findsOneWidget);
  });

  group('Chặn LFG', () {
    Future<List<bool>> pumpGuard(WidgetTester tester) async {
      final results = <bool>[];
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => results.add(await ensureCanJoinLfg(context)),
              child: const Text('join'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('join'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('đủ điểm thì cho qua, không hiện hộp thoại', (tester) async {
      final results = await pumpGuard(tester);
      expect(results, [true]);
      expect(find.text(ReviewStrings.blockedTitle), findsNothing);
    });

    testWidgets('dưới 30 điểm thì chặn, giải thích và mở được màn Fair Play', (tester) async {
      await loginAs('restricted@sportnexus.vn');
      final results = await pumpGuard(tester);

      expect(find.text(ReviewStrings.blockedTitle), findsOneWidget);
      expect(find.textContaining('là 25'), findsOneWidget);

      await tester.tap(find.text(ReviewStrings.viewFairPlay));
      await tester.pumpAndSettle();
      expect(find.byType(FairPlayScreen), findsOneWidget);
      expect(find.textContaining('Tạm khóa ghép LFG'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(results, [false]);
    });
  });
}
