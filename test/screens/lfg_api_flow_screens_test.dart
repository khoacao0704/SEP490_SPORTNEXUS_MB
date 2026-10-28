import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';

const _me = 'u-player-001';

/// Như BE thật: host trả cả sân, không rời được (chỉ hủy kèo); có lời mời / chờ duyệt.
class _BeLikeLfg extends MockLfgRepository {
  _BeLikeLfg() : super(latency: Duration.zero, wallet: MockWalletRepository(latency: Duration.zero));

  late LfgMatch current;
  final List<String> calls = [];

  @override
  bool get hostCanLeave => false;

  @override
  bool get hostPaysCourt => true;

  @override
  Future<LfgMatch> getMatch(String matchId) async => current;

  @override
  Future<LfgMatch> acceptInvitation(String matchId) async {
    calls.add('accept');
    return current = build(hostIsMe: false, myStatus: null, meJoined: true);
  }

  @override
  Future<int> leaveMatch(String matchId, {String? reason}) async {
    calls.add('leave');
    current = build(hostIsMe: false, myStatus: null);
    return 0;
  }

  @override
  Future<LfgMatch> cancelMatch(String matchId) async {
    calls.add('cancel');
    return current = build(hostIsMe: true, myStatus: null, cancelled: true);
  }

  static LfgMatch build({required bool hostIsMe, LfgMyStatus? myStatus, bool meJoined = false, bool cancelled = false}) {
    final start = DateTime.now().add(const Duration(days: 4));
    return LfgMatch(
      id: 'c1',
      facilityId: 'f1',
      facilityName: 'Hà Nội Badminton Center',
      city: '',
      district: '36 Trần Duy Hưng, Hà Nội',
      location: Facility.noLocation,
      sport: Sport.badminton,
      format: LfgFormat.doubles,
      start: start,
      end: start.add(const Duration(hours: 1)),
      courtPrice: 200000,
      members: [
        LfgMember(userId: hostIsMe ? _me : 'u-host', name: 'Chủ Kèo', fairPlayScore: 90, joinedAt: DateTime.now(), isHost: true),
        if (meJoined) LfgMember(userId: _me, name: 'Khoa Cao', fairPlayScore: 93, joinedAt: DateTime.now()),
      ],
      createdAt: DateTime.now(),
      totalSlotsOverride: 4,
      slotsLeftOverride: meJoined ? 2 : 3,
      pricePerPersonOverride: 50000,
      myStatus: myStatus,
      bookingId: 'b1',
      cancelReason: cancelled ? LfgCancelReason.cancelled : null,
    );
  }
}

void main() {
  late _BeLikeLfg lfg;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lfg = _BeLikeLfg();
    AppRepositories.lfg = lfg;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LfgMatchDetailScreen(matchId: 'c1')));
    await tester.pumpAndSettle();
  }

  testWidgets('được mời: chấp nhận thì vào kèo; địa chỉ hiện đầy đủ, quy định ghi host trả cả sân', (tester) async {
    lfg.current = _BeLikeLfg.build(hostIsMe: false, myStatus: LfgMyStatus.invited);
    await pump(tester);

    expect(find.text(LfgStrings.statusInvited), findsOneWidget);
    expect(find.text('36 Trần Duy Hưng, Hà Nội'), findsOneWidget);
    expect(find.textContaining('Host đã trả trước toàn bộ tiền sân'), findsOneWidget);

    await tester.tap(find.text(LfgStrings.acceptInvite(50000)));
    await tester.pumpAndSettle();
    expect(lfg.calls, ['accept']);
    expect(find.text(LfgStrings.joinSuccess), findsOneWidget);
    expect(find.text(LfgStrings.leave), findsOneWidget);
  });

  testWidgets('đang chờ chủ kèo duyệt: rút yêu cầu', (tester) async {
    lfg.current = _BeLikeLfg.build(hostIsMe: false, myStatus: LfgMyStatus.pendingApproval);
    await pump(tester);

    expect(find.text(LfgStrings.pendingApprovalNote), findsOneWidget);
    await tester.tap(find.text(LfgStrings.withdrawRequest));
    await tester.pumpAndSettle();
    expect(lfg.calls, ['leave']);
    expect(find.text(LfgStrings.withdrawnMessage), findsOneWidget);
  });

  testWidgets('host: không có nút rời, chỉ hủy kèo (có hỏi xác nhận)', (tester) async {
    lfg.current = _BeLikeLfg.build(hostIsMe: true);
    await pump(tester);

    expect(find.text(LfgStrings.leave), findsNothing);
    await tester.tap(find.text(LfgStrings.cancelMatch));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.hostCancelMessage(200000)), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, LfgStrings.cancelMatch));
    await tester.pumpAndSettle();

    expect(lfg.calls, ['cancel']);
    expect(find.text(LfgStrings.hostCancelledMessage), findsOneWidget);
    expect(find.text(LfgStrings.statusCancelled), findsOneWidget);
  });
}
