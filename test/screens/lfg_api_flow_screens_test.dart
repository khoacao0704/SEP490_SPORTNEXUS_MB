import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/core/utils/formatters.dart';
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

  static LfgMatch build({
    required bool hostIsMe,
    LfgMyStatus? myStatus,
    bool meJoined = false,
    bool cancelled = false,
    Duration startsIn = const Duration(days: 4),
    int courtPrice = 200000,
    int otherJoiners = 0,
  }) {
    final start = DateTime.now().add(startsIn);
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
      courtPrice: courtPrice,
      members: [
        LfgMember(userId: hostIsMe ? _me : 'u-host', name: 'Chủ Kèo', fairPlayScore: 90, joinedAt: DateTime.now(), isHost: true),
        if (meJoined) LfgMember(userId: _me, name: 'Khoa Cao', fairPlayScore: 93, joinedAt: DateTime.now()),
        for (var i = 0; i < otherJoiners; i++)
          LfgMember(userId: 'u-j$i', name: 'Người chơi $i', fairPlayScore: 90, joinedAt: DateTime.now()),
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
    expect(find.textContaining('Host đã trả trước toàn bộ giá sân'), findsOneWidget);

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

  testWidgets('host hủy dưới 48h: cảnh báo gắt số tiền bị trừ, bồi thường mỗi người, −20 Fair Play', (tester) async {
    // Ví dụ BE: tiền sân 150.000đ, 2 người đã vào → host mất 75.000đ, mỗi người nhận 37.500đ.
    lfg.current = _BeLikeLfg.build(hostIsMe: true, startsIn: const Duration(hours: 20), courtPrice: 150000, otherJoiners: 2);
    await pump(tester);

    await tester.tap(find.text(LfgStrings.cancelMatch));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.lateCancelTitle), findsOneWidget);
    expect(find.text(LfgStrings.lateCancelWarning), findsOneWidget);
    expect(find.text('−${Formatters.vnd(75000)}'), findsOneWidget);
    expect(find.text(Formatters.vnd(37500)), findsOneWidget);
    expect(find.text(LfgStrings.lateCancelFairPlay), findsOneWidget);

    // Quay lại: không hủy.
    await tester.tap(find.text(LfgStrings.lateCancelBack));
    await tester.pumpAndSettle();
    expect(lfg.calls, isEmpty);

    await tester.tap(find.text(LfgStrings.cancelMatch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LfgStrings.lateCancelConfirm));
    await tester.pumpAndSettle();
    expect(lfg.calls, ['cancel']);
    expect(find.text(LfgStrings.lateCancelledMessage(75000)), findsOneWidget);
  });

  testWidgets('host hủy dưới 48h khi chưa ai vào: hoàn đủ tiền sân nhưng vẫn −20 Fair Play', (tester) async {
    lfg.current = _BeLikeLfg.build(hostIsMe: true, startsIn: const Duration(hours: 20));
    await pump(tester);

    await tester.tap(find.text(LfgStrings.cancelMatch));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.lateCancelWarningNoJoiner), findsOneWidget);
    expect(find.text(LfgStrings.lateCancelLossLabel), findsNothing);
    expect(find.text(LfgStrings.lateCancelFairPlay), findsOneWidget);
  });

  testWidgets('cảnh báo hủy đơn phương không tràn trên máy nhỏ, chữ phóng to', (tester) async {
    lfg.current = _BeLikeLfg.build(hostIsMe: true, startsIn: const Duration(hours: 20), courtPrice: 1500000, otherJoiners: 3);
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.6)),
        child: LfgMatchDetailScreen(matchId: 'c1'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LfgStrings.cancelMatch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(LfgStrings.lateCancelConfirm), findsOneWidget);
  });
}
