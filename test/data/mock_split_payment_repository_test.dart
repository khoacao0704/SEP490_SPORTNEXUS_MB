import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/split_payment_rules.dart';
import 'package:test1/core/strings/split_payment_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/split_payment_repository.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/split_payment.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';

void main() {
  late DateTime clock;
  late MockWalletRepository wallet;
  late MockFacilityRepository facility;
  late MockSplitPaymentRepository repo;
  late MockBookingRepository bookings;

  // Cơ sở 1 sân để dễ thấy khung giờ bị giữ.
  const testFacility = Facility(
    id: 'f-test',
    name: 'Sân Test',
    address: '1 Test',
    city: 'Hồ Chí Minh',
    district: 'Quận 1',
    location: GeoPoint(10.77, 106.70),
    offerings: [SportOffering(sport: Sport.badminton, courtCount: 1, priceFrom: 130000)],
    rating: 4.5,
    reviewCount: 1,
    imageUrls: [],
    openTime: '06:00',
    closeTime: '22:00',
    phone: '0900',
  );

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  Matcher error(String message) =>
      throwsA(isA<SplitPaymentException>().having((e) => e.message, 'message', message));

  Future<TimeSlot> freeSlot() async {
    final slots = await facility.getTimeSlots('f-test', Sport.badminton, clock.add(const Duration(days: 1)));
    return slots.firstWhere((s) => !s.isFull);
  }

  Future<SplitPayment> createSplit(int parts) async {
    final slot = await freeSlot();
    final hold = await facility.holdSlots([slot]);
    return repo.create(
      hold: hold,
      parts: parts,
      facilityName: 'Sân Test',
      sportLabel: 'Cầu Lông',
      location: 'Quận 1, Hồ Chí Minh',
      schedule: 'Thứ 5, 15/10 • 08:00 - 09:00',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 10, 0);
    wallet = MockWalletRepository(latency: Duration.zero, now: () => clock);
    facility = MockFacilityRepository(latency: Duration.zero, now: () => clock, facilities: const [testFacility]);
    bookings = MockBookingRepository(facility: facility, latency: Duration.zero, now: () => clock, wallet: wallet);
    repo = MockSplitPaymentRepository(
      facility: facility,
      latency: Duration.zero,
      now: () => clock,
      wallet: wallet,
      bookings: bookings,
    );
    await loginAs('player@sportnexus.vn');
  });

  test('chia phần: làm tròn lên 1.000đ, tổng các phần đúng bằng tiền sân', () {
    expect(SplitPaymentRules.allowedParts, [2, 4]);
    expect(SplitPaymentRules.shareAmount(130000, 4), 33000);
    expect(SplitPaymentRules.bookerAmount(130000, 4), 31000);
    expect(SplitPaymentRules.bookerAmount(130000, 4) + 3 * SplitPaymentRules.shareAmount(130000, 4), 130000);
    expect(SplitPaymentRules.shareAmount(130000, 2), 65000);
  });

  test('người đặt trả 1/N, khung giờ được giữ 30 phút', () async {
    final before = await wallet.getBalance();
    final split = await createSplit(4);

    expect(split.parts, 4);
    expect(split.shares.first.isPaid, isTrue);
    expect(split.paidCount, 1);
    expect(split.code, hasLength(6));
    expect(split.expiresAt, clock.add(const Duration(minutes: 30)));
    expect(await wallet.getBalance(), before - split.shares.first.amount);

    // Sau 15 phút (quá 10 phút giữ chỗ thường) khung giờ vẫn được giữ.
    clock = clock.add(const Duration(minutes: 15));
    final slot = (await facility.getTimeSlots('f-test', Sport.badminton, clock.add(const Duration(days: 1))))
        .firstWhere((s) => s.id == split.slots.first.id);
    expect(slot.isFull, isTrue);
  });

  test('chỉ chia được 2 hoặc 4 phần', () async {
    expect(() => createSplit(3), error(SplitPaymentStrings.invalidParts));
  });

  test('người nhận link trả đủ thì đặt sân thành công, có vé trong Lịch Đặt', () async {
    final split = await createSplit(2);

    expect(() => repo.payShare(split.code), error(SplitPaymentStrings.isBooker));

    await loginAs('restricted@sportnexus.vn'); // Fair Play 25 vẫn trả được: không xét Fair Play
    final paid = await repo.payShare(split.code.toLowerCase());
    expect(paid.status(clock), SplitStatus.completed);
    expect(paid.shares.last.payerName, 'Trần Văn Bình');
    expect(() => repo.payShare(split.code), error(SplitPaymentStrings.alreadyPaid));
    await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
    expect(() => repo.payShare(split.code), error(SplitPaymentStrings.fullyPaid));
    await loginAs('player@sportnexus.vn');

    // Đủ tiền thì có lần đặt sân (vé QR riêng), hiện cho cả người đặt lẫn người góp.
    final booking = (await bookings.getMyBookings()).firstWhere((b) => b.id == split.bookingId);
    expect(booking.paymentType, BookingPaymentType.split);
    expect(booking.amountPaid, split.totalAmount);
    expect(booking.ticketCode, 'SPN-BK-${split.bookingId}');
    expect((await repo.getMine()).single.id, split.id);
  });

  test('mỗi tài khoản chỉ trả một phần', () async {
    final split = await createSplit(4);
    await loginAs('restricted@sportnexus.vn');
    await repo.payShare(split.code);
    expect(() => repo.payShare(split.code), error(SplitPaymentStrings.alreadyPaid));
  });

  test('hết 30 phút chưa đủ: hủy, hoàn đủ cho người đã trả, nhả khung giờ', () async {
    final start = await wallet.getBalance();
    final split = await createSplit(4);
    await repo.simulateFriendPaid(split.id); // bạn bè trả ngoài ví này
    await loginAs('restricted@sportnexus.vn');
    await repo.payShare(split.code);
    await loginAs('player@sportnexus.vn');

    clock = clock.add(const Duration(minutes: 31));
    final expired = await repo.getById(split.id);
    expect(expired.status(clock), SplitStatus.expired);
    expect(expired.refunded, isTrue);
    // Ví giả lập dùng chung: phần của người đặt và của "restricted" đều được hoàn.
    expect(await wallet.getBalance(), start);
    await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
    expect(() => repo.payShare(split.code), error(SplitPaymentStrings.expired));

    final slot = (await facility.getTimeSlots('f-test', Sport.badminton, clock.add(const Duration(days: 1))))
        .firstWhere((s) => s.id == split.slots.first.id);
    expect(slot.isFull, isFalse);
  });

  test('mã không tồn tại', () async {
    expect(() => repo.findByCode('ZZZZZZ'), error(SplitPaymentStrings.notFound));
  });
}
