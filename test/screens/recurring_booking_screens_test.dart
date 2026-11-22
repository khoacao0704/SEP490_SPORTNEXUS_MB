import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/booking_rules.dart';
import 'package:test1/core/strings/booking_strings.dart';
import 'package:test1/core/strings/facility_strings.dart';
import 'package:test1/core/strings/split_payment_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/recurring_plan.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';
import 'package:test1/screens/booking/my_bookings_screen.dart';
import 'package:test1/screens/facility/facility_detail_screen.dart';
import 'package:test1/widgets/booking/recurring_booking_section.dart';
import 'package:test1/widgets/facility/slot_picker.dart';

import '../helpers/layout_check.dart';

/// Như bản giả lập sân nhưng mọi khung đều còn trống: bản giả lập thường đánh dấu "đã có người đặt" theo hash của
/// id khung, các ngày khác nhau ít nên cùng một giờ hiếm khi trống đủ 8 ngày → test không ổn định.
class _AllFreeFacility extends MockFacilityRepository {
  _AllFreeFacility() : super(latency: Duration.zero);

  @override
  Future<List<TimeSlot>> getTimeSlots(String facilityId, Sport sport, DateTime date, {CourtType? courtType}) async => [
        for (final s in await super.getTimeSlots(facilityId, sport, date, courtType: courtType))
          TimeSlot(
            id: s.id,
            facilityId: s.facilityId,
            sport: s.sport,
            courtType: s.courtType,
            courtName: s.courtName,
            start: s.start,
            end: s.end,
            price: s.price,
            isAvailable: true,
          ),
      ];
}

void main() {
  late MockFacilityRepository facility;
  late MockBookingRepository booking;
  late MockWalletRepository wallet;
  final thienTrieu = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = MockWalletRepository(latency: Duration.zero, initialBalance: 5000000);
    facility = _AllFreeFacility();
    final review = MockReviewRepository(latency: Duration.zero);
    booking = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.review = review;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.booking = booking;
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet, bookings: booking);
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  /// Giờ trên sân [court] còn trống ở MỌI ngày trong [dates]; trả khung của từng ngày.
  Future<List<TimeSlot>> freeAt(List<DateTime> dates, String court) async {
    final days = [
      for (final d in dates)
        (await facility.getTimeSlots(thienTrieu.id, Sport.badminton, d)).where((s) => s.courtName == court).toList(),
    ];
    for (final first in days.first.where((s) => !s.isFull)) {
      final picked = [for (final d in days) d.where((s) => s.start.hour == first.start.hour).firstOrNull];
      if (picked.every((s) => s != null && !s.isFull)) return picked.cast<TimeSlot>();
    }
    throw StateError('không có giờ trống đủ ${dates.length} ngày');
  }

  /// Sân con + giờ còn trống ở MỌI ngày trong [dates] (dò lần lượt mọi sân con của Thiên Triều).
  Future<List<TimeSlot>> freeOnAnyCourt(List<DateTime> dates) async {
    final courts = (await facility.getTimeSlots(thienTrieu.id, Sport.badminton, dates.first)).map((s) => s.courtName).toSet();
    for (final court in courts) {
      try {
        return await freeAt(dates, court);
      } on StateError {
        // sân này không có giờ trống đủ mọi ngày: thử sân sau
      }
    }
    throw StateError('không sân nào có giờ trống đủ ${dates.length} ngày');
  }

  /// Bấm ô sân con [court] (bật / tắt sân đó).
  Future<void> tapCourt(WidgetTester tester, String court) async {
    final chip = find.descendant(of: find.byType(CourtSelector), matching: find.text(court));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip.hitTestable());
    await tester.pumpAndSettle();
  }

  /// Bấm ô giờ của [slot] trong lưới (áp cho mọi sân đang sáng).
  Future<void> tapTime(WidgetTester tester, TimeSlot slot) async {
    final time = find.text(Formatters.timeRange(slot.start, slot.end));
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    await tester.tap(time.hitTestable());
    await tester.pumpAndSettle();
  }

  /// Chỉ để [slot.courtName] sáng (sân mặc định là Sân 1) rồi bấm khung [slot].
  Future<void> pickSlot(WidgetTester tester, TimeSlot slot) async {
    if (slot.courtName != 'Sân 1') {
      await tapCourt(tester, slot.courtName);
      await tapCourt(tester, 'Sân 1');
    }
    await tapTime(tester, slot);
  }

  /// Cùng giờ trên sân [court] còn trống [weeks] tuần liên tiếp kể từ [day].
  Future<List<TimeSlot>> weeklyFree(DateTime day, String court, {int weeks = 4}) =>
      freeAt([for (var i = 0; i < weeks; i++) DateTime(day.year, day.month, day.day + 7 * i)], court);

  testWidgets('Chi tiết sân: lặp 2 thứ × 1 khung × 4 tuần = 8 lượt → tách 2 gói, thanh toán 1 lần', (tester) async {
    await pump(tester, FacilityDetailScreen(facility: thienTrieu, initialSport: Sport.badminton));
    expect(find.text(BookingStrings.discountBadge(10)), findsOneWidget);

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await tester.tap(find.text(Formatters.dayMonth(tomorrow)));
    await tester.pumpAndSettle();

    // Lặp vào thứ của ngày mai + thứ của ngày kia; tìm sân con + giờ còn trống đủ 8 ngày.
    final dates = RecurringPlan.datesFor(tomorrow, {tomorrow.weekday, tomorrow.weekday % 7 + 1}, 4);
    final slots = (await tester.runAsync(() => freeOnAnyCourt(dates)))!;
    await pickSlot(tester, slots.first);

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).hitTestable());
    await tester.pumpAndSettle();
    // Mặc định lặp đúng thứ của ngày bắt đầu: 1 × 1 × 4 = 4 lượt.
    expect(find.text(BookingStrings.recurringCount(1, 1, 1, 4, 4)), findsOneWidget);

    final nextDay = find.widgetWithText(ChoiceChip, BookingStrings.weekdayShort[tomorrow.weekday % 7]);
    await tester.ensureVisible(nextDay);
    await tester.pumpAndSettle();
    await tester.tap(nextDay.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.recurringCount(2, 1, 1, 4, 8)), findsOneWidget);

    for (final s in slots) {
      expect(
        find.text('${Formatters.weekdayDayMonth(s.start)} • ${s.courtName} • ${Formatters.timeRange(s.start, s.end)}'),
        findsOneWidget,
      );
    }
    final original = slots.fold(0, (sum, s) => sum + s.price);
    expect(find.text(Formatters.vnd(RecurringBookingRules.discounted(original, 10))), findsOneWidget);
    expect(find.textContaining(BookingStrings.packageTitle(8), findRichText: true), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, FacilityStrings.bookNow));
    await tester.pumpAndSettle();
    expect(find.byType(BookingCheckoutScreen), findsOneWidget);
    expect(find.text(BookingStrings.discountRow(10)), findsOneWidget);
    expect(find.text(SplitPaymentStrings.option), findsNothing);

    await tester.tap(find.textContaining('Xác nhận thanh toán'));
    await tester.pumpAndSettle();
    final paid = slots.fold(0, (sum, s) => sum + RecurringBookingRules.discounted(s.price, 10));
    expect(find.text(BookingStrings.packagesBooked(8, 2, paid)), findsOneWidget);

    final mine = (await tester.runAsync(booking.getMyBookings))!.where((b) => b.isRecurring).toList();
    expect(mine, hasLength(8));
    expect(mine.map((b) => b.recurringGroupId).toSet(), hasLength(2)); // mỗi thứ một gói
  });

  testWidgets('Chi tiết sân: bật thêm sân thứ 2 thì khóa đặt lặp lại; tắt về 1 sân thì mở lại; đổi ngày thì bỏ khung cũ', (tester) async {
    await pump(tester, FacilityDetailScreen(facility: thienTrieu, initialSport: Sport.badminton));
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await tester.tap(find.text(Formatters.dayMonth(tomorrow)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).hitTestable());
    await tester.pumpAndSettle();

    final day = (await tester.runAsync(() => facility.getTimeSlots(thienTrieu.id, Sport.badminton, tomorrow)))!;
    final first = day.firstWhere((s) => s.courtName == 'Sân 1'); // sân mặc định

    await tapTime(tester, first);
    expect(find.text(BookingStrings.recurringCount(1, 1, 1, 4, 4)), findsOneWidget);
    // Bật thêm Sân 2: cùng khung được chọn luôn cho Sân 2; đặt lặp lại bị tắt và khóa (vẫn đặt thường).
    await tapCourt(tester, 'Sân 2');
    expect(find.text(BookingStrings.recurringLockedMultiCourt), findsOneWidget);
    expect(find.text(BookingStrings.recurringOneCourtOnly), findsOneWidget);
    var toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(2)), findsOneWidget);

    // Tắt Sân 2: về 1 sân → bỏ khung của Sân 2, mở khóa, bật lại được.
    await tapCourt(tester, 'Sân 2');
    expect(find.textContaining(FacilityStrings.selectedSlotCount(1)), findsOneWidget);
    toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged, isNotNull);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.recurringCount(1, 1, 1, 4, 4)), findsOneWidget);

    // Chọn khung ở ngày khác: bỏ các khung của ngày cũ, ngày mới thành ngày bắt đầu.
    final dayAfter = DateTime(now.year, now.month, now.day + 2);
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 2000), 3000);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Formatters.dayMonth(dayAfter)).hitTestable());
    await tester.pumpAndSettle();
    final later = (await tester.runAsync(() => facility.getTimeSlots(thienTrieu.id, Sport.badminton, dayAfter)))!
        .firstWhere((s) => s.courtName == 'Sân 1');
    await tapTime(tester, later);
    expect(find.text(BookingStrings.recurringOneDay), findsOneWidget);
    expect(find.text(BookingStrings.recurringCount(1, 1, 1, 4, 4)), findsOneWidget);
  });

  testWidgets('Chi tiết sân: 2 sân cùng sáng, bấm 1 khung là chọn cho cả 2 sân; bấm lại thì bỏ cả 2', (tester) async {
    await pump(tester, FacilityDetailScreen(facility: thienTrieu, initialSport: Sport.badminton));
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await tester.tap(find.text(Formatters.dayMonth(tomorrow)));
    await tester.pumpAndSettle();

    final day = (await tester.runAsync(() => facility.getTimeSlots(thienTrieu.id, Sport.badminton, tomorrow)))!;
    final a = day.where((s) => s.courtName == 'Sân 1').take(2).toList();
    final bookButton = find.widgetWithText(ElevatedButton, FacilityStrings.bookNow);

    // Sân 1 sáng sẵn; chọn slot 1-2 rồi bật thêm Sân 2 → Sân 2 cũng được chọn slot 1-2.
    await tapTime(tester, a[0]);
    await tapTime(tester, a[1]);
    await tapCourt(tester, 'Sân 2');
    expect(find.text(BookingStrings.multiCourtHint(2)), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CourtSelector), matching: find.text(FacilityStrings.courtSelectedCount(2))),
      findsNWidgets(2),
    );
    expect(find.textContaining(FacilityStrings.selectedSlotCount(4)), findsOneWidget);
    expect(tester.widget<ElevatedButton>(bookButton).onPressed, isNotNull);

    // Bấm lại slot 1 (ô gộp 2 sân): bỏ slot 1 ở cả 2 sân → vẫn cùng khung giờ, đặt được.
    await tapTime(tester, a[0]);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(2)), findsOneWidget);
    expect(tester.widget<ElevatedButton>(bookButton).onPressed, isNotNull);

    // Bấm thêm slot 3: chọn cho cả 2 sân.
    final third = day.where((s) => s.courtName == 'Sân 1').elementAt(2);
    await tapTime(tester, third);
    expect(find.textContaining(FacilityStrings.selectedSlotCount(4)), findsOneWidget);
  });

  testWidgets('Chi tiết sân: bật đặt cố định khi chưa chọn buổi mẫu: nhắc cách chọn, nút đặt khóa', (tester) async {
    await pump(tester, FacilityDetailScreen(facility: thienTrieu, initialSport: Sport.badminton));
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).hitTestable());
    await tester.pumpAndSettle();
    // Chưa chọn khung nào: nhắc cách chọn buổi mẫu, nút đặt khóa.
    expect(find.text(BookingStrings.recurringPatternHint), findsOneWidget);
    final bookButton = find.widgetWithText(ElevatedButton, FacilityStrings.bookNow);
    expect(tester.widget<ElevatedButton>(bookButton).onPressed, isNull);
  });

  testWidgets('Lịch đặt: các buổi gom thành một gói; hủy là hủy cả gói, hoàn 100%', (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 5);
    final weekly = (await tester.runAsync(() => weeklyFree(start, 'Sân 1')))!;
    final hold = (await tester.runAsync(() => facility.holdSlots(weekly)))!;
    final created = (await tester.runAsync(() => booking.createBooking(
          hold: hold,
          paymentType: BookingPaymentType.full,
          facilityName: thienTrieu.name,
          sportLabel: 'Cầu Lông',
          location: 'Quận 7',
          schedule: '',
          recurring: true,
          discountPercent: 10,
        )))!;
    final paid = created.fold(0, (sum, b) => sum + b.amountPaid);

    await pump(tester, const MyBookingsScreen());
    expect(find.text(BookingStrings.packageTitle(4)), findsOneWidget);
    for (final b in created) {
      expect(find.text(b.schedule), findsOneWidget);
    }

    await tester.ensureVisible(find.text(BookingStrings.cancelPackage));
    await tester.tap(find.text(BookingStrings.cancelPackage));
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.confirmCancelPackage(4, paid)), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, BookingStrings.cancelPackage));
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.packageCancelled(paid)), findsOneWidget);
    expect(find.text(BookingStrings.cancelPackage), findsNothing);
    expect(find.text(BookingStrings.refunded(paid)), findsOneWidget);
  });
  testWidgets('Bố cục gói cố định: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 5);
    final weekly = (await tester.runAsync(() => weeklyFree(start, 'Sân 1')))!;
    final hold = (await tester.runAsync(() => facility.holdSlots(weekly)))!;
    await tester.runAsync(() => booking.createBooking(
          hold: hold,
          paymentType: BookingPaymentType.full,
          facilityName: 'Trung Tâm Thể Thao Cầu Lông Thiên Triều Quận 7 Cơ Sở 2',
          sportLabel: 'Cầu Lông',
          location: '25 Đường số 17, P. Tân Thuận Đông, Quận 7, TP. Hồ Chí Minh',
          schedule: '',
          recurring: true,
          discountPercent: 10,
        ));
    final plan = RecurringPlan([
      RecurringSession(date: weekly[0].start, slots: [weekly[0]]),
      RecurringSession(date: weekly[1].start, issue: RecurringIssue.taken),
      RecurringSession(date: weekly[2].start, issue: RecurringIssue.notOpen),
      RecurringSession(date: weekly[3].start, slots: [weekly[3]]),
    ]);

    final problems = <String>[
      ...await collectLayoutProblems(
        tester,
        'Chi tiết sân (bật đặt cố định)',
        () => FacilityDetailScreen(facility: thienTrieu, initialSport: Sport.badminton),
        interact: (tester) async {
          await tester.ensureVisible(find.byType(Switch));
          await settleFrames(tester);
          await tester.tap(find.byType(Switch).hitTestable());
          await settleFrames(tester);
        },
      ),
      ...await collectLayoutProblems(
        tester,
        'Mục đặt cố định (tuần bị kẹt)',
        () => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const RecurringDiscountBadge(percent: 50),
                const SizedBox(height: 8),
                RecurringBookingSection(
                  enabled: true,
                  onToggle: (_) {},
                  discountPercent: 50,
                  patternValid: true,
                  startDate: weekly[0].start,
                  slotsPerDay: 3,
                  weekdays: const {1, 2, 3, 4, 5, 6, 7},
                  onWeekdayToggled: (_) {},
                  weeks: 8,
                  onWeeksChanged: (_) {},
                  plan: plan,
                  planning: false,
                ),
              ],
            ),
          ),
        ),
      ),
      ...await collectLayoutProblems(
        tester,
        'Thanh toán gói cố định',
        () => const BookingCheckoutScreen(
          sport: 'Bóng Đá • Sân 7 người',
          courtName: 'Trung Tâm Thể Thao Phú Thọ Quận 11 • Sân số 12',
          location: '1 Lữ Gia, Phường 15, Quận 11, TP. Hồ Chí Minh',
          dateTime: 'Thứ 3 • Sân 12 • 18:00 - 20:00\n24/11, 01/12, 08/12, 15/12, 22/12, 29/12, 05/01, 12/01',
          totalAmount: 12500000,
          recurring: RecurringCheckout(
            sessions: 56,
            discountPercent: 50,
            summary: 'T2, T3, T4, T5, T6, T7, CN • Sân số 12 • 08:00 - 10:00, 18:00 - 20:00',
            packages: [],
          ),
        ),
      ),
      ...await collectLayoutProblems(tester, 'Lịch đặt có gói', () => const MyBookingsScreen()),
      ...await collectLayoutProblems(
        tester,
        'Ô chọn sân có dấu đã chọn',
        () => Scaffold(
          body: CourtSelector(
            courts: const ['Sân 1', 'Sân Cactus Đôi Trong Nhà Số 12', 'Sân lucky'],
            selected: 'Sân 1',
            freeSlots: const {'Sân 1': 8, 'Sân Cactus Đôi Trong Nhà Số 12': 0},
            pickedSlots: const {'Sân 1': 12, 'Sân Cactus Đôi Trong Nhà Số 12': 3},
            onSelected: (_) {},
          ),
        ),
      ),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
