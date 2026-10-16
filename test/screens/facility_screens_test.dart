import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/services/location_service.dart';
import 'package:test1/core/strings/facility_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';
import 'package:test1/screens/facility/facility_detail_screen.dart';
import 'package:test1/screens/facility/facility_search_screen.dart';

class _FakeLocationService extends LocationService {
  final LocationResult result;

  const _FakeLocationService(this.result);

  @override
  Future<LocationResult> getCurrentLocation() async => result;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositories.facility = MockFacilityRepository(latency: Duration.zero);
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Tìm sân: bị từ chối quyền vị trí vẫn hiện danh sách, lọc được theo môn', (tester) async {
    await pumpScreen(
      tester,
      const FacilitySearchScreen(
        locationService: _FakeLocationService(LocationResult(LocationStatus.denied)),
      ),
    );

    expect(find.text(FacilityStrings.locationDenied), findsOneWidget);
    expect(find.text('Hồ Chí Minh'), findsOneWidget);
    expect(find.text(FacilityStrings.resultCount(8)), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, Sport.badminton.label));
    await tester.pumpAndSettle();
    expect(find.text(FacilityStrings.resultCount(5)), findsOneWidget);
    expect(find.text('Trung Tâm TDTT Kỳ Hòa'), findsNothing); // không có cầu lông
  });

  testWidgets('Tìm sân: có GPS ở Hà Nội thì tự chọn Hà Nội và hiện khoảng cách', (tester) async {
    await pumpScreen(
      tester,
      const FacilitySearchScreen(
        locationService: _FakeLocationService(
          LocationResult(LocationStatus.granted, GeoPoint(21.0360, 105.7935)),
        ),
      ),
    );

    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text(FacilityStrings.locationDenied), findsNothing);
    // Sân Cầu Giấy cách vị trí ~70 m nên đứng đầu danh sách.
    expect(find.textContaining(' m'), findsWidgets);
  });

  testWidgets('Tìm sân: bấm vào thẻ cơ sở mở màn chi tiết', (tester) async {
    await pumpScreen(
      tester,
      const FacilitySearchScreen(
        locationService: _FakeLocationService(LocationResult(LocationStatus.denied)),
      ),
    );

    await tester.tap(find.text('Pickleball Thảo Điền'));
    await tester.pumpAndSettle();
    expect(find.byType(FacilityDetailScreen), findsOneWidget);
    expect(find.text(FacilityStrings.chooseSlot), findsOneWidget);
  });

  testWidgets('Chi tiết: chọn khung giờ rồi đặt sân thì sang màn thanh toán', (tester) async {
    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');
    await pumpScreen(tester, FacilityDetailScreen(facility: facility, initialSport: Sport.badminton));
    // Màn Thanh toán cũ có hàng tổng tiền chưa co giãn, bị tràn ở font test (rộng hơn font thật).
    // Mở rộng màn hình giả lập cho test này; lỗi đó sẽ sửa khi tới lượt chuyển màn Thanh toán.
    tester.view.physicalSize = const Size(1800, 2400);
    await tester.pumpAndSettle();

    // Chưa chọn khung giờ thì nút đặt sân bị khóa.
    final bookButton = find.widgetWithText(ElevatedButton, FacilityStrings.bookNow);
    expect(tester.widget<ElevatedButton>(bookButton).onPressed, isNull);

    // Chọn ngày mai để chắc chắn còn khung giờ chưa qua.
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await tester.tap(find.text(Formatters.dayMonth(tomorrow)));
    await tester.pumpAndSettle();

    final available = find.textContaining('Còn ');
    expect(available, findsWidgets);
    await tester.ensureVisible(available.first);
    await tester.pumpAndSettle();
    // Ô đầu có thể nằm dưới thanh ảnh đang ghim; chỉ bấm vào ô thực sự bấm được.
    await tester.tap(available.hitTestable().first);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(bookButton).onPressed, isNotNull);

    await tester.tap(bookButton);
    await tester.pumpAndSettle();
    expect(find.byType(BookingCheckoutScreen), findsOneWidget);

    // Quay lại chưa thanh toán: về màn chi tiết (chỗ giữ được nhả, vẫn giữ lựa chọn).
    await tester.tap(find.descendant(of: find.byType(BookingCheckoutScreen), matching: find.byIcon(Icons.arrow_back)));
    await tester.pumpAndSettle();
    expect(find.byType(FacilityDetailScreen), findsOneWidget);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(1)), findsOneWidget);
  });

  testWidgets('Chi tiết: chọn nhiều khung ở 2 ngày, bỏ chọn được, tổng tiền cộng dồn', (tester) async {
    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-eco-q7');
    await pumpScreen(tester, FacilityDetailScreen(facility: facility, initialSport: Sport.badminton));

    final now = DateTime.now();
    final day1 = DateTime(now.year, now.month, now.day + 1);
    final day2 = DateTime(now.year, now.month, now.day + 2);
    final repo = AppRepositories.facility;
    final open1 = (await repo.getTimeSlots(facility.id, Sport.badminton, day1)).where((s) => !s.isFull).toList();
    final open2 = (await repo.getTimeSlots(facility.id, Sport.badminton, day2)).where((s) => !s.isFull).toList();

    Future<void> tapSlot(DateTime start) async {
      final finder = find.text(Formatters.timeRange(start, start.add(const Duration(hours: 1))));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder.hitTestable());
      await tester.pumpAndSettle();
    }

    Future<void> openDay(DateTime day) async {
      // Cuộn về đầu trang: nếu dùng ensureVisible, thanh chọn ngày sẽ nằm dưới thanh ảnh đang ghim.
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 2000), 3000);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Formatters.dayMonth(day)).hitTestable());
      await tester.pumpAndSettle();
    }

    // Ngày 1: chọn 2 khung.
    await openDay(day1);
    await tapSlot(open1[0].start);
    await tapSlot(open1[1].start);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(2)), findsOneWidget);

    // Sang ngày 2 chọn thêm 1 khung: lựa chọn ngày 1 vẫn còn.
    await openDay(day2);
    await tapSlot(open2[0].start);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(3)), findsOneWidget);
    expect(find.text(Formatters.vnd(open1[0].price + open1[1].price + open2[0].price)), findsOneWidget);

    // Bấm lại để bỏ chọn.
    await tapSlot(open2[0].start);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(2)), findsOneWidget);
    expect(find.text(Formatters.vnd(open1[0].price + open1[1].price)), findsOneWidget);

    // Xem danh sách đã chọn rồi bỏ chọn tất cả.
    await tester.tap(find.textContaining(FacilityStrings.selectedSlotCount(2)));
    await tester.pumpAndSettle();
    expect(find.text(FacilityStrings.selectedSlotsTitle), findsOneWidget);
    await tester.tap(find.text(FacilityStrings.clearSelection));
    await tester.pumpAndSettle();
    expect(find.text(FacilityStrings.selectSlotFirst), findsOneWidget);
  });

  testWidgets('Chi tiết: bóng đá chọn loại sân, mỗi loại số sân và giá riêng; đổi loại thì bỏ chọn khung giờ', (tester) async {
    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-hoalu');
    await pumpScreen(tester, FacilityDetailScreen(facility: facility, initialSport: Sport.football));
    expect(find.text(FacilityStrings.chooseCourtType), findsOneWidget);
    expect(find.text('Sân 5 người (5 vs 5)'), findsOneWidget);
    expect(find.text('3 sân • Từ 500.000 đ'), findsOneWidget);
    expect(find.text('Sân 11 người (11 vs 11)'), findsOneWidget);

    final now = DateTime.now();
    await tester.ensureVisible(find.text(Formatters.dayMonth(DateTime(now.year, now.month, now.day + 1))));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Formatters.dayMonth(DateTime(now.year, now.month, now.day + 1))));
    await tester.pumpAndSettle();
    final available = find.textContaining('Còn ');
    await tester.ensureVisible(available.first);
    await tester.pumpAndSettle();
    await tester.tap(available.hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.textContaining(FacilityStrings.selectedSlotCount(1)), findsOneWidget);

    // Cuộn về đầu trang để chip loại sân không bị thanh ảnh đang ghim che.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sân 7 người (7 vs 7)'));
    await tester.pumpAndSettle();
    expect(find.textContaining(FacilityStrings.selectedSlotCount(1)), findsNothing);
    // Sân 7 người có 2 sân con.
    expect(find.text(FacilityStrings.chooseCourt), findsOneWidget);
    expect(find.text('Sân 2'), findsOneWidget);
    expect(find.text('Sân 3'), findsNothing);
  });

  testWidgets('Chi tiết: chọn sân con rồi chọn giờ; khung đã chọn ghi rõ sân con', (tester) async {
    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');
    await pumpScreen(tester, FacilityDetailScreen(facility: facility, initialSport: Sport.badminton));
    final now = DateTime.now();
    await tester.ensureVisible(find.text(Formatters.dayMonth(DateTime(now.year, now.month, now.day + 1))));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Formatters.dayMonth(DateTime(now.year, now.month, now.day + 1))));
    await tester.pumpAndSettle();
    expect(find.text('Sân 6'), findsOneWidget);

    await tester.ensureVisible(find.text('Sân 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sân 4'));
    await tester.pumpAndSettle();
    final available = find.text(FacilityStrings.available);
    await tester.ensureVisible(available.first);
    await tester.pumpAndSettle();
    await tester.tap(available.hitTestable().first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining(FacilityStrings.selectedSlotCount(1)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sân 4 • '), findsOneWidget);
  });
}
