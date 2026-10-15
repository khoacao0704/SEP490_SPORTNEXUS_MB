import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_finance_strings.dart';
import 'package:test1/core/strings/wallet_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/owner_finance.dart';
import 'package:test1/models/wallet_transaction.dart';

void main() {
  late DateTime now;
  late MockWalletRepository wallet;
  late MockOwnerRepository repo;

  Future<void> setUpAt(DateTime at) async {
    now = at;
    SharedPreferences.setMockInitialValues({});
    await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
    wallet = MockWalletRepository(
      latency: Duration.zero,
      now: () => now,
      keyPrefix: MockOwnerRepository.ownerWalletPrefix,
      initialBalance: 3200000,
    );
    repo = MockOwnerRepository(latency: Duration.zero, now: () => now, wallet: wallet);
  }

  Matcher throwsOwner(String message) =>
      throwsA(isA<OwnerException>().having((e) => e.message, 'message', message));

  // Thứ 4, 15/10/2026 15:00.
  setUp(() => setUpAt(DateTime(2026, 10, 15, 15, 0)));

  test('phí tháng = 10% toàn bộ doanh thu tháng, gồm phần tự thu tại sân', () async {
    final bills = await repo.getListingFees();
    expect(bills.map((b) => b.month), [DateTime(2026, 9), DateTime(2026, 8)]);

    final september = await repo.getMonthlyRevenue(DateTime(2026, 9));
    final sepBill = bills.first;
    expect(sepBill.revenue, september.total);
    expect(sepBill.amount, (september.total * 0.1).round());
    expect(september.atCourt, greaterThan(0));
    expect(september.total, september.viaApp + september.atCourt);
    expect(september.daily, hasLength(30));
  });

  test('chốt ngày 1, hạn ngày 7: sau ngày 7 chưa trả là quá hạn', () async {
    final bills = await repo.getListingFees();
    expect(bills.first.dueDate, DateTime(2026, 10, 7));
    expect(bills.first.status(now), FeeStatus.overdue);
    expect(bills.last.status(now), FeeStatus.paid);

    await setUpAt(DateTime(2026, 10, 7, 23, 0));
    expect((await repo.getListingFees()).first.status(now), FeeStatus.due);
  });

  test('check-out giải ngân phần tiền qua app vào ví Chủ sân và cộng doanh thu', () async {
    final revenueBefore = (await repo.getMonthlyRevenue(now)).total; // ghi nhận tiền vắng mặt trước
    final before = await wallet.getBalance();

    await repo.checkOut('LFGOW1');

    expect(await wallet.getBalance(), before + 160000);
    final txs = await wallet.getTransactions();
    final release = txs.singleWhere((t) => t.reference == 'LFGOW1');
    expect(release.type, TransactionType.escrowRelease);
    expect(release.amount, 160000);
    expect((await repo.getMonthlyRevenue(now)).total, revenueBefore + 160000);
  });

  test('vắng mặt: tiền cọc đã trả về chủ sân như tiền phạt', () async {
    final before = await wallet.getBalance();
    final october = await repo.getMonthlyRevenue(now, facilityId: 'f-hcm-hoalu');
    final noShow = october.items.where((i) => i.id == 'rv-noshow-OW1004').single;
    expect(noShow.kind, RevenueKind.penalty);
    expect(noShow.amount, 125000);
    expect(await wallet.getBalance(), before + 125000);

    // Ghi nhận một lần.
    await repo.getMonthlyRevenue(now);
    expect(await wallet.getBalance(), before + 125000);
  });

  test('trả phí bằng ví: thiếu tiền báo lỗi, đủ thì trả xong và hết quá hạn', () async {
    final sep = (await repo.getListingFees()).first;
    await expectLater(repo.payListingFee(sep.id), throwsOwner(WalletStrings.insufficientBalance));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${MockOwnerRepository.ownerWalletPrefix}${MockWalletRepository.keyBalance}', 50000000);
    final paid = await repo.payListingFee(sep.id);
    expect(paid.status(now), FeeStatus.paid);
    expect(await wallet.getBalance(), 50000000 - sep.amount);
    expect((await wallet.getTransactions()).first.type, TransactionType.listingFee);
    expect((await repo.getListingFees()).every((b) => b.status(now) == FeeStatus.paid), isTrue);
    expect(() => repo.payListingFee(sep.id), throwsOwner(OwnerFinanceStrings.alreadyPaid));
  });

  test('ví Chủ sân tách riêng với ví người chơi', () async {
    await repo.checkOut('LFGOW1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(MockWalletRepository.keyBalance), isNull);
    expect(prefs.getInt('${MockOwnerRepository.ownerWalletPrefix}${MockWalletRepository.keyBalance}'), isNotNull);
  });

  test('lọc doanh thu theo cơ sở', () async {
    final all = await repo.getMonthlyRevenue(DateTime(2026, 9));
    final tt = await repo.getMonthlyRevenue(DateTime(2026, 9), facilityId: 'f-hcm-thientrieu');
    final hl = await repo.getMonthlyRevenue(DateTime(2026, 9), facilityId: 'f-hcm-hoalu');
    expect(tt.total + hl.total, all.total);
    expect(all.byFacility, hasLength(2));
    expect(tt.penalties, 0);
  });
}
