import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/voucher_strings.dart';
import 'package:test1/data/mock/mock_voucher_repository.dart';
import 'package:test1/models/voucher.dart';
import 'package:test1/screens/wallet/my_vouchers_screen.dart';

import '../helpers/layout_check.dart';

Voucher _voucher(String id, VoucherStatus status, {int ageDays = 1}) {
  final createdAt = DateTime.now().subtract(Duration(days: ageDays));
  return Voucher(
    id: id,
    discountPercent: 10,
    status: status,
    expiresAt: createdAt.add(const Duration(days: 30)),
    sourceBookingId: 'bk-$id',
    createdAt: createdAt,
  );
}

void main() {
  testWidgets('3 tab theo trạng thái; mã còn dùng mà quá hạn nằm ở tab Hết hạn', (tester) async {
    final repo = MockVoucherRepository(vouchers: [
      _voucher('a', VoucherStatus.active),
      _voucher('b', VoucherStatus.used),
      _voucher('c', VoucherStatus.active, ageDays: 40),
    ]);
    await tester.pumpWidget(MaterialApp(home: MyVouchersScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text(VoucherStrings.title), findsOneWidget);
    expect(find.text(VoucherStrings.discount(10)), findsOneWidget);
    expect(find.text(VoucherStrings.compensation), findsOneWidget);

    await tester.tap(find.text(VoucherStrings.tabUsed));
    await tester.pumpAndSettle();
    expect(find.text(VoucherStrings.statusUsed), findsWidgets);

    await tester.tap(find.text(VoucherStrings.tabExpired));
    await tester.pumpAndSettle();
    expect(find.text(VoucherStrings.statusExpired), findsWidgets);
  });

  testWidgets('chưa có mã thì hiện câu trống', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyVouchersScreen(repository: MockVoucherRepository(vouchers: []))));
    await tester.pumpAndSettle();

    expect(find.text(VoucherStrings.emptyActive), findsOneWidget);
  });

  testWidgets('không tràn chữ trên nhiều cỡ máy + chữ phóng to', (tester) async {
    final problems = await collectLayoutProblems(
      tester,
      VoucherStrings.title,
      () => MyVouchersScreen(repository: MockVoucherRepository()),
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
