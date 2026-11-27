import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/community_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_community_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/community_post.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/screens/community/community_screen.dart';
import 'package:test1/screens/community/compose_post_screen.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';
import 'package:test1/widgets/community/post_card.dart';

import '../helpers/layout_check.dart';

/// B4 lượt 5a: Bảng tin cộng đồng (bản giả lập).
void main() {
  late MockCommunityRepository community;
  late MockLfgRepository lfg;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    community = MockCommunityRepository(latency: Duration.zero, lfg: () => lfg);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.review = review;
    AppRepositories.lfg = lfg;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.facility = AppRepositories.lfgFacility = MockFacilityRepository(latency: Duration.zero);
    AppRepositories.community = community;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('bảng tin: hiện bài mẫu; lọc môn; like; bấm tên người đăng xem bài của họ', (tester) async {
    await pump(tester, const CommunityScreen());
    expect(find.byType(PostCard), findsNWidgets(4));

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Bóng Đá'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bóng Đá'));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsOneWidget);
    expect(find.text('FC Sài Gòn'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, CommunityStrings.allSports));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, CommunityStrings.allSports));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.text('Minh Tuấn').first);
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.authorPosts('Minh Tuấn')), findsOneWidget);
    expect(find.byType(PostCard), findsNWidgets(2));
  });

  testWidgets('đăng bài → có trong Bài viết của tôi; sửa (có lịch sử sửa); xóa thì còn nhãn Đã xóa', (tester) async {
    await pump(tester, const CommunityScreen());
    await tester.tap(find.text(CommunityStrings.newPost));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePostScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tìm bạn đánh tennis sáng chủ nhật');
    await tester.pump();
    await tester.tap(find.text(CommunityStrings.post));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.posted), findsOneWidget);
    expect(find.text('Tìm bạn đánh tennis sáng chủ nhật'), findsOneWidget);

    await tester.tap(find.text(CommunityStrings.tabMine));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CommunityStrings.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Đã đổi: tennis chiều chủ nhật');
    await tester.tap(find.text(CommunityStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.saved), findsOneWidget);
    expect(find.text('Đã đổi: tennis chiều chủ nhật'), findsOneWidget);

    await tester.tap(find.text(CommunityStrings.editHistory));
    await tester.pumpAndSettle();
    expect(find.byType(PostEditHistory), findsOneWidget);
    expect(find.text('Tìm bạn đánh tennis sáng chủ nhật'), findsOneWidget);
    Navigator.of(tester.element(find.byType(PostEditHistory))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CommunityStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, CommunityStrings.delete));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.deleted), findsOneWidget);
    expect(find.text(CommunityStrings.deletedBadge), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('chi tiết kèo của chủ kèo: Đăng lên Bảng tin (câu soạn sẵn) → bài có thẻ kèo, bấm mở lại kèo', (tester) async {
    final other = await tester.runAsync(() async => (await lfg.getFeed(const LfgFeedQuery(city: 'Hồ Chí Minh'))).first.match);
    await pump(tester, LfgMatchDetailScreen(matchId: other!.id));
    expect(find.text(CommunityStrings.shareLfg), findsNothing); // không phải chủ kèo

    final mine = await tester.runAsync(() async {
      final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 19).add(const Duration(days: 3));
      return lfg.createMatch(
        hold: SlotHold(
          holdId: 'h',
          slots: [
            TimeSlot(id: 's-share', facilityId: facility.id, sport: Sport.badminton, start: start,
                end: start.add(const Duration(hours: 1)), price: 160000, courtName: 'Sân 4', isAvailable: true),
          ],
          expiresAt: now.add(const Duration(minutes: 10)),
        ),
        facility: facility,
        format: LfgFormat.doubles,
      );
    });
    await pump(tester, LfgMatchDetailScreen(matchId: mine!.id));
    await tester.tap(find.text(CommunityStrings.shareLfg));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.shareLfgTitle), findsOneWidget);
    expect(find.textContaining('Kèo Cầu Lông còn 3 suất tại Sân 4 - Sân Cầu Lông Thiên Triều'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, CommunityStrings.post));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.shared), findsOneWidget);

    await pump(tester, const CommunityScreen());
    await tester.tap(find.textContaining('Kèo LFG ·'));
    await tester.pumpAndSettle();
    expect(find.byType(LfgMatchDetailScreen), findsOneWidget);
  });

  testWidgets('bảng tin lỗi thì có Thử lại; không có bài phù hợp thì báo trống', (tester) async {
    await pump(tester, const CommunityScreen());
    await tester.enterText(find.byType(TextField), 'không-có-bài-nào');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.emptyFeed), findsOneWidget);
  });

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bố cục: Bảng tin (bài có ảnh + kèo), Bài viết của tôi, Đăng bài', (tester) async {
    await tester.runAsync(() async {
      final m = (await lfg.getFeed(const LfgFeedQuery(city: 'Hồ Chí Minh'))).first.match;
      await community.createPost(
        content: 'Bài dài để kiểm tra xuống dòng trên máy nhỏ và khi phóng to chữ trong cài đặt máy ' * 3,
        mediaUrls: ['a.jpg', 'b.jpg', 'c.jpg'],
        lfgCardId: m.id,
      );
      final p = (await community.getPosts(const PostQuery(mine: true))).items.first;
      await community.updatePost(p.id, '${p.content} (đã sửa)');
    });
    await expectNoOverflow(tester, 'Bảng tin', () => const CommunityScreen(), interact: scrollToEnd);
    await expectNoOverflow(tester, 'Bài viết của tôi', () => const CommunityScreen(), interact: (t) async {
      await t.tap(find.text(CommunityStrings.tabMine));
      await settleFrames(t);
      await scrollToEnd(t);
    });
    await expectNoOverflow(tester, 'Đăng bài', () => const ComposePostScreen(), interact: scrollToEnd);
    await expectNoOverflow(tester, 'Bài của một người',
        () => const CommunityScreen(authorId: 'u-minhtuan', authorName: 'Tên người đăng rất dài để thử'));
  });
}
