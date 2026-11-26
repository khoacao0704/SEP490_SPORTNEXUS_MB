import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_slot_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_booking_data.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/owner_facility.dart';
import 'package:test1/screens/owner/owner_courts_screen.dart';
import 'package:test1/screens/owner/owner_slots_screen.dart';

void main() {
  late OwnerFacility tt;
  final today = DateTime.now();
  final fixedNow = DateTime(today.year, today.month, today.day, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero, now: () => fixedNow);
    await auth.login('owner@sportnexus.vn', 'Owner@123');
    tt = await AppRepositories.owner.getOwnerFacility(MockOwnerBookingData.thienTrieu);
  });

  Future<void> pump(WidgetTester tester, Widget home, {Size size = const Size(640, 3200), double textScale = 1}) async {
    tester.view.physicalSize = size * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)), child: home),
    ));
    await tester.pumpAndSettle();
  }

  /// Cuộn tới chữ [text] (kể cả mục chưa dựng của ListView) rồi bấm; [first] để chọn mục đầu khi trùng chữ.
  Future<void> tapText(WidgetTester tester, String text, {bool first = false}) async {
    final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    if (find.text(text).evaluate().isEmpty && lists.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(find.text(text), 200, scrollable: lists.first);
    }
    final f = first ? find.text(text).first : find.text(text).last;
    // Đưa vào giữa khung nhìn (ensureVisible mặc định sát mép, có thể bị nút nổi che).
    await tester.runAsync(() => Scrollable.ensureVisible(tester.element(f), alignment: 0.5));
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('Sân & giá', () {
    testWidgets('khu cầu lông: tạm ngưng sân, mở lại; thêm sân mới', (tester) async {
      await pump(tester, OwnerCourtsScreen(facility: tt));
      expect(find.text(OwnerSlotStrings.zoneTotal(3)), findsOneWidget);
      expect(find.text(OwnerSlotStrings.courtActive), findsNWidgets(3));

      await tapText(tester, OwnerSlotStrings.suspendCourt, first: true);
      expect(find.text(OwnerSlotStrings.courtToggled(false, 'Sân 1')), findsOneWidget);
      expect(find.text(OwnerSlotStrings.courtInactive), findsOneWidget);
      await tapText(tester, OwnerSlotStrings.reopenCourt);
      expect(find.text(OwnerSlotStrings.courtInactive), findsNothing);

      await tapText(tester, OwnerSlotStrings.addCourtInZone);
      expect(find.text(OwnerSlotStrings.addCourtTitle), findsOneWidget);
      // Thiếu tên: báo lỗi.
      await tapText(tester, OwnerSlotStrings.create);
      expect(find.text(OwnerSlotStrings.errName), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, OwnerSlotStrings.courtName), 'Sân 4');
      await tapText(tester, OwnerSlotStrings.create);
      expect(find.text(OwnerSlotStrings.courtAdded('Sân 4')), findsOneWidget);
      expect(find.text(OwnerSlotStrings.zoneTotal(4)), findsOneWidget);
    });

    testWidgets('sửa giá sân: hỏi áp dụng cho ca trống từ ngày mai', (tester) async {
      await pump(tester, OwnerCourtsScreen(facility: tt));
      await tapText(tester, OwnerSlotStrings.edit, first: true);
      expect(find.text(OwnerSlotStrings.editCourtTitle('Sân 1')), findsOneWidget);
      expect(find.textContaining('ca trống 7 ngày tới'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, OwnerSlotStrings.defaultPrice), '95000');
      await tapText(tester, OwnerSlotStrings.save);
      expect(find.text(OwnerSlotStrings.regenerateBody), findsOneWidget);
      await tapText(tester, OwnerSlotStrings.regenerateYes);
      expect(find.text(OwnerSlotStrings.regenerated('Sân 1')), findsOneWidget);
    });

    testWidgets('xóa sân có hộp thoại xác nhận', (tester) async {
      await pump(tester, OwnerCourtsScreen(facility: tt));
      await tester.tap(find.byTooltip('${OwnerSlotStrings.delete} Sân 3'));
      await tester.pumpAndSettle();
      expect(find.text(OwnerSlotStrings.deleteCourtConfirm('Sân 3')), findsOneWidget);
      await tapText(tester, OwnerSlotStrings.confirm);
      expect(find.textContaining('Đã xóa Sân 3'), findsOneWidget);
      expect(find.text(OwnerSlotStrings.zoneTotal(2)), findsOneWidget);
    });

    testWidgets('bảng giá khu và giờ mở cửa', (tester) async {
      await pump(tester, OwnerCourtsScreen(facility: tt));
      await tester.tap(find.text(OwnerSlotStrings.tabPricing));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, OwnerSlotStrings.pricingPriceLabel), '90000');
      await tapText(tester, OwnerSlotStrings.savePrice);
      expect(find.text(OwnerSlotStrings.regenerateBody), findsOneWidget);
      await tapText(tester, OwnerSlotStrings.regenerateNo);
      expect((await AppRepositories.owner.getCourts(tt.id)).every((c) => c.defaultPrice == 90000), isTrue);

      await tester.tap(find.text(OwnerSlotStrings.tabTimeGrid));
      await tester.pumpAndSettle();
      expect(find.text(OwnerSlotStrings.slotMinutesTitle), findsOneWidget);
      await tapText(tester, OwnerSlotStrings.saveHours);
      expect(find.text(OwnerSlotStrings.hoursSaved), findsOneWidget);
    });
  });

  group('Ca sân', () {
    testWidgets('lịch 7 ngày: mở một ô, xóa ca trống', (tester) async {
      await pump(tester, OwnerSlotsScreen(facilityId: tt.id, facilityName: tt.profile.name));
      expect(find.text(OwnerSlotStrings.weekTitle), findsOneWidget);
      expect(find.textContaining('Khách tìm sân hôm nay đặt được'), findsOneWidget);
      expect(find.text(OwnerSlotStrings.dayCell(16)), findsWidgets);

      await tester.tap(find.text(OwnerSlotStrings.dayCell(16)).first);
      await tester.pumpAndSettle();
      final deletes = find.text(OwnerSlotStrings.delete);
      expect(deletes, findsWidgets);
      await tester.ensureVisible(deletes.first);
      await tester.pumpAndSettle();
      await tester.tap(deletes.first);
      await tester.pumpAndSettle();
      await tapText(tester, OwnerSlotStrings.confirm);
      expect(find.text(OwnerSlotStrings.slotDeleted), findsOneWidget);
    });

    testWidgets('thao tác hàng loạt: đổi giá thiếu giá thì báo lỗi; khóa ca hôm nay', (tester) async {
      await pump(tester, OwnerSlotsScreen(facilityId: tt.id, facilityName: tt.profile.name));
      await tapText(tester, OwnerSlotStrings.bulkPrice);
      final submit = find.widgetWithText(ElevatedButton, OwnerSlotStrings.bulkPrice);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text(OwnerSlotStrings.errNewPrice), findsOneWidget);

      await tapText(tester, OwnerSlotStrings.bulkLock);
      final lock = find.widgetWithText(ElevatedButton, OwnerSlotStrings.bulkLock);
      await tester.ensureVisible(lock);
      await tester.tap(lock);
      await tester.pumpAndSettle();
      expect(find.textContaining('Khớp '), findsOneWidget);
    });

    testWidgets('sinh ca có khung giá giờ vàng', (tester) async {
      await pump(tester, OwnerSlotsScreen(facilityId: tt.id, facilityName: tt.profile.name));
      await tapText(tester, OwnerSlotStrings.addRule);
      await tester.enterText(find.widgetWithText(TextField, OwnerSlotStrings.rulePrice), '150000');
      await tapText(tester, OwnerSlotStrings.generate);
      expect(find.textContaining('Tạo mới'), findsWidgets);
    });

    testWidgets('đợt giá đặc biệt: tạo đợt', (tester) async {
      await pump(tester, OwnerSlotsScreen(facilityId: tt.id, facilityName: tt.profile.name));
      expect(find.text(OwnerSlotStrings.periodsEmpty), findsOneWidget);
      await tapText(tester, OwnerSlotStrings.newPeriod);
      await tapText(tester, OwnerSlotStrings.savePeriod);
      expect(find.text(OwnerSlotStrings.errPeriodName), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, OwnerSlotStrings.periodName), 'Sale cuối năm');
      await tester.enterText(find.widgetWithText(TextField, OwnerSlotStrings.periodPrice).first, '70000');
      await tapText(tester, OwnerSlotStrings.savePeriod);
      expect(find.textContaining('Đã tạo đợt "Sale cuối năm"'), findsOneWidget);
      expect(find.text('Sale cuối năm'), findsOneWidget);
    });
  });

  testWidgets('máy nhỏ, chữ phóng to: Sân & giá, form sân, Ca sân không tràn', (tester) async {
    const small = Size(320, 568);
    await pump(tester, OwnerCourtsScreen(facility: tt), size: small, textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tapText(tester, OwnerSlotStrings.edit, first: true);
    expect(tester.takeException(), isNull);
    // Form chiếm gần hết màn khi chữ to: đóng như bấm nút Back.
    Navigator.of(tester.element(find.text(OwnerSlotStrings.editCourtTitle('Sân 1')))).pop();
    await tester.pumpAndSettle();
    expect(find.text(OwnerSlotStrings.editCourtTitle('Sân 1')), findsNothing);
    for (final tab in [OwnerSlotStrings.tabPricing, OwnerSlotStrings.tabTimeGrid]) {
      await tester.ensureVisible(find.text(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pump(tester, OwnerSlotsScreen(facilityId: tt.id, facilityName: tt.profile.name), size: small, textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tapText(tester, OwnerSlotStrings.newPeriod);
    expect(tester.takeException(), isNull);
    await tapText(tester, OwnerSlotStrings.addRule);
    expect(tester.takeException(), isNull);
  });
}
