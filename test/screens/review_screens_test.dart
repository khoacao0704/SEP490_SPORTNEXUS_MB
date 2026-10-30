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
import 'package:test1/screens/review/facility_reviews_screen.dart';
import 'package:test1/screens/review/my_reviews_screen.dart';
import 'package:test1/screens/review/submit_review_screen.dart';
import 'package:test1/screens/review/write_facility_review_screen.dart';
import 'package:test1/widgets/review/facility_reviews_section.dart';
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

  testWidgets('Đánh giá trận LFG: chấm sân + 1 người; trận còn 2 người chờ chấm, sân thành đã đánh giá',
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
    expect(find.textContaining(ReviewStrings.playerCount(2)), findsOneWidget);

    // Mở lại: sân đã đánh giá, chỉ còn 2 người chưa chấm.
    await tester.tap(find.text('Sân Cầu Lông Thiên Triều'));
    await tester.pumpAndSettle();
    expect(find.text(ReviewStrings.facilityAlreadyReviewed), findsOneWidget);
    expect(find.text('Minh Tuấn'), findsNothing);
    expect(find.text('Hoàng Nam'), findsOneWidget);
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

  group('Đánh giá cơ sở', () {
    Widget section(String id, String name) => Scaffold(
      body: SingleChildScrollView(child: FacilityReviewsSection(facilityId: id, facilityName: name)),
    );

    testWidgets('chi tiết sân: tổng hợp + đánh giá mới nhất; đã chơi thì viết được, viết xong thành đã đánh giá',
        (tester) async {
      await pump(tester, section('f-hcm-thientrieu', 'Sân Cầu Lông Thiên Triều'));
      expect(find.text('3.7'), findsOneWidget);
      expect(find.text(ReviewStrings.reviewCount(3)), findsOneWidget);
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      expect(find.text(ReviewStrings.ownerReply), findsNothing);
      expect(find.textContaining(ReviewStrings.ownerReply), findsWidgets);

      await tester.tap(find.text(ReviewStrings.writeReview));
      await tester.pumpAndSettle();
      expect(find.byType(WriteFacilityReviewScreen), findsOneWidget);
      final submit = find.widgetWithText(ElevatedButton, ReviewStrings.submit);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

      await tester.tap(find.bySemanticsLabel('5 sao'));
      await tester.enterText(find.byType(TextField), 'Sân đẹp');
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ReviewStrings.send));
      await tester.pumpAndSettle();

      expect(find.text(ReviewStrings.submitted), findsOneWidget);
      expect(find.text(ReviewStrings.writeReview), findsNothing);
      expect(find.text(ReviewStrings.facilityAlreadyReviewed), findsOneWidget);
      expect(find.text(ReviewStrings.reviewCount(4)), findsOneWidget);
      expect(find.text('Sân đẹp'), findsOneWidget);
    });

    testWidgets('chưa từng chơi ở sân thì không có nút viết đánh giá', (tester) async {
      await pump(tester, section('f-hcm-fpt', 'Sân FPT'));
      expect(find.text(ReviewStrings.noReviews), findsOneWidget);
      expect(find.text(ReviewStrings.writeReview), findsNothing);
    });

    testWidgets('xem tất cả: lọc theo số sao', (tester) async {
      await pump(
        tester,
        const FacilityReviewsScreen(facilityId: 'f-hcm-thientrieu', facilityName: 'Sân Cầu Lông Thiên Triều'),
      );
      expect(find.text('Trần Quốc Huy'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, ReviewStrings.starsFilter(2)));
      await tester.pumpAndSettle();
      expect(find.text('Lê Thu Hà'), findsOneWidget);
      expect(find.text('Trần Quốc Huy'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, ReviewStrings.starsFilter(3)));
      await tester.pumpAndSettle();
      expect(find.text(ReviewStrings.noReviewsForStars), findsOneWidget);
    });

    testWidgets('đánh giá của tôi: hiện tên cơ sở', (tester) async {
      await review.submitFacilityReview('f-hcm-eco-q7', const FacilityReviewInput(stars: 4, comment: 'Ổn'));
      await pump(tester, const MyReviewsScreen());
      expect(find.text('Eco Sport Quận 7'), findsOneWidget);
      expect(find.text('Ổn'), findsOneWidget);
    });
  });
}
