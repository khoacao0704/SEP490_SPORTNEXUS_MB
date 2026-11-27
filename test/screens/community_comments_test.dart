import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/community_strings.dart';
import 'package:test1/core/strings/report_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_community_repository.dart';
import 'package:test1/data/mock/mock_report_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/models/community_post.dart';
import 'package:test1/models/player_report.dart';
import 'package:test1/screens/community/community_screen.dart';
import 'package:test1/screens/report/support_center_screen.dart';
import 'package:test1/widgets/community/comments_sheet.dart';

import '../helpers/layout_check.dart';

/// B4 lượt 5b: bình luận + báo cáo bài viết / bình luận (bản giả lập).
void main() {
  late MockCommunityRepository community;
  late MockReportRepository report;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    community = MockCommunityRepository(latency: Duration.zero);
    report = MockReportRepository(latency: Duration.zero);
    AppRepositories.community = community;
    AppRepositories.report = report;
    AppRepositories.team = MockTeamRepository();
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

  Future<void> openFirstComments(WidgetTester tester) async {
    await pump(tester, const CommunityScreen());
    await tester.tap(find.textContaining(' bình luận').first);
    await tester.pumpAndSettle();
    expect(find.byType(CommentsSheet), findsOneWidget);
  }

  Finder input() => find.descendant(of: find.byType(CommentsSheet), matching: find.byType(TextField)).last;

  testWidgets('viết bình luận có tag @ (gợi ý tên), trả lời, like (lưu trong máy), số bình luận trên thẻ tăng', (tester) async {
    await openFirstComments(tester);
    expect(find.text(CommunityStrings.noComments), findsOneWidget);

    await tester.enterText(input(), 'Hẹn gặp @Min');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Minh Tuấn'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input()).controller!.text, 'Hẹn gặp @Minh Tuấn ');
    await tester.tap(find.byTooltip(CommunityStrings.send));
    await tester.pumpAndSettle();
    expect(find.textContaining('@Minh Tuấn', findRichText: true), findsOneWidget);

    await tester.tap(find.text(CommunityStrings.reply).first);
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.replyHint('Khoa Cao')), findsWidgets);
    await tester.enterText(input(), 'Trả lời chính mình');
    await tester.tap(find.byTooltip(CommunityStrings.send));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trả lời chính mình', findRichText: true), findsOneWidget);
    expect(find.text('${CommunityStrings.commentsTitle} (2)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border).last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(CommentsSheet), matching: find.byIcon(Icons.favorite)), findsOneWidget);
    expect((await tester.runAsync(CommentLikeStore.read))!.values.single.liked, isTrue);

    Navigator.of(tester.element(find.byType(CommentsSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.comments(2)), findsOneWidget); // thẻ bài cập nhật theo số vừa gửi
  });

  testWidgets('bình luận của mình: sửa (có lịch sử sửa), xóa; người khác thì có Báo cáo', (tester) async {
    await tester.runAsync(() => community.addComment('post-seed-1', 'Bình luận gốc'));
    await pump(tester, const CommunityScreen());
    // Mở bình luận của bài mẫu 1 (Minh Tuấn, 2 giờ trước).
    final post1 = find.textContaining('Tối thứ 6 ai đánh đôi');
    expect(post1, findsOneWidget);
    await tester.tap(find.text(CommunityStrings.comments(1)));
    await tester.pumpAndSettle();

    await tester.tap(find.text(CommunityStrings.edit));
    await tester.pumpAndSettle();
    final editField = find.descendant(of: find.byType(CommentsSheet), matching: find.byType(TextField)).first;
    await tester.enterText(editField, 'Bình luận đã sửa');
    await tester.tap(find.text(CommunityStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.commentSaved), findsOneWidget);
    expect(find.textContaining('Bình luận đã sửa', findRichText: true), findsOneWidget);
    await tester.tap(find.text(CommunityStrings.editHistory));
    await tester.pumpAndSettle();
    expect(find.text('Bình luận gốc'), findsOneWidget);
    Navigator.of(tester.element(find.text('Bình luận gốc'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text(CommunityStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, CommunityStrings.delete));
    await tester.pumpAndSettle();
    expect(find.text(CommunityStrings.commentDeleted), findsOneWidget);
    expect(find.text(CommunityStrings.noComments), findsOneWidget);
  });

  testWidgets('báo cáo bài viết của người khác: lý do theo loại bài viết, gửi kèm mã bài', (tester) async {
    await pump(tester, const CommunityScreen());
    await tester.tap(find.byTooltip(CommunityStrings.report).first);
    await tester.pumpAndSettle();
    expect(find.byType(ReportContentScreen), findsOneWidget);
    await tester.tap(find.text('Lý do khác'));
    await tester.enterText(find.byType(TextField), 'Bài viết quảng cáo trái phép nhiều lần');
    await tester.tap(find.text(ReportStrings.submitReport));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.postReportSent), findsOneWidget);
    final sent = (await tester.runAsync(report.getMine))!.single;
    expect(sent.targetType, ReportTarget.communityPost.apiValue);
  });

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bố cục: phần bình luận có trả lời + tag, báo cáo bình luận', (tester) async {
    final post = await tester.runAsync(() async {
      final c = await community.addComment('post-seed-1', 'Bình luận dài để kiểm tra xuống dòng @Minh Tuấn ' * 3);
      await community.addComment('post-seed-1', 'Trả lời dài để kiểm tra lùi lề trên máy nhỏ ' * 2, parentId: c.id);
      return (await community.getPosts(const PostQuery())).items.firstWhere((p) => p.id == 'post-seed-1');
    });
    await expectNoOverflow(
      tester,
      'Bình luận',
      () => Scaffold(body: CommentsSheet(post: post!, onCountChanged: (_) {})),
      interact: scrollToEnd,
    );
    await expectNoOverflow(
      tester,
      'Báo cáo bình luận',
      () => const ReportContentScreen(
        target: ReportTarget.postComment,
        title: CommunityStrings.reportCommentTitle,
        subject: 'Tên người viết bình luận rất dài để thử',
        objectId: 'c1',
      ),
      interact: scrollToEnd,
    );
  });
}
