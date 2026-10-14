import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/tournament_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_tournament_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/tournament_repository.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/tournament.dart';
import 'package:test1/models/wallet_transaction.dart';

void main() {
  late DateTime clock;
  late MockWalletRepository wallet;
  late MockTournamentRepository repo;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  Matcher error(String message) =>
      throwsA(isA<TournamentException>().having((e) => e.message, 'message', message));

  const pairCup = 't-hcm-caulong-doi-mua-thu'; // đôi, 300.000đ, mở đăng ký
  const footballCup = 't-hcm-sportnexus-cup'; // đội 5–10 người, 1.500.000đ
  const basketball = 't-hcm-bongro-3x3'; // đã hết hạn, Khoa Cao là đội trưởng
  const pickleball = 't-hcm-pickleball-open-q7'; // đang diễn ra
  const tennis = 't-hcm-tennis-he'; // đã kết thúc

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 10, 0);
    wallet = MockWalletRepository(latency: Duration.zero, now: () => clock);
    repo = MockTournamentRepository(latency: Duration.zero, now: () => clock, wallet: wallet);
    await loginAs('player@sportnexus.vn');
  });

  group('danh sách', () {
    test('lọc theo thành phố; đang mở đăng ký trước, đã kết thúc sau cùng', () async {
      final list = await repo.getTournaments(const TournamentQuery(city: 'Hồ Chí Minh'));
      expect(list.map((t) => t.id), [footballCup, pairCup, basketball, pickleball, tennis]);
      expect(list.map((t) => t.status(clock)), [
        TournamentStatus.registrationOpen,
        TournamentStatus.registrationOpen,
        TournamentStatus.upcoming,
        TournamentStatus.ongoing,
        TournamentStatus.finished,
      ]);

      final hn = await repo.getTournaments(const TournamentQuery(city: 'Hà Nội'));
      expect(hn.single.maxEntries, 32);
    });

    test('lọc theo môn và trạng thái', () async {
      final football = await repo.getTournaments(const TournamentQuery(city: 'Hồ Chí Minh', sport: Sport.football));
      expect(football.single.id, footballCup);

      final ongoing = await repo.getTournaments(
        const TournamentQuery(city: 'Hồ Chí Minh', status: TournamentStatus.ongoing),
      );
      expect(ongoing.single.id, pickleball);
    });

    test('giải của tôi: chưa kết thúc trước (khai mạc sớm nhất trước), đã kết thúc sau', () async {
      final mine = await repo.getMyTournaments();
      expect(mine.map((t) => t.id), [pickleball, basketball, tennis]);
    });

    test('sơ đồ nhánh: số vòng, nhà vô địch, trận tiếp theo', () async {
      final t5 = await repo.getTournament(tennis);
      expect(t5.roundCount, 3);
      expect(t5.matches, hasLength(7));
      expect(t5.champion, isNotNull);
      expect(t5.champion!.hasMember('u-player-001'), isFalse);

      final t4 = await repo.getTournament(pickleball);
      final myEntry = t4.entryOf('u-player-001')!;
      final next = t4.matches.where((m) => m.involves(myEntry.id) && !m.isFinished).single;
      expect(next.round, 2);
      expect(TournamentStrings.roundName(next.round, t4.roundCount), 'Bán kết');
      expect(TournamentStrings.roundName(1, 5), 'Vòng 1/16');
    });
  });

  group('tìm đồng đội', () {
    test('theo email hoặc số điện thoại', () async {
      expect((await repo.findPlayer('PhuongLinh@sportnexus.vn')).name, 'Phương Linh');
      expect((await repo.findPlayer('0908888888')).userId, MockAuthRepository.restrictedPlayerId);
    });

    test('không có tài khoản hoặc không phải người chơi', () async {
      expect(repo.findPlayer('khongco@sportnexus.vn'), error(TournamentStrings.playerNotFound));
      expect(repo.findPlayer('owner@sportnexus.vn'), error(TournamentStrings.notAPlayer));
    });
  });

  group('đăng ký', () {
    Future<TournamentMember> partner() => repo.findPlayer('phuonglinh@sportnexus.vn');

    test('giải đôi: trừ lệ phí, tên đơn ghép từ 2 người, vào Giải của tôi', () async {
      final before = await wallet.getBalance();
      final t = await repo.register(TournamentRegistration(tournamentId: pairCup, teammates: [await partner()]));

      final entry = t.entryOf('u-player-001')!;
      expect(entry.name, 'Khoa Cao / Phương Linh');
      expect(entry.captainId, 'u-player-001');
      expect(t.entryCount, 12);
      expect(await wallet.getBalance(), before - 300000);
      final tx = (await wallet.getTransactions()).first;
      expect(tx.type, TransactionType.tournamentFee);
      expect((await repo.getMyTournaments()).map((t) => t.id), contains(pairCup));
    });

    test('sai số thành viên, đăng ký 2 lần, đồng đội đã có đơn khác', () async {
      expect(repo.register(const TournamentRegistration(tournamentId: pairCup)), error(TournamentStrings.wrongMemberCount));

      await repo.register(TournamentRegistration(tournamentId: pairCup, teammates: [await partner()]));
      expect(
        repo.register(TournamentRegistration(tournamentId: pairCup, teammates: [await repo.findPlayer('baongoc@sportnexus.vn')])),
        error(TournamentStrings.alreadyRegistered),
      );

      await loginAs('restricted@sportnexus.vn');
      expect(
        repo.register(TournamentRegistration(tournamentId: pairCup, teammates: [await partner()])),
        error(TournamentStrings.memberTaken('Phương Linh')),
      );
    });

    test('giải đội: bắt buộc tên đội; ví không đủ thì báo lỗi, không tạo đơn', () async {
      final mates = [
        for (final e in ['phuonglinh', 'tuankiet', 'baongoc', 'giahuy']) await repo.findPlayer('$e@sportnexus.vn'),
      ];
      expect(
        repo.register(TournamentRegistration(tournamentId: footballCup, teammates: mates)),
        error(TournamentStrings.teamNameRequired),
      );
      await expectLater(
        repo.register(TournamentRegistration(tournamentId: footballCup, teamName: 'Khoa FC', teammates: mates)),
        throwsA(isA<TournamentException>()),
      );
      expect((await repo.getTournament(footballCup)).entryOf('u-player-001'), isNull);
    });

    test('hết hạn đăng ký thì không nhận', () async {
      await loginAs('restricted@sportnexus.vn');
      final mates = [await repo.findPlayer('baongoc@sportnexus.vn'), await repo.findPlayer('hoangnam@sportnexus.vn')];
      expect(
        repo.register(TournamentRegistration(tournamentId: basketball, teamName: 'Bình 3x3', teammates: mates)),
        error(TournamentStrings.closed),
      );
    });
  });

  group('rút khỏi giải', () {
    test('trước hạn: hoàn 100%, suất mở lại', () async {
      await repo.register(
        TournamentRegistration(tournamentId: pairCup, teammates: [await repo.findPlayer('phuonglinh@sportnexus.vn')]),
      );
      final before = await wallet.getBalance();

      expect(await repo.withdraw(pairCup), 300000);
      expect(await wallet.getBalance(), before + 300000);
      final t = await repo.getTournament(pairCup);
      expect(t.entryOf('u-player-001'), isNull);
      expect(t.entryCount, 11);
    });

    test('sau hạn: không hoàn, vẫn trong sơ đồ và đánh dấu đã rút', () async {
      final before = await wallet.getBalance();
      expect(await repo.withdraw(basketball), 0);
      expect(await wallet.getBalance(), before);

      final entry = (await repo.getTournament(basketball)).entryOf('u-player-001')!;
      expect(entry.withdrawn, isTrue);
      expect(repo.withdraw(basketball), error(TournamentStrings.alreadyWithdrawn));
    });

    test('thành viên không phải đội trưởng, giải đã khai mạc', () async {
      // "restricted" là đồng đội trong đơn do Khoa Cao đăng ký.
      await repo.register(TournamentRegistration(
        tournamentId: pairCup,
        teammates: [await repo.findPlayer('restricted@sportnexus.vn')],
      ));
      await loginAs('restricted@sportnexus.vn');
      expect(repo.withdraw(pairCup), error(TournamentStrings.notCaptain));

      await loginAs('player@sportnexus.vn');
      expect(repo.withdraw(pickleball), error(TournamentStrings.alreadyStarted));
    });
  });

  test('BTC hủy giải: hoàn 100% lệ phí, trạng thái đã hủy', () async {
    await repo.register(
      TournamentRegistration(tournamentId: pairCup, teammates: [await repo.findPlayer('phuonglinh@sportnexus.vn')]),
    );
    final before = await wallet.getBalance();

    final t = await repo.simulateOrganizerCancelled(pairCup);
    expect(t.status(clock), TournamentStatus.cancelled);
    expect(await wallet.getBalance(), before + 300000);
    expect(repo.withdraw(pairCup), error(TournamentStrings.alreadyStarted));
  });

  test('BTC hủy giải có đơn mẫu của mình: vẫn hoàn lệ phí, hủy lần 2 không hoàn thêm', () async {
    final before = await wallet.getBalance();
    await repo.simulateOrganizerCancelled(basketball);
    expect(await wallet.getBalance(), before + 600000);
    await repo.simulateOrganizerCancelled(basketball);
    expect(await wallet.getBalance(), before + 600000);
  });
}
