import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/court_session.dart';

void main() {
  final now = DateTime(2026, 10, 15, 15, 0);
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

  test('chủ sân thấy các cơ sở của mình và lượt sân trong ngày', () async {
    final facilities = await repo.getMyFacilities();
    expect(facilities.map((f) => f.id), ['f-hcm-thientrieu', 'f-hcm-hoalu']);

    final today = await repo.getSessions(day: now);
    expect(today, hasLength(6));
    expect(today.first.start.isBefore(today.last.start), isTrue);

    final hoaLu = await repo.getSessions(day: now, facilityId: 'f-hcm-hoalu');
    expect(hoaLu.every((s) => s.facilityId == 'f-hcm-hoalu'), isTrue);
    expect(hoaLu, hasLength(3));
  });

  test('trạng thái lượt sân tính theo giờ', () async {
    final byId = {for (final s in await repo.getSessions(day: now)) s.id: s};
    expect(byId['OW1001']!.status(now), SessionStatus.waitingCheckIn);
    expect(byId['LFGOW1']!.status(now), SessionStatus.playing);
    expect(byId['OW1003']!.isOverdueCheckOut(now), isTrue);
    expect(byId['OW1004']!.status(now), SessionStatus.noShow);
    expect(byId['OW1005']!.status(now), SessionStatus.completed);
    expect(byId['LFGOW2']!.status(now), SessionStatus.upcoming);

    final lfg = byId['LFGOW1']!;
    expect(lfg.isAbsent(lfg.players.last, now), isTrue); // quá T+15 chưa check-in
    expect(byId['OW1001']!.remainingToCollect, 120000); // cọc 1/4 của 160.000
  });

  test('tra mã QR không phân biệt hoa thường; mã lạ báo lỗi', () async {
    final found = await repo.lookupTicket(' spn-bk-ow1001 ');
    expect(found.player.name, 'Nguyễn Minh Anh');
    expect(found.session.id, 'OW1001');

    final lfg = await repo.lookupTicket('SPN-LFG-LFGOW1-u-lfg-12');
    expect(lfg.player.name, 'Ngô Mỹ Linh');

    expect(() => repo.lookupTicket('SPN-BK-KHONGCO'), throwsOwner(OwnerStrings.ticketNotFound));
  });

  test('check-in người đầu tiên phải chỉ định sân con còn trống', () async {
    // Sân 2 đang có kèo LFG chơi trùng giờ.
    expect(await repo.getFreeCourts('OW1001'), ['Sân 1', 'Sân 3', 'Sân 4', 'Sân 5', 'Sân 6']);

    expect(
      () => repo.checkIn(sessionId: 'OW1001', userId: 'u-OW1001'),
      throwsOwner(OwnerStrings.chooseCourtRequired),
    );
    expect(
      () => repo.checkIn(sessionId: 'OW1001', userId: 'u-OW1001', court: 'Sân 2'),
      throwsOwner(OwnerStrings.courtBusy('Sân 2')),
    );

    final s = await repo.checkIn(sessionId: 'OW1001', userId: 'u-OW1001', court: 'Sân 3');
    expect(s.assignedCourt, 'Sân 3');
    expect(s.status(now), SessionStatus.playing);
    expect(
      () => repo.checkIn(sessionId: 'OW1001', userId: 'u-OW1001'),
      throwsOwner(OwnerStrings.alreadyCheckedIn),
    );
  });

  test('ngoài khung T−30 phút tới T+15 phút không check-in được', () async {
    final upcoming = await repo.getSession('LFGOW2');
    expect(
      () => repo.checkIn(sessionId: 'LFGOW2', userId: 'u-lfg-21', court: 'Sân 1'),
      throwsOwner(OwnerStrings.checkInNotOpen('17:30')),
    );
    expect(upcoming.checkInOpensAt, DateTime(2026, 10, 15, 17, 30));

    expect(
      () => repo.checkIn(sessionId: 'LFGOW1', userId: 'u-lfg-14'),
      throwsOwner(OwnerStrings.checkInClosed('14:45')),
    );
  });

  test('check-out một lần cho cả lượt sân, chỉ khi đã có người check-in', () async {
    expect(() => repo.checkOut('OW1004'), throwsOwner(OwnerStrings.checkOutNeedsCheckIn));

    final done = await repo.checkOut('LFGOW1');
    expect(done.status(now), SessionStatus.completed);
    expect(done.checkedOutAt, now);
    expect(() => repo.checkOut('LFGOW1'), throwsOwner(OwnerStrings.sessionCompleted));

    // Sân con được nhả sau check-out.
    expect(await repo.getFreeCourts('OW1001'), contains('Sân 2'));
  });

  test('lượt sân đã hủy không check-in được', () async {
    final tomorrow = DateTime(2026, 10, 16);
    final cancelled = (await repo.getSessions(day: tomorrow)).firstWhere((s) => s.id == 'OW1007');
    expect(cancelled.status(now), SessionStatus.cancelled);
    expect(
      () => repo.checkIn(sessionId: 'OW1007', userId: 'u-OW1007', court: 'Sân 1'),
      throwsOwner(OwnerStrings.sessionCancelled),
    );
  });

  test('tài khoản không sở hữu cơ sở thì không thấy gì', () async {
    await loginAs('player@sportnexus.vn', 'Player@123');
    expect(await repo.getMyFacilities(), isEmpty);
    expect(await repo.getSessions(day: now), isEmpty);
    expect(() => repo.lookupTicket('SPN-BK-OW1001'), throwsOwner(OwnerStrings.ticketNotFound));
  });
}
