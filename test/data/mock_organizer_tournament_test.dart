import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/core/strings/owner_tournament_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_tournament_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/tournament_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/owner_finance.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/tournament.dart';

void main() {
  // Thứ 4, 15/10/2026 15:00.
  final now = DateTime(2026, 10, 15, 15, 0);
  const seeded = 't-own-bongda-hoalu'; // Hoa Lư, 6 đội, đã hết hạn đăng ký, 500.000đ / đội
  late MockWalletRepository playerWallet;
  late MockWalletRepository ownerWallet;
  late MockOwnerRepository owner;
  late MockTournamentRepository repo;

  Future<void> switchTo(String email, String password) =>
      MockAuthRepository(latency: Duration.zero).login(email, password);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await switchTo('owner@sportnexus.vn', 'Owner@123');
    playerWallet = MockWalletRepository(latency: Duration.zero, now: () => now);
    ownerWallet = MockWalletRepository(
      latency: Duration.zero,
      now: () => now,
      keyPrefix: MockOwnerRepository.ownerWalletPrefix,
      initialBalance: 3200000,
    );
    owner = MockOwnerRepository(latency: Duration.zero, now: () => now, wallet: ownerWallet);
    repo = MockTournamentRepository(
      latency: Duration.zero,
      now: () => now,
      wallet: playerWallet,
      owner: owner,
      random: Random(7),
    );
  });

  Matcher error(String message) =>
      throwsA(isA<TournamentException>().having((e) => e.message, 'message', message));

  TournamentDraft pairDraft({
    DateTime? deadline,
    DateTime? start,
    DateTime? end,
    int maxEntries = 8,
    int fee = 200000,
    String description = '',
  }) =>
      TournamentDraft(
        name: 'Giải Cầu Lông Đôi Thiên Triều',
        facilityId: 'f-hcm-thientrieu',
        sport: Sport.badminton,
        entryType: TournamentEntryType.pair,
        minMembers: 2,
        maxMembers: 2,
        maxEntries: maxEntries,
        entryFee: fee,
        registrationDeadline: deadline ?? DateTime(2026, 10, 25, 23, 59),
        startDate: start ?? DateTime(2026, 10, 28, 7),
        endDate: end ?? DateTime(2026, 10, 28, 18),
        description: description,
      );

  test('chủ sân thấy giải mình tổ chức', () async {
    expect((await repo.getOrganizedTournaments()).map((t) => t.id), [seeded]);
  });

  test('tạo giải: mở đăng ký ngay, tự tạm đóng sân, người chơi thấy được', () async {
    final t = await repo.createTournament(pairDraft());
    expect(t.status(now), TournamentStatus.registrationOpen);
    expect(t.organizerId, MockAuthRepository.ownerId);
    expect(t.closureId, isNotNull);

    final facility = await owner.getOwnerFacility('f-hcm-thientrieu');
    final closure = facility.closures.singleWhere((c) => c.id == t.closureId);
    expect(closure.blocks(Sport.badminton, CourtType.standard, DateTime(2026, 10, 28, 9), DateTime(2026, 10, 28, 10)), isTrue);
    expect(closure.blocks(Sport.pickleball, CourtType.standard, DateTime(2026, 10, 28, 9), DateTime(2026, 10, 28, 10)), isFalse);

    await switchTo('player@sportnexus.vn', 'Player@123');
    final list = await repo.getTournaments(const TournamentQuery(city: 'Hồ Chí Minh'));
    expect(list.map((x) => x.id), contains(t.id));
  });

  test('không tạo được nếu ngày thi đấu đã có người đặt sân', () async {
    await expectLater(
      repo.createTournament(pairDraft(
        deadline: DateTime(2026, 10, 15, 15, 30),
        start: DateTime(2026, 10, 15, 16),
        end: DateTime(2026, 10, 15, 18),
      )),
      error(OwnerFacilityStrings.closureBlocked(2)),
    );
    expect(await repo.getOrganizedTournaments(), hasLength(1));
  });

  test('kiểm tra thông tin giải', () async {
    await expectLater(repo.createTournament(pairDraft(maxEntries: 6)), error(OwnerTournamentStrings.invalidSize));
    await expectLater(
      repo.createTournament(pairDraft(deadline: DateTime(2026, 10, 14))),
      error(OwnerTournamentStrings.deadlinePassed),
    );
    await expectLater(
      repo.createTournament(pairDraft(deadline: DateTime(2026, 10, 29))),
      error(OwnerTournamentStrings.invalidDates),
    );
    await expectLater(
      repo.createTournament(TournamentDraft(
        name: 'Bóng đá',
        facilityId: 'f-hcm-hoalu',
        sport: Sport.football,
        courtType: CourtType.football7,
        entryType: TournamentEntryType.team,
        minMembers: 5, // sân 7 người phải tối thiểu 7
        maxMembers: 10,
        maxEntries: 8,
        entryFee: 0,
        registrationDeadline: DateTime(2026, 10, 25),
        startDate: DateTime(2026, 10, 30, 7),
        endDate: DateTime(2026, 10, 30, 18),
      )),
      error(OwnerTournamentStrings.invalidMembers),
    );
  });

  test('đã có người đăng ký: chỉ sửa mô tả, giải thưởng, điều lệ', () async {
    final t = (await repo.getOrganizedTournaments()).single;
    final draft = TournamentDraft.fromTournament(t);
    await expectLater(
      repo.updateTournament(seeded, TournamentDraft(
        name: draft.name,
        facilityId: draft.facilityId,
        sport: draft.sport,
        courtType: draft.courtType,
        entryType: draft.entryType,
        minMembers: draft.minMembers,
        maxMembers: draft.maxMembers,
        maxEntries: draft.maxEntries,
        entryFee: 600000,
        registrationDeadline: draft.registrationDeadline,
        startDate: draft.startDate,
        endDate: draft.endDate,
      )),
      error(OwnerTournamentStrings.lockedFields),
    );

    final updated = await repo.updateTournament(seeded, TournamentDraft(
      name: draft.name,
      facilityId: draft.facilityId,
      sport: draft.sport,
      courtType: draft.courtType,
      entryType: draft.entryType,
      minMembers: draft.minMembers,
      maxMembers: draft.maxMembers,
      maxEntries: draft.maxEntries,
      entryFee: draft.entryFee,
      registrationDeadline: draft.registrationDeadline,
      startDate: draft.startDate,
      endDate: draft.endDate,
      description: 'Mô tả mới',
      rules: const ['Điều lệ mới'],
    ));
    expect(updated.description, 'Mô tả mới');
    expect(updated.rules, ['Điều lệ mới']);
  });

  test('chưa ai đăng ký: đổi ngày thì dời lịch tạm đóng sân', () async {
    final t = await repo.createTournament(pairDraft());
    final moved = await repo.updateTournament(
      t.id,
      pairDraft(start: DateTime(2026, 11, 2, 7), end: DateTime(2026, 11, 2, 18)),
    );
    final facility = await owner.getOwnerFacility('f-hcm-thientrieu');
    expect(facility.closures.where((c) => c.id == t.closureId), isEmpty);
    final closure = facility.closures.singleWhere((c) => c.id == moved.closureId);
    expect(closure.from, DateTime(2026, 11, 2));
  });

  test('bốc thăm: sau hạn, 6 đội vào sơ đồ 8, 2 đội miễn đấu vòng 1', () async {
    final fresh = await repo.createTournament(pairDraft());
    await expectLater(repo.drawBracket(fresh.id), error(OwnerTournamentStrings.drawNotYet));

    final t = await repo.drawBracket(seeded);
    expect(t.bracketSize, 8);
    expect(t.roundCount, 3);
    final r1 = t.matchesInRound(1);
    expect(r1, hasLength(4));
    final drawnIds = r1.expand((m) => [m.entryAId, m.entryBId]).whereType<String>().toList();
    expect(drawnIds.toSet(), t.entries.map((e) => e.id).toSet());
    expect(drawnIds, hasLength(6));

    final byes = r1.where((m) => m.isBye).toList();
    expect(byes, hasLength(2));
    for (final b in byes) {
      expect(b.winnerId, isNotNull);
      final next = t.matchesInRound(2)[b.index ~/ 2];
      expect(next.involves(b.winnerId!), isTrue);
    }
    // Hai trận miễn đấu không dồn về cùng một trận bán kết.
    expect(byes.map((b) => b.index ~/ 2).toSet(), hasLength(2));

    await expectLater(repo.drawBracket(seeded), error(OwnerTournamentStrings.alreadyDrawn));
  });

  test('nhập kết quả tới chung kết: giải kết thúc, lệ phí về ví chủ sân', () async {
    var t = await repo.drawBracket(seeded);
    final balanceBefore = await ownerWallet.getBalance();

    final finalMatch = t.matchesInRound(3).single;
    await expectLater(
      repo.recordResult(seeded, finalMatch.id, winnerId: 'x', score: '1-0'),
      error(OwnerTournamentStrings.matchNotReady),
    );

    Future<void> playRound(int round) async {
      for (final m in t.matchesInRound(round).where((m) => !m.isFinished)) {
        t = await repo.recordResult(seeded, m.id, winnerId: m.entryAId!, score: '3 - 1');
      }
    }

    final firstPlayable = t.matchesInRound(1).firstWhere((m) => !m.isBye);
    await expectLater(
      repo.recordResult(seeded, firstPlayable.id, winnerId: firstPlayable.entryAId!, score: ' '),
      error(OwnerTournamentStrings.scoreRequired),
    );
    await expectLater(
      repo.recordResult(seeded, firstPlayable.id, winnerId: 'not-in-match', score: '1-0'),
      error(OwnerTournamentStrings.invalidWinner),
    );

    await playRound(1);
    await playRound(2);
    // Bán kết đã đá: không sửa ngược trận vòng 1.
    await expectLater(
      repo.recordResult(seeded, firstPlayable.id, winnerId: firstPlayable.entryBId!, score: '0-3'),
      error(OwnerTournamentStrings.nextPlayed),
    );
    expect(t.paidOutAt, isNull);

    await playRound(3);
    expect(t.champion, isNotNull);
    expect(t.status(now), TournamentStatus.finished);
    expect(t.paidOutAt, now);
    expect(await ownerWallet.getBalance(), balanceBefore + 6 * 500000);

    final october = await owner.getMonthlyRevenue(now, facilityId: 'f-hcm-hoalu');
    expect(october.items.where((i) => i.kind == RevenueKind.tournamentFee).single.amount, 3000000);

    await expectLater(repo.cancelTournament(seeded), error(OwnerTournamentStrings.alreadyFinished));
  });

  test('hủy giải: hoàn 100% lệ phí người chơi, mở lại sân', () async {
    final t = await repo.createTournament(pairDraft());

    await switchTo('player@sportnexus.vn', 'Player@123');
    final mate = await repo.findPlayer('phuonglinh@sportnexus.vn');
    final before = await playerWallet.getBalance();
    await repo.register(TournamentRegistration(tournamentId: t.id, teammates: [mate]));
    expect(await playerWallet.getBalance(), before - 200000);
    await expectLater(repo.cancelTournament(t.id), error(OwnerTournamentStrings.notOrganizer));

    await switchTo('owner@sportnexus.vn', 'Owner@123');
    final cancelled = await repo.cancelTournament(t.id);
    expect(cancelled.status(now), TournamentStatus.cancelled);
    expect(await playerWallet.getBalance(), before);
    final facility = await owner.getOwnerFacility('f-hcm-thientrieu');
    expect(facility.closures.where((c) => c.id == t.closureId), isEmpty);
  });
}
