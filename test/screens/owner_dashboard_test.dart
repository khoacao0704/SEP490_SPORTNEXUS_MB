import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_dashboard_strings.dart';
import 'package:test1/core/strings/owner_review_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/owner_dashboard.dart';
import 'package:test1/screens/owner/owner_overview_screen.dart';

import '../helpers/layout_check.dart';

void main() {
  final today = DateTime.now();
  final fixedNow = DateTime(today.year, today.month, today.day, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero, now: () => fixedNow);
    AppRepositories.ownerWallet =
        MockWalletRepository(latency: Duration.zero, keyPrefix: MockOwnerRepository.ownerWalletPrefix, initialBalance: 3200000);
    await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  group('so sánh kỳ (như periodCompare.js của Web)', () {
    test('tháng: kỳ này tới hôm nay, kỳ trước trọn tháng; quý tính đúng nhãn', () {
      final (cur, prev) = comparePeriods(CompareKind.month, DateTime(2026, 3, 10, 9));
      expect(cur.from, DateTime(2026, 3, 1));
      expect(cur.elapsed, 10);
      expect(cur.length, 31);
      expect(prev.from, DateTime(2026, 2, 1));
      expect(prev.to, DateTime(2026, 2, 28));
      expect(prev.label, 'Tháng 2/2026');
      final (q, pq) = comparePeriods(CompareKind.quarter, DateTime(2026, 1, 5));
      expect(q.label, 'Quý 1/2026');
      expect(pq.label, 'Quý 4/2025');
      expect(pq.length, 92);
    });

    test('cộng dồn và % thay đổi so với cùng mốc kỳ trước', () {
      final (cur, prev) = comparePeriods(CompareKind.month, DateTime(2026, 3, 3));
      final s = ComparisonSummary.of(
        cur,
        prev,
        [DayStat(date: DateTime(2026, 3, 1), revenue: 0, bookings: 3), DayStat(date: DateTime(2026, 3, 3), revenue: 0, bookings: 3)],
        [DayStat(date: DateTime(2026, 2, 2), revenue: 0, bookings: 4), DayStat(date: DateTime(2026, 2, 20), revenue: 0, bookings: 6)],
      );
      expect(s.current, [3, 3, 6]);
      expect(s.currentTotal, 6);
      expect(s.previousTotal, 10);
      expect(s.previousSameDay, 4);
      expect(s.change, 50);
    });
  });

  test('dashboard giả lập: số liệu khớp nhau, không tính ngày sau hôm nay, có khiếu nại mở', () async {
    final d = await AppRepositories.owner.getDashboard(
      facilityId: 'f-hcm-thientrieu',
      from: DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6)),
      to: DateTime(today.year, today.month, today.day + 3),
    );
    expect(d.revenueByDay, hasLength(7));
    expect(d.totalBookings, d.revenueByCourt.fold<int>(0, (s, c) => s + c.bookings));
    expect(d.totalRevenue, d.revenueByDay.fold<int>(0, (s, x) => s + x.revenue));
    expect(d.openReports, 2); // cp-01 chờ, cp-03 đã giải trình
    expect(d.reviewCount, 5);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 12000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Widget overview({VoidCallback? onScan}) => OwnerOverviewScreen(
        ownerName: 'Chủ Sân Demo',
        facilityId: 'f-hcm-thientrieu',
        revision: 0,
        facilitySelector: const Text('Thiên Triều'),
        onChanged: () {},
        onOpenSchedule: () {},
        onOpenScan: onScan,
        onOpenFacilities: () {},
      );

  testWidgets('tổng quan như Web: KPI, kỳ 7/30/90, doanh thu, việc cần xử lý, so sánh, sân, bảng', (tester) async {
    var scanned = 0;
    await pump(tester, overview(onScan: () => scanned++));
    expect(find.text(OwnerDashboardStrings.kpiBalance), findsOneWidget);
    expect(find.text('3.200.000 Điểm'), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.kpiBookings(30)), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.revenueChart), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.todoTitle), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.todoReports(2)), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.todoPending(1)), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.todoRejected(1)), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.compareTitle('tháng')), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.courtBookingsTitle), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.todayTitle), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.courtPerfTitle), findsOneWidget);
    expect(find.text(OwnerDashboardStrings.tableTitle), findsOneWidget);

    await tester.tap(find.text(OwnerDashboardStrings.periodDays(7)));
    await tester.pumpAndSettle();
    expect(find.text(OwnerDashboardStrings.kpiBookings(7)), findsOneWidget);

    await tester.tap(find.text(OwnerDashboardStrings.showTable));
    await tester.pumpAndSettle();
    expect(find.text(OwnerDashboardStrings.colDay), findsOneWidget);

    await tester.tap(find.text('Quý'));
    await tester.pumpAndSettle();
    expect(find.text(OwnerDashboardStrings.compareTitle('quý')), findsOneWidget);

    await tester.tap(find.text(OwnerDashboardStrings.todoReports(2)));
    await tester.pumpAndSettle();
    expect(find.text(OwnerComplaintStrings.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerDashboardStrings.scanNow).first);
    expect(scanned, 1);
  });

  testWidgets('bố cục Tổng quan: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final problems = await collectLayoutProblems(tester, 'Tổng quan', overview, interact: (t) async {
      // Cuộn từng đoạn tới cuối để dựng và kiểm mọi khối.
      for (var i = 0; i < 40; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -500), warnIfMissed: false);
        await t.pump();
      }
      await t.tap(find.text(OwnerDashboardStrings.periodDays(7)), warnIfMissed: false);
      await t.pump();
    });
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
