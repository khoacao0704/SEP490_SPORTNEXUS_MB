import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/team_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/screens/team/my_teams_screen.dart';
import 'package:test1/screens/team/team_detail_screen.dart';
import 'package:test1/screens/team/team_form_screen.dart';

void main() {
  final popupMenus = find.byWidgetPredicate((w) => w is PopupMenuButton);
  late MockTeamRepository teams;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    teams = MockTeamRepository(latency: Duration.zero);
    AppRepositories.team = teams;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    await loginAs('player@sportnexus.vn');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  test('tách SĐT theo dòng / dấu phẩy, bỏ trùng', () {
    expect(TeamFormScreen.parsePhones('0911111111, 0922222222\n0911111111;  '), ['0911111111', '0922222222']);
  });

  testWidgets('đội của tôi: nhận lời mời thì vào đội, lời mời biến mất', (tester) async {
    await pump(tester, const MyTeamsScreen());
    expect(find.text('Pickleball Q7'), findsOneWidget);
    expect(find.textContaining(TeamStrings.captain), findsOneWidget);
    expect(find.text(TeamStrings.invitationsTitle), findsOneWidget);
    expect(find.text('Cầu Lông Gò Vấp'), findsOneWidget);

    await tester.tap(find.text(TeamStrings.accept));
    await tester.pumpAndSettle();
    expect(find.text(TeamStrings.accepted), findsOneWidget);
    expect(find.text(TeamStrings.invitationsTitle), findsNothing);
    expect(find.text('Cầu Lông Gò Vấp'), findsOneWidget);
    expect(find.textContaining(TeamStrings.memberCount(2)), findsNWidgets(2));
  });

  testWidgets('tạo đội kèm mời SĐT: mở chi tiết, thấy lời mời đang chờ và thu hồi được', (tester) async {
    await pump(tester, const MyTeamsScreen());
    await tester.tap(find.text(TeamStrings.createTeam));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, TeamStrings.teamName), 'Đội Mới');
    await tester.enterText(find.widgetWithText(TextField, TeamStrings.invitePhonesLabel), '0911111111, 0999999999');
    await tester.tap(find.text(TeamStrings.create));
    await tester.pumpAndSettle();

    expect(find.byType(TeamDetailScreen), findsOneWidget);
    expect(find.text('${TeamStrings.pendingInvitations} (1)'), findsOneWidget);
    expect(find.text('Lan Anh'), findsOneWidget);

    await tester.tap(find.text(TeamStrings.revoke));
    await tester.pumpAndSettle();
    expect(find.text(TeamStrings.revoked), findsOneWidget);
    expect(find.text('Lan Anh'), findsNothing);
  });

  testWidgets('đội trưởng: mời SĐT không có tài khoản thì báo lỗi; chuyển quyền thì chỉ còn nút rời đội', (tester) async {
    await pump(tester, const TeamDetailScreen(teamId: 'team-pickle-q7'));
    expect(find.text('Khoa Cao ${TeamStrings.you}'), findsOneWidget);

    await tester.tap(find.text(TeamStrings.invite));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, TeamStrings.invitePhone), '0999999999');
    await tester.tap(find.text(TeamStrings.send));
    await tester.pumpAndSettle();
    expect(find.text(TeamStrings.phoneNotFound('0999999999')), findsOneWidget);

    await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Hoàng Nam'), matching: popupMenus));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeamStrings.makeCaptain));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeamStrings.confirm));
    await tester.pumpAndSettle();
    expect(find.text(TeamStrings.captainTransferred), findsOneWidget);
    expect(find.text(TeamStrings.invite), findsNothing);

    await tester.tap(popupMenus.first);
    await tester.pumpAndSettle();
    expect(find.text(TeamStrings.leave), findsOneWidget);
    expect(find.text(TeamStrings.disband), findsNothing);
  });

  testWidgets('thành viên rời đội', (tester) async {
    await loginAs('restricted@sportnexus.vn');
    final team = await tester.runAsync(() => teams.createTeam(name: 'X'));
    await loginAs('player@sportnexus.vn');
    await tester.runAsync(() => teams.invite('team-pickle-q7', '0908888888'));
    await loginAs('restricted@sportnexus.vn');
    final invitation = (await tester.runAsync(teams.getMyInvitations))!.single;
    await tester.runAsync(() => teams.acceptInvitation(invitation.id));
    expect(team, isNotNull);

    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeamDetailScreen(teamId: 'team-pickle-q7')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(popupMenus.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeamStrings.leave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeamStrings.confirm));
    await tester.pumpAndSettle();

    expect(find.text(TeamStrings.left), findsOneWidget);
    expect(find.byType(TeamDetailScreen), findsNothing);
    expect((await tester.runAsync(teams.getMyTeams))!.map((t) => t.id), isNot(contains('team-pickle-q7')));
  });
}
