import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_booking_data.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/owner_booking.dart';

void main() {
  // 15:00 → đơn mẫu: 14–16h đang chơi (kèo LFG), 15h vãng lai, 16h đã thanh toán, 17–19h chờ góp tiền.
  final now = DateTime(2026, 10, 15, 15, 0);
  const tt = MockOwnerBookingData.thienTrieu;
  const hl = MockOwnerBookingData.hoaLu;
  late MockOwnerRepository repo;

  Future<void> loginAs(String email, String password) async {
    SharedPreferences.setMockInitialValues({});
    await MockAuthRepository(latency: Duration.zero).login(email, password);
  }

  setUp(() async {
    await loginAs('owner@sportnexus.vn', 'Owner@123');
    repo = MockOwnerRepository(latency: Duration.zero, now: () => now);
  });

  Matcher throwsOwner(String message) =>
      throwsA(isA<OwnerException>().having((e) => e.message, 'message', message));

  String slot(String court, int hour, {DateTime? day}) => MockOwnerBookingData.slotId(court, day ?? now, hour);

  test('danh sách đơn theo ngày, trạng thái, tìm khách; có số liệu tổng', () async {
    final today = await repo.getBookings(facilityId: tt, date: now);
    expect(today.items.map((b) => b.id), containsAll(['OW1001', 'OW1002', 'OW1003', 'WI100']));
    expect(today.items.any((b) => b.id == 'OW1006'), isFalse, reason: 'đơn ngày mai');
    expect(today.paidCount, 2);
    expect(today.checkedInCount, 1);

    final paid = await repo.getBookings(facilityId: tt, date: now, status: OwnerBookingStatus.paid);
    expect(paid.items.map((b) => b.id).toSet(), {'OW1001', 'WI100'});

    final found = await repo.getBookings(facilityId: tt, from: now, to: now.add(const Duration(days: 1)), search: 'thu');
    expect(found.items.single.customerName, 'Hồ Thị Thu');

    final hoaLu = await repo.getBookings(facilityId: hl, date: now);
    expect(hoaLu.items.single.id, 'OW1004');
  });

  test('lưới ca: trạng thái ô theo đơn và ca khóa', () async {
    final day = await repo.getDaySchedule(tt, now);
    final byId = {for (final c in day.courts) for (final s in c.slots) s.id: s};
    expect(byId[slot('c-tt-2', 14)]!.state, SlotCellState.checkedIn);
    expect(byId[slot('c-tt-1', 15)]!.state, SlotCellState.paid);
    expect(byId[slot('c-tt-1', 15)]!.isWalkIn, isTrue);
    expect(byId[slot('c-tt-1', 17)]!.state, SlotCellState.pending);
    expect(byId[slot('c-tt-3', 18)]!.state, SlotCellState.maintenance);
    expect(byId[slot('c-tt-3', 10)]!.state, SlotCellState.past);
    expect(byId[slot('c-tt-3', 20)]!.state, SlotCellState.available);
    expect(day.lockedSlots, 1);
  });

  test('khách vãng lai: nhiều ca liên tiếp, ca đã có người thì báo lỗi', () async {
    await repo.createWalkIn(WalkInRequest(
      courtSlotId: slot('c-tt-2', 19),
      numberOfSlots: 2,
      customerName: 'Anh Tuấn',
      customerPhone: '0909000111',
      autoCheckIn: true,
    ));
    final created = (await repo.getBookings(facilityId: tt, search: 'Tuấn')).items.single;
    expect(created.isWalkIn, isTrue);
    expect(created.status, OwnerBookingStatus.checkedIn);
    expect(created.totalAmount, 160000);
    expect(created.end.difference(created.start), const Duration(hours: 2));

    await expectLater(
      repo.createWalkIn(WalkInRequest(courtSlotIds: [slot('c-tt-2', 20)], customerName: 'Khách khác')),
      throwsOwner('Ca 20:00 – 21:00 không còn trống.'),
    );
    await expectLater(
      repo.createWalkIn(WalkInRequest(courtSlotIds: [slot('c-tt-3', 21)], customerName: '  ')),
      throwsOwner(OwnerStrings.walkInNameRequired),
    );
  });

  test('check-in thủ công chỉ cho đơn đã thanh toán; kết thúc ca sớm khi đang chơi', () async {
    await repo.checkInBooking('OW1001');
    final b = await repo.getBooking('OW1001');
    expect(b.status, OwnerBookingStatus.checkedIn);
    expect(b.participants.every((p) => p.isCheckedIn), isTrue);
    await expectLater(repo.checkInBooking('OW1001'), throwsA(isA<OwnerException>()));
    await expectLater(repo.checkInBooking('OW1003'), throwsA(isA<OwnerException>()), reason: 'đơn chờ góp tiền');

    expect((await repo.getBooking('OW1002')).canEndEarly(now), isTrue);
    await repo.endBooking('OW1002');
    expect((await repo.getBooking('OW1002')).status, 'COMPLETED');
  });

  test('khóa / mở / đổi giá ca trống', () async {
    final id = slot('c-tt-3', 21);
    await repo.setSlotLocked(id, locked: true);
    expect((await repo.getDaySchedule(tt, now)).lockedSlots, 2);
    await repo.setSlotLocked(id, locked: false);
    await repo.setSlotPrice(id, 120000);
    final day = await repo.getDaySchedule(tt, now);
    expect(day.courts.expand((c) => c.slots).firstWhere((s) => s.id == id).price, 120000);
    await expectLater(repo.setSlotPrice(id, 500), throwsOwner(OwnerStrings.priceTooLow));
    await expectLater(repo.setSlotLocked(slot('c-tt-3', 16), locked: true), throwsA(isA<OwnerException>()));
  });

  test('quét mã vé đúng cơ sở thì check-in; mã lạ hoặc cơ sở khác báo lỗi', () async {
    final r = await repo.scanQr(facilityId: tt, qrCode: MockOwnerBookingData.ticketCode('OW1001').toLowerCase());
    expect(r.customerName, 'Nguyễn Minh Anh');
    expect((await repo.getBooking('OW1001')).status, OwnerBookingStatus.checkedIn);
    await expectLater(repo.scanQr(facilityId: tt, qrCode: 'XYZ'), throwsA(isA<OwnerException>()));
    await expectLater(
      repo.scanQr(facilityId: hl, qrCode: MockOwnerBookingData.ticketCode('OW1006')),
      throwsA(isA<OwnerException>()),
    );
  });

  test('chủ sân hủy: dưới 48h phạt 20% + −10 FP; vãng lai không phạt; khóa ca sau hủy', () async {
    final late = await repo.cancelBooking('OW1001', reasonCode: 1, reason: 'Sân hỏng đèn', lockSlot: true);
    expect(late.penaltyAmount, 16000);
    expect(late.fairPlayPenalty, 10);
    final cancelled = await repo.getBooking('OW1001');
    expect(cancelled.status, OwnerBookingStatus.cancelled);
    expect(cancelled.cancellation!.reason, 'Sân hỏng đèn');
    final day = await repo.getDaySchedule(tt, now);
    expect(day.courts.expand((c) => c.slots).firstWhere((s) => s.id == slot('c-tt-3', 16)).state, SlotCellState.maintenance);

    final walkIn = await repo.cancelBooking('WI100');
    expect(walkIn.penaltyAmount, 0);
    expect(walkIn.fairPlayPenalty, 0);
    await expectLater(repo.cancelBooking('OW1002'), throwsA(isA<OwnerException>()), reason: 'đã check-in');
  });

  test('tài khoản không sở hữu cơ sở thì không xem được đơn', () async {
    await loginAs('player@sportnexus.vn', 'Player@123');
    final other = MockOwnerRepository(latency: Duration.zero, now: () => now);
    expect(await other.getMyFacilities(), isEmpty);
    await expectLater(other.getBookings(facilityId: tt), throwsA(isA<OwnerException>()));
  });
}
