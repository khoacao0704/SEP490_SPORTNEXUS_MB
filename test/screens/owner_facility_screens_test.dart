import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/core/strings/owner_slot_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/owner_facility.dart';
import 'package:test1/screens/owner/facility_form_screen.dart';
import 'package:test1/screens/owner/owner_facilities_screen.dart';
import 'package:test1/screens/owner/owner_facility_detail_screen.dart';

import '../helpers/layout_check.dart';

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

  testWidgets('hồ sơ bị từ chối: thấy lý do, sửa thông tin được như Web', (tester) async {
    final rejected = await AppRepositories.owner.getOwnerFacility('f-own-rejected');
    await pump(tester, OwnerFacilityDetailScreen(facility: rejected));
    expect(find.text(OwnerFacilityStrings.badgeRejected), findsOneWidget);
    expect(find.textContaining('Ảnh giấy phép bị mờ'), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.editTitle), findsOneWidget);
    expect(find.text(OwnerFacilityStrings.closeButton), findsOneWidget);
  });

  testWidgets('tạo cơ sở: thiếu tên báo lỗi; đủ tên + tỉnh + phường + số nhà thì tạo, chờ duyệt', (tester) async {
    await pump(tester, const FacilityFormScreen());
    expect(find.text(OwnerFacilityStrings.createHint), findsOneWidget);
    await tester.tap(find.text(OwnerFacilityStrings.createSubmit));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.errName), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, OwnerFacilityStrings.fName), 'Sân Mới');
    await tester.tap(find.text(OwnerFacilityStrings.createSubmit));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.errAddress), findsOneWidget);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, OwnerFacilityStrings.fProvince));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ Chí Minh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, OwnerFacilityStrings.fWard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phường Sài Gòn').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, OwnerFacilityStrings.fStreet), '1 Lê Lợi');
    await tester.enterText(find.widgetWithText(TextField, OwnerFacilityStrings.fDiscount), '60');
    await tester.tap(find.text(OwnerFacilityStrings.createSubmit));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.errDiscount), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, OwnerFacilityStrings.fDiscount), '10');
    await tester.tap(find.text('Wifi'));
    await tester.tap(find.text(OwnerFacilityStrings.createSubmit));
    await tester.pumpAndSettle();
    final all = await AppRepositories.owner.getOwnerFacilities();
    expect(all, hasLength(5));
    expect(all.first.profile.address, '1 Lê Lợi, Phường Sài Gòn, Hồ Chí Minh');
    expect(all.first.status, ApprovalStatus.pending);
    expect(all.first.amenityItems.single.name, 'Wifi');
  });

  testWidgets('sửa thông tin: form điền sẵn, lưu thẳng không chờ duyệt lại', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OwnerFacilityDetailScreen(facility: hoaLu));
    await tester.tap(find.text(OwnerFacilityStrings.editTitle));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Sân Bóng Hoa Lư'), findsOneWidget);
    expect(find.text('Hồ Chí Minh'), findsOneWidget, reason: 'tỉnh điền sẵn theo tên');

    await tester.enterText(find.widgetWithText(TextField, OwnerFacilityStrings.fName), 'Hoa Lư Arena');
    // Phường cũ không có trong danh mục mới: phải chọn lại mới lưu được (như Web).
    await tester.tap(find.text(OwnerFacilityStrings.saveInfo));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.errAddress), findsOneWidget);
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, OwnerFacilityStrings.fWard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phường Tân Định').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerFacilityStrings.saveInfo));
    await tester.pumpAndSettle();
    expect(find.text('Hoa Lư Arena'), findsWidgets);
    expect(find.text(OwnerFacilityStrings.badgeApproved), findsOneWidget);
  });

  testWidgets('tiện ích: chọn rồi Lưu tiện ích; Hoàn tác bỏ thay đổi', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OwnerFacilityDetailScreen(facility: hoaLu));
    await tester.tap(find.text('Wifi'));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.undo), findsOneWidget);
    await tester.tap(find.text(OwnerFacilityStrings.saveAmenities));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.amenitiesSaved), findsOneWidget);
    expect((await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu')).operations.amenities, contains('Wifi'));
  });

  testWidgets('đóng cơ sở có hộp thoại xác nhận', (tester) async {
    final pending = await AppRepositories.owner.getOwnerFacility('f-own-pending');
    await pump(tester, OwnerFacilityDetailScreen(facility: pending));
    await tester.tap(find.text(OwnerFacilityStrings.closeButton));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.closeConfirm(pending.profile.name)), findsOneWidget);
    await tester.tap(find.text(OwnerFacilityStrings.confirm));
    await tester.pumpAndSettle();
    expect((await AppRepositories.owner.getOwnerFacilities()).any((f) => f.id == 'f-own-pending'), isFalse);
  });

  testWidgets('bố cục form cơ sở và chi tiết cơ sở: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    final problems = [
      ...await collectLayoutProblems(tester, 'Form tạo', () => const FacilityFormScreen()),
      ...await collectLayoutProblems(tester, 'Form sửa', () => FacilityFormScreen(facility: hoaLu)),
      ...await collectLayoutProblems(tester, 'Chi tiết', () => OwnerFacilityDetailScreen(facility: hoaLu)),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('chi tiết cơ sở có "Sân & giá" và "Ca sân" như web', (tester) async {
    final tt = await AppRepositories.owner.getOwnerFacility('f-hcm-thientrieu');
    await pump(tester, OwnerFacilityDetailScreen(facility: tt));
    expect(find.text(OwnerSlotStrings.courtsEntry), findsOneWidget);
    expect(find.text(OwnerSlotStrings.slotsEntry), findsOneWidget);

    await tester.tap(find.text(OwnerSlotStrings.courtsEntry));
    await tester.pumpAndSettle();
    expect(find.text(OwnerSlotStrings.tabZones), findsOneWidget);
    expect(find.text(OwnerSlotStrings.zoneTotal(3)), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerSlotStrings.slotsEntry));
    await tester.pumpAndSettle();
    expect(find.text(OwnerSlotStrings.weekTitle), findsOneWidget);
    expect(find.text(OwnerSlotStrings.generateTitle), findsOneWidget);
  });

  testWidgets('chi tiết cơ sở đã duyệt: có lịch tạm đóng và mở lại được', (tester) async {
    final hoaLu = await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu');
    await pump(tester, OwnerFacilityDetailScreen(facility: hoaLu));
    expect(find.text('Thay mặt cỏ sân 11 người'), findsOneWidget);

    await tester.tap(find.text(OwnerFacilityStrings.reopen));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFacilityStrings.noClosures), findsOneWidget);
    expect((await AppRepositories.owner.getOwnerFacility('f-hcm-hoalu')).closures, isEmpty);
    expect(hoaLu.status, ApprovalStatus.approved);
  });
}
