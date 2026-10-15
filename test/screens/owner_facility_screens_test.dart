import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/owner_facility.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/owner/court_pricing_screen.dart';
import 'package:test1/screens/owner/facility_form_screen.dart';
import 'package:test1/screens/owner/owner_facilities_screen.dart';
import 'package:test1/screens/owner/owner_facility_detail_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero);
    await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('tab Cơ sở hiện trạng thái duyệt của từng cơ sở', (tester) async {
    await pump(tester, OwnerFacilitiesScreen(onChanged: () {}));
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.statusApproved), findsNWidgets(2));
    expect(find.text(OwnerFacilityStrings.statusPending), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.statusRejected), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.needsPricing), findsOneWidget); // Hoa Lư: nửa sân 3x3
    expect(find.text(OwnerFacilityStrings.addFacility), findsOneWidget);
  });

  testWidgets('hồ sơ bị từ chối: xem lý do, sửa & nộp lại thành chờ duyệt', (tester) async {
    final rejected = await AppRepositories.owner.getOwnerFacility('f-own-rejected');
    await pump(tester, OwnerFacilityDetailScreen(facility: rejected));
    expect(find.textContaining('Ảnh giấy phép bị mờ'), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.lockedUntilApproved), findsOneWidget);

    await tester.tap(find.text(OwnerFacilityStrings.resubmit));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.resubmitTitle), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, OwnerFacilityStrings.licenseNumber), '0319999888');
    await tester.tap(find.text(OwnerFacilityStrings.submit));
    await tester.pumpAndSettle();

    expect(find.text(OwnerFacilityStrings.pendingBanner), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.resubmit), findsNothing);
    expect(find.text('0319999888'), findsOneWidget);
  });

  testWidgets('đăng cơ sở mới thiếu thông tin thì báo lỗi từng mục', (tester) async {
    await pump(tester, const FacilityFormScreen());
    await tester.tap(find.text(OwnerFacilityStrings.submit));
    await tester.pumpAndSettle();

    expect(find.text(OwnerFacilityStrings.required), findsWidgets);
    expect(find.text(OwnerFacilityStrings.missingLocation), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.missingCourt), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.missingPhoto), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.missingLicenseImage), findsOneWidget);
    expect((await AppRepositories.owner.getOwnerFacilities()), hasLength(4));
  });

  testWidgets('yêu cầu đổi thông tin chỉ có tên / địa chỉ / giấy phép', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OwnerFacilityDetailScreen(facility: hoaLu));
    await tester.tap(find.text(OwnerFacilityStrings.requestChange));
    await tester.pumpAndSettle();

    expect(find.text(OwnerFacilityStrings.changeTitle), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.formCourts), findsNothing);
    expect(find.text(OwnerFacilityStrings.formPhotos), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, OwnerFacilityStrings.name), 'Hoa Lư Arena');
    await tester.tap(find.text(OwnerFacilityStrings.submitChange));
    await tester.pumpAndSettle();

    expect(find.text(OwnerFacilityStrings.changePendingBanner), findsOneWidget);
    expect(find.text('Sân Bóng Hoa Lư'), findsWidgets); // vẫn tên cũ khi chờ duyệt
  });

  testWidgets('cài giá cho loại sân chưa có giá', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    final half = hoaLu.courtFor(Sport.basketball, CourtType.basketballHalf)!;
    await pump(tester, CourtPricingScreen(facility: hoaLu, court: half));

    expect(find.text(OwnerFacilityStrings.preview), findsNothing);
    final prices = find.widgetWithText(TextFormField, OwnerFacilityStrings.normalPrice);
    final peaks = find.widgetWithText(TextFormField, OwnerFacilityStrings.peakPrice);
    await tester.enterText(prices.first, '150000');
    await tester.enterText(peaks.first, '200000');
    await tester.enterText(prices.last, '170000');
    await tester.enterText(peaks.last, '220000');
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.preview), findsOneWidget);
    expect(find.text('17:00 - 18:00'), findsNWidgets(2));

    await tester.tap(find.text(OwnerFacilityStrings.save));
    await tester.pumpAndSettle();
    final saved = (await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu'))
        .courtFor(Sport.basketball, CourtType.basketballHalf)!;
    expect(saved.pricing!.weekdayPrice, 150000);
    expect(saved.pricing!.weekendPeakPrice, 220000);
  });

  testWidgets('khóa loại sân rồi mở khóa lại', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OwnerFacilityDetailScreen(facility: hoaLu));
    await tester.tap(find.textContaining('Sân đầy đủ 5x5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerFacilityStrings.lockCourt));
    await tester.pumpAndSettle();
    expect(find.textContaining('cho tới khi bạn mở khóa'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OwnerFacilityStrings.lockCourt)));
    await tester.pumpAndSettle();

    expect(find.text(OwnerFacilityStrings.locked), findsOneWidget);
    await tester.tap(find.textContaining('Sân đầy đủ 5x5'));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.pricingTitle), findsNothing); // đang khóa thì không mở màn sửa

    await tester.tap(find.text(OwnerFacilityStrings.unlock));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.locked), findsNothing);
    final court = (await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu'))
        .courtFor(Sport.basketball, CourtType.basketballFull)!;
    expect(court.isLocked, isFalse);
  });

  testWidgets('chi tiết cơ sở đã duyệt: có lịch tạm đóng và mở lại được', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OwnerFacilityDetailScreen(facility: hoaLu));
    expect(find.text('Thay mặt cỏ sân 11 người'), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.noPricing), findsOneWidget);

    await tester.tap(find.text(OwnerFacilityStrings.reopen));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.noClosures), findsOneWidget);
    expect((await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu')).closures, isEmpty);
    expect(hoaLu.status, ApprovalStatus.approved);
  });
}
