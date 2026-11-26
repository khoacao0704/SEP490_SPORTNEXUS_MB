import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_booking_data.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/owner_booking.dart';
import 'package:test1/screens/auth/role_router.dart';
import 'package:test1/screens/owner/owner_booking_detail_screen.dart';
import 'package:test1/screens/owner/owner_main_screen.dart';
import 'package:test1/screens/owner/owner_scan_screen.dart';
import 'package:test1/widgets/owner/schedule_grid_view.dart';

void main() {
  late AppUser owner;
  // Giữ giờ giả lập 15:00 hôm nay để đơn mẫu cố định: 14–16h kèo LFG đang chơi, 15h vãng lai,
  // 16h Nguyễn Minh Anh đã thanh toán, 17–19h chờ góp tiền, 18h sân 3 khóa.
  final today = DateTime.now();
  final fixedNow = DateTime(today.year, today.month, today.day, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero, now: () => fixedNow);
    owner = await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home, {Size size = const Size(640, 1440), double textScale = 1}) async {
    tester.view.physicalSize = size * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Cuộn lưới tới dòng giờ [scrollTo] rồi bấm ô khớp [matching] đang nằm trong màn hình.
  Future<void> tapGridCell(WidgetTester tester, Finder matching, {required String scrollTo}) async {
    final grid = find.byType(ScheduleGridView);
    final list = find.descendant(of: grid, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.descendant(of: grid, matching: find.text(scrollTo)), 120, scrollable: list);
    await tester.drag(list, const Offset(0, -150));
    await tester.pumpAndSettle();
    final view = tester.getRect(list);
    final cells = find.descendant(of: grid, matching: matching);
    final onScreen = cells.evaluate().toList().indexWhere((e) {
      final r = tester.getRect(find.byElementPredicate((x) => x == e));
      return view.contains(r.topLeft) && view.contains(r.bottomRight);
    });
    expect(onScreen, isNonNegative, reason: 'không thấy ô cần bấm trên màn hình');
    await tester.tap(cells.at(onScreen));
  }

  Future<void> openScheduleTab(WidgetTester tester) async {
    await pump(tester, OwnerMainScreen(user: owner));
    await tester.tap(find.text(OwnerStrings.navSchedule));
    await tester.pumpAndSettle();
  }

  test('Chủ sân đăng nhập vào giao diện Chủ sân', () {
    expect(homeScreenFor(owner), isA<OwnerMainScreen>());
  });

  testWidgets('khung Chủ sân: luôn quản lý một cơ sở (không có "Tất cả cơ sở"), đổi được cơ sở', (tester) async {
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
    // Tổng quan hôm nay của Thiên Triều: có khách đặt hôm nay.
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);

    await tester.tap(find.text('Sân Cầu Lông Thiên Triều').first);
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.allFacilities), findsNothing);
    await tester.tap(find.text('Sân Bóng Hoa Lư').last);
    await tester.pumpAndSettle();
    expect(find.text('Phạm Đức Huy'), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsNothing);

    await tester.tap(find.text(OwnerStrings.navFacilities));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.title), findsOneWidget);
  });

  testWidgets('lưới lịch: bấm ô trống → nhận khách vãng lai → ô thành đã đặt', (tester) async {
    await openScheduleTab(tester);
    expect(find.text(OwnerStrings.viewGrid), findsOneWidget);
    expect(find.descendant(of: find.byType(ScheduleGridView), matching: find.text('FC Hoàng Gia')), findsOneWidget);

    await tapGridCell(tester, find.text(OwnerStrings.cellFree), scrollTo: '20:00');
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.walkInTitle), findsOneWidget);

    // Chưa nhập tên: báo lỗi, không tạo đơn.
    await tester.tap(find.text(OwnerStrings.walkInSubmit));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.walkInNameRequired), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, OwnerStrings.walkInNameHint), 'Anh Tuấn');
    await tester.tap(find.text(OwnerStrings.walkInSubmit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã nhận đặt sân cho "Anh Tuấn"'), findsOneWidget);
    expect(find.descendant(of: find.byType(ScheduleGridView), matching: find.text('Anh Tuấn')), findsOneWidget);
  });

  testWidgets('lưới lịch: ô đã thanh toán → check-in thủ công; ô bảo trì → mở lại ca', (tester) async {
    await openScheduleTab(tester);
    await tapGridCell(tester, find.text('Nguyễn Minh Anh'), scrollTo: '16:00');
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.slotBookingTitle('Sân 3')), findsOneWidget);
    expect(find.text(OwnerStrings.slotStatusLabel(SlotCellState.paid)), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.manualCheckIn));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.manualCheckInDone), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(ScheduleGridView))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tapGridCell(tester, find.text(OwnerStrings.cellMaintenance), scrollTo: '18:00');
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.maintenanceTitle), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.unlockSlot));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.slotUnlocked), findsOneWidget);
    expect(find.text(OwnerStrings.cellMaintenance), findsNothing);
  });

  testWidgets('danh sách đơn: lọc trạng thái, mở chi tiết', (tester) async {
    await openScheduleTab(tester);
    await tester.tap(find.text(OwnerStrings.viewList));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.statActiveRevenue), findsOneWidget);
    expect(find.text('Trần Quốc Bảo'), findsOneWidget);

    await tester.tap(find.text(OwnerStrings.statusAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerStrings.statusFilters[OwnerBookingStatus.checkedIn]!).last);
    await tester.pumpAndSettle();
    expect(find.text('Trần Quốc Bảo'), findsNothing);
    expect(find.text('Võ Thanh Tùng'), findsOneWidget);

    await tester.tap(find.text(OwnerStrings.detail));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.detailTitle), findsOneWidget);
    expect(find.text(OwnerStrings.lfgBadge), findsOneWidget);
    expect(find.text(OwnerStrings.lfgTitle(3, 2)), findsOneWidget);
  });

  testWidgets('Chủ sân hủy đơn dưới 48h: cảnh báo 20% + −10 Fair Play, chọn lý do, xác nhận thì đơn bị hủy', (tester) async {
    await pump(tester, const OwnerBookingDetailScreen(bookingId: 'OW1001'));
    expect(find.text('Cho mượn thêm 2 vợt'), findsOneWidget);

    await tester.tap(find.text(OwnerStrings.cancelBooking));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.cancelPenaltyValue(20)), findsOneWidget);
    expect(find.text(OwnerStrings.cancelFairPlay(10)), findsOneWidget);
    expect(find.text(OwnerStrings.cancelWarning(20, fairPlay: 10, walkIn: false)), findsOneWidget);

    // Quay lại: không hủy.
    await tester.tap(find.text(OwnerStrings.cancelBack));
    await tester.pumpAndSettle();
    expect((await AppRepositories.owner.getBooking('OW1001')).status, OwnerBookingStatus.paid);

    await tester.tap(find.text(OwnerStrings.cancelBooking));
    await tester.pumpAndSettle();
    // Chọn "Khác (Tự nhập lý do)" mà bỏ trống thì phải nhập.
    await tester.tap(find.text(MockOwnerBookingData.cancelReasons.first.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MockOwnerBookingData.cancelReasons.last.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerStrings.cancelConfirmPenalty));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.cancelReasonRequired), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, OwnerStrings.cancelReasonHint), 'Sân hỏng đèn');
    await tester.tap(find.text(OwnerStrings.cancelLockSlot));
    await tester.tap(find.text(OwnerStrings.cancelConfirmPenalty));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền phạt đã trừ vào ví: ${Formatters.vnd(16000)}. Trừ 10 điểm Fair Play.'), findsOneWidget);
    expect(find.text(OwnerStrings.bookingBadge(OwnerBookingStatus.cancelled)), findsOneWidget);
    expect(find.textContaining('Sân hỏng đèn'), findsOneWidget);
    expect(find.text(OwnerStrings.cancelBooking), findsNothing);
  });

  testWidgets('đơn khách vãng lai: hủy không phạt, nút "Xác nhận hủy đơn"', (tester) async {
    await pump(tester, const OwnerBookingDetailScreen(bookingId: 'WI100'));
    expect(find.text(OwnerStrings.walkInBadge), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.cancelBooking));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.cancelWarning(0, fairPlay: 0, walkIn: true)), findsOneWidget);
    expect(find.text(OwnerStrings.cancelPenaltyValue(0)), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.cancelConfirm));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy đơn. Người đặt được hoàn 100% và nhận voucher 10%.'), findsOneWidget);
  });

  testWidgets('quét QR: nhập mã → xác nhận → check-in thành công, có trong nhật ký và danh sách đã check-in', (tester) async {
    await pump(
      tester,
      const OwnerScanScreen(
        enableCamera: false,
        facilityId: MockOwnerBookingData.thienTrieu,
        facilityName: 'Sân Cầu Lông Thiên Triều',
      ),
    );
    await tester.enterText(find.byType(TextField), MockOwnerBookingData.ticketCode('OW1001'));
    await tester.tap(find.text(OwnerStrings.lookup));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.scannedTitle), findsOneWidget);
    expect(find.text(OwnerStrings.scannedBody('Sân Cầu Lông Thiên Triều')), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.confirmCheckIn));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.scanSuccess), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.scanNext));
    await tester.pumpAndSettle();

    // Mã lạ: báo thất bại.
    await tester.enterText(find.byType(TextField), 'MA-LA');
    await tester.tap(find.text(OwnerStrings.lookup));
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerStrings.confirmCheckIn));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.scanFailed), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.scanNext));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(OwnerStrings.scanLog));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(ListTile), matching: find.textContaining('MA-LA')), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerStrings.todayBookings));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.tabWaiting(1)), findsOneWidget, reason: 'còn đơn vãng lai 15h');
    await tester.tap(find.text(OwnerStrings.manualCheckIn));
    await tester.pumpAndSettle();
    expect(find.text(OwnerStrings.todayCheckedIn('FC Hoàng Gia', 'Sân 1')), findsOneWidget);
    expect(find.text(OwnerStrings.todayNoWaiting), findsOneWidget);
    await tester.tap(find.text(OwnerStrings.tabChecked(3)));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
  });

  testWidgets('máy nhỏ, chữ phóng to: lưới, popup vãng lai, popup hủy không tràn', (tester) async {
    await pump(tester, OwnerMainScreen(user: owner), size: const Size(320, 568), textScale: 1.6);
    await tester.tap(find.text(OwnerStrings.navSchedule));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tapGridCell(tester, find.text(OwnerStrings.cellFree), scrollTo: '20:00');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(OwnerStrings.walkInTitle), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerStrings.viewList));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await pump(tester, const OwnerBookingDetailScreen(key: ValueKey('OW1002'), bookingId: 'OW1002'), size: const Size(320, 568), textScale: 1.6);
    expect(tester.takeException(), isNull);
    await pump(tester, const OwnerBookingDetailScreen(key: ValueKey('OW1001'), bookingId: 'OW1001'), size: const Size(320, 568), textScale: 1.6);
    await tester.tap(find.text(OwnerStrings.cancelBooking));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(OwnerStrings.cancelConfirmPenalty), findsOneWidget);
  });
}
