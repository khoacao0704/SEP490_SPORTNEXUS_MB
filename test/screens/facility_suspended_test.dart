import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/facility_strings.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/facility_repository.dart';
import 'package:test1/screens/lfg/create_lfg_match_screen.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/core/strings/owner_finance_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/owner_facility.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/facility/facility_detail_screen.dart';
import 'package:test1/screens/owner/owner_facilities_screen.dart';
import 'package:test1/screens/owner/owner_facility_detail_screen.dart';
import 'package:test1/screens/owner/owner_finance_screen.dart';
import 'package:test1/widgets/booking/recurring_booking_section.dart';

import '../helpers/layout_check.dart';

Facility _suspended(Facility f) => Facility(
      id: f.id,
      name: f.name,
      address: f.address,
      city: f.city,
      district: f.district,
      location: f.location,
      offerings: f.offerings,
      rating: f.rating,
      reviewCount: f.reviewCount,
      imageUrls: f.imageUrls,
      amenities: f.amenities,
      rules: f.rules,
      openTime: f.openTime,
      closeTime: f.closeTime,
      phone: f.phone,
      description: f.description,
      amenityIcons: f.amenityIcons,
      courtDetails: f.courtDetails,
      recurringDiscountPercent: f.recurringDiscountPercent,
      isSuspended: true,
    );

/// BE trả chi tiết cơ sở kèm isSuspended = true (hệ thống tự tạm ngưng vì quá hạn phản hồi khiếu nại).
class _SuspendedFacilityRepository extends MockFacilityRepository {
  _SuspendedFacilityRepository() : super(latency: Duration.zero);

  @override
  Future<Facility> getFacility(String facilityId) async => _suspended(await super.getFacility(facilityId));
}

const _suspendedOwnerId = 'f-hcm-thientrieu';

/// Một cơ sở đã duyệt của chủ sân đang bị tạm ngưng.
class _SuspendedOwnerRepository extends MockOwnerRepository {
  _SuspendedOwnerRepository() : super(latency: Duration.zero);

  OwnerFacility _mark(OwnerFacility f) => f.id == _suspendedOwnerId ? f.copyWith(isSuspended: true) : f;

  @override
  Future<List<OwnerFacility>> getOwnerFacilities() async => (await super.getOwnerFacilities()).map(_mark).toList();

  @override
  Future<OwnerFacility> getOwnerFacility(String facilityId) async => _mark(await super.getOwnerFacility(facilityId));

  @override
  Future<List<Facility>> getMyFacilities() async =>
      (await getOwnerFacilities()).where((f) => f.isApproved).map((f) => f.toFacility()).toList();
}

void main() {
  Future<void> pump(WidgetTester tester, Widget home, {Size size = const Size(1080, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  group('Người chơi: sân tạm ngưng', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppRepositories.facility = _SuspendedFacilityRepository();
    });

    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');

    testWidgets('vẫn hiện sân, ca trống xám; bấm ca báo "Sân đang tạm ngưng do có khiếu nại", không chọn được', (tester) async {
      await pump(tester, FacilityDetailScreen(facility: facility, initialSport: Sport.badminton));

      expect(find.text(FacilityStrings.suspendedNotice), findsOneWidget);
      expect(find.byType(RecurringBookingSection), findsNothing);

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      await tester.tap(find.text(Formatters.dayMonth(tomorrow)));
      await tester.pumpAndSettle();

      // Không còn ca nào "Còn trống"; ca trống ghi "Tạm ngưng".
      expect(find.text(FacilityStrings.available), findsNothing);
      final suspendedTiles = find.text(FacilityStrings.suspendedSlot);
      expect(suspendedTiles, findsWidgets);

      await tester.ensureVisible(suspendedTiles.first);
      await tester.pumpAndSettle();
      await tester.tap(suspendedTiles.hitTestable().first);
      await tester.pump();
      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text(FacilityStrings.suspendedMessage)),
        findsOneWidget,
      );

      // Không có ca nào được chọn, nút đặt sân khóa.
      expect(find.textContaining(FacilityStrings.selectedSlotCount(1)), findsNothing);
      final bookButton = find.widgetWithText(ElevatedButton, FacilityStrings.bookNow);
      expect(tester.widget<ElevatedButton>(bookButton).onPressed, isNull);
    });

    testWidgets('giữ ca ở sân tạm ngưng (lối Trợ lý AI / tạo kèo dùng chung) bị chặn', (tester) async {
      final repo = _SuspendedFacilityRepository();
      final err = await tester.runAsync(() async {
        final day = DateTime.now().add(const Duration(days: 1));
        final slot = (await repo.getTimeSlots(facility.id, Sport.badminton, day)).firstWhere((s) => s.isAvailable);
        try {
          await repo.holdSlots([slot]);
          return null;
        } on FacilityException catch (e) {
          return e.message;
        }
      });
      expect(err, FacilityStrings.suspendedMessage);
    });

    testWidgets('tạo kèo: sân tạm ngưng vẫn chọn xem được, có nhãn + khung báo, ca xám, bấm ca báo lý do', (tester) async {
      AppRepositories.lfgFacility = AppRepositories.facility;
      final wallet = MockWalletRepository(latency: Duration.zero);
      final review = MockReviewRepository(latency: Duration.zero);
      AppRepositories.wallet = AppRepositories.paymentWallet = wallet;
      AppRepositories.review = review;
      AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
      AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
      await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');

      await pump(tester, const CreateLfgMatchScreen(), size: const Size(1600, 3200));
      await tester.tap(find.text('Sân Cầu Lông Thiên Triều'));
      await tester.pumpAndSettle();

      expect(find.text(FacilityStrings.suspendedBar), findsOneWidget);
      expect(find.text(FacilityStrings.suspendedNotice), findsOneWidget);
      final tiles = find.text(FacilityStrings.suspendedSlot);
      expect(tiles, findsWidgets);
      await tester.ensureVisible(tiles.first);
      await tester.pumpAndSettle();
      await tester.tap(tiles.hitTestable().first);
      await tester.pump();
      expect(find.descendant(of: find.byType(SnackBar), matching: find.text(FacilityStrings.suspendedMessage)), findsOneWidget);
      expect(find.text(LfgStrings.continueToPay), findsNothing);

      await expectNoOverflow(
        tester,
        'Tạo kèo: sân tạm ngưng',
        () => const CreateLfgMatchScreen(),
        interact: (tester) async {
          await tester.tap(find.text('Sân Cầu Lông Thiên Triều'));
          await settleFrames(tester);
        },
      );
    });

    testWidgets('chi tiết sân tạm ngưng không tràn chữ ở mọi cỡ máy / cỡ chữ', (tester) async {
      await expectNoOverflow(
        tester,
        'Chi tiết sân tạm ngưng',
        () => FacilityDetailScreen(facility: facility, initialSport: Sport.badminton),
      );
    });
  });

  group('Chủ sân: cơ sở tạm ngưng', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final auth = MockAuthRepository(latency: Duration.zero);
      AppRepositories.auth = auth;
      AppRepositories.owner = _SuspendedOwnerRepository();
      await auth.login('owner@sportnexus.vn', 'Owner@123');
    });

    testWidgets('danh sách cơ sở hiện thẻ "Tạm ngưng nhận đặt"; chi tiết hiện cảnh báo', (tester) async {
      await pump(tester, OwnerFacilitiesScreen(onChanged: () {}), size: const Size(1600, 4000));
      expect(find.text(OwnerFacilityStrings.statusSuspended), findsOneWidget);

      final f = await AppRepositories.owner.getOwnerFacility(_suspendedOwnerId);
      await pump(tester, OwnerFacilityDetailScreen(facility: f), size: const Size(1600, 4000));
      expect(find.text(OwnerFacilityStrings.suspendedBanner), findsOneWidget);
    });

    testWidgets('bấm Đổi Điểm ra tiền thì bị chặn, báo tên cơ sở đang tạm ngưng', (tester) async {
      await pump(tester, const OwnerFinanceScreen(), size: const Size(1600, 4000));
      final name = (await AppRepositories.owner.getOwnerFacility(_suspendedOwnerId)).profile.name;

      await tester.tap(find.text(OwnerFinanceStrings.withdraw));
      await tester.pumpAndSettle();
      expect(find.text(OwnerFinanceStrings.withdrawBlockedTitle), findsOneWidget);
      expect(find.text(OwnerFinanceStrings.withdrawSuspended([name])), findsOneWidget);
    });

    testWidgets('cảnh báo tạm ngưng ở chi tiết cơ sở không tràn chữ', (tester) async {
      final f = await AppRepositories.owner.getOwnerFacility(_suspendedOwnerId);
      await expectNoOverflow(tester, 'Chủ sân: cơ sở tạm ngưng', () => OwnerFacilityDetailScreen(facility: f));
    });
  });
}
