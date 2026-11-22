import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/team.dart';
import 'package:test1/widgets/lfg/team_picker.dart';

Team _team(String id, {Sport? sport = Sport.football, int members = 5, bool locked = false}) => Team(
      id: id,
      name: 'Đội $id',
      sport: sport,
      captainId: 'me',
      isLocked: locked,
      members: [for (var i = 0; i < members; i++) TeamMember(accountId: '$id-$i', fullName: 'Người $i')],
    );

void main() {
  test('đội chọn được: đúng số người, đúng môn (chưa khai môn cũng được), không bị khóa', () {
    expect(teamIneligibleReason(_team('a'), Sport.football, 5), isNull);
    expect(teamIneligibleReason(_team('b', sport: null), Sport.football, 5), isNull);
    expect(teamIneligibleReason(_team('c', members: 4), Sport.football, 5), LfgStrings.teamWrongSize(5, 4));
    expect(teamIneligibleReason(_team('d', sport: Sport.basketball), Sport.football, 5), LfgStrings.teamWrongSport);
    expect(teamIneligibleReason(_team('e', locked: true), Sport.football, 5), LfgStrings.teamLocked);
  });

  testWidgets('dropdown: đội không hợp hiện mờ kèm lý do, chỉ chọn được đội hợp lệ', (tester) async {
    Team? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => CaptainTeamDropdown(
              teams: [_team('a'), _team('c', members: 4)],
              sport: Sport.football,
              sideSize: 5,
              selectedId: picked?.id,
              onChanged: (t) => setState(() => picked = t),
            ),
          ),
        ),
      ),
    ));
    expect(find.text(LfgStrings.pickTeamTitle), findsOneWidget);
    expect(find.text(LfgStrings.noCaptainTeam), findsNothing);

    await tester.tap(find.text(LfgStrings.pickTeamHint));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.teamWrongSize(5, 4)), findsOneWidget);
    await tester.tap(find.text('Đội c').last);
    await tester.pumpAndSettle();
    expect(picked, isNull);

    await tester.tap(find.text('Đội a').last);
    await tester.pumpAndSettle();
    expect(picked?.id, 'a');
  });

  testWidgets('không có đội hợp lệ thì báo và có nút mở Đội của tôi', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CaptainTeamDropdown(
          teams: [_team('c', members: 4)],
          sport: Sport.football,
          sideSize: 5,
          selectedId: null,
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text(LfgStrings.noCaptainTeam), findsOneWidget);
    expect(find.text(LfgStrings.openMyTeams), findsOneWidget);
  });
}
