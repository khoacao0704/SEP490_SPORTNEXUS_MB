import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/screens/auth/role_router.dart';
import 'package:test1/screens/owner/owner_main_screen.dart';
import 'package:test1/screens/owner/owner_scan_screen.dart';
import 'package:test1/screens/owner/owner_session_detail_screen.dart';

void main() {
  late AppUser owner;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero);
    owner = await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  test('Chủ sân đăng nhập vào giao diện Chủ sân', () {
    expect(homeScreenFor(owner), isA<OwnerMainScreen>());
  });

  testWidgets('khung Chủ sân: bottom nav riêng và chọn cơ sở', (tester) async {
    await pump(tester, OwnerMainScreen(user: owner));
    expect(find.text(OwnerStrings.greeting('Chủ Sân Demo')), findsOneWidget);
    for (final label in [
      OwnerStrings.navOverview,
      OwnerStrings.navSchedule,
      OwnerStrings.navScan,
      OwnerStrings.navFacilities,
      OwnerStrings.navAccount,
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text(OwnerStrings.allFacilities).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sân Bóng Hoa Lư').last);
    await tester.pumpAndSettle();
    expect(find.text('Sân Bóng Hoa Lư'), findsWidgets);
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsNothing);

    await tester.tap(find.text(OwnerStrings.navFacilities));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.title), findsOneWidget);
  });

  testWidgets('nhập mã vé: hiện sân con người chơi đã đặt rồi check-in', (tester) async {
    await pump(
      tester,
      const OwnerScanScreen(
        enableCamera: false,
        facilityId: 'mock-facility-id',
      ),
    );
    await tester.enterText(find.byType(TextField), 'SPN-BK-OW1001');
    await tester.tap(find.text(OwnerStrings.lookup));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    expect(find.text(OwnerStrings.bookedCourt('Sân 3')), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.confirmCheckIn));
    await tester.pumpAndSettle();

    expect(find.text(OwnerStrings.checkInSuccess('Nguyễn Minh Anh', 'Sân 3')), findsOneWidget);
  });

  testWidgets('quá giờ check-in: báo vắng mặt, không mở check-in', (tester) async {
    await pump(
      tester,
      const OwnerScanScreen(
        enableCamera: false,
        facilityId: 'mock-facility-id',
      ),
    );
    await tester.enterText(find.byType(TextField), 'SPN-LFG-LFGOW1-u-lfg-14');
    await tester.tap(find.text(OwnerStrings.lookup));
    await tester.pumpAndSettle();

    expect(find.text('Bùi Khánh Vy'), findsOneWidget);
    expect(find.textContaining('Hệ thống đã ghi nhận vắng mặt'), findsOneWidget);
    expect(find.text(OwnerStrings.confirmCheckIn), findsNothing);
  });

  testWidgets('check-out cả kèo LFG một lần và giải ngân', (tester) async {
    final session = await AppRepositories.owner.getSession('LFGOW1');
    await pump(tester, OwnerSessionDetailScreen(session: session));
    expect(find.text(OwnerStrings.checkedInCount(3, 4)), findsWidgets);
    expect(find.text(OwnerStrings.absent), findsOneWidget);

    await tester.tap(find.text(OwnerStrings.checkOut));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check-out cho tất cả người chơi trong kèo'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OwnerStrings.checkOut)));
    await tester.pumpAndSettle();

    expect(find.text(OwnerStrings.checkOutSuccess(160000)), findsOneWidget);
    expect(find.text(OwnerStrings.statusCompleted), findsOneWidget);
    expect(find.text(OwnerStrings.disbursed(160000)), findsOneWidget);
    expect(find.text(OwnerStrings.checkOut), findsNothing);
  });

  testWidgets('cọc 1/4: hiện phần chủ sân tự thu tại sân', (tester) async {
    final session = await AppRepositories.owner.getSession('OW1001');
    await pump(tester, OwnerSessionDetailScreen(session: session));
    expect(find.text(OwnerStrings.remainingToCollect), findsOneWidget);
    expect(find.text(Formatters.vnd(120000)), findsOneWidget);
    expect(find.text(OwnerStrings.checkIn), findsOneWidget);
  });
}
