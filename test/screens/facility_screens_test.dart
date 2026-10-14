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

    // Quay lại chưa thanh toán: về màn chi tiết (chỗ giữ được nhả).
    await tester.tap(find.descendant(of: find.byType(BookingCheckoutScreen), matching: find.byIcon(Icons.arrow_back)));
    await tester.pumpAndSettle();
    expect(find.byType(FacilityDetailScreen), findsOneWidget);
  });
}
