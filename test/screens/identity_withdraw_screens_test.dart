import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/identity_rules.dart';
import 'package:test1/core/constants/wallet_rules.dart';
import 'package:test1/core/strings/identity_strings.dart';
import 'package:test1/core/strings/wallet_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_identity_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/identity_verification.dart';
import 'package:test1/screens/profile/identity_verification_screen.dart';
import 'package:test1/screens/wallet/withdraw_screen.dart';

import '../helpers/layout_check.dart';

void main() {
  late MockIdentityRepository identity;
  late MockWalletRepository wallet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    identity = MockIdentityRepository(latency: Duration.zero);
    AppRepositories.identity = identity;
    wallet = MockWalletRepository(latency: Duration.zero, initialBalance: 1000000);
    AppRepositories.wallet = wallet;
    await wallet.addBankAccount(
      bankCode: 'VCB',
      bankName: 'Vietcombank',
      accountNumber: '0123456789',
      accountHolder: 'NGUYEN VAN A',
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  /// Bộ chọn ảnh giả: trả đường dẫn không có thật (ảnh xem trước hiện biểu tượng dự phòng).
  Future<String?> fakePick(BuildContext _, IdentityPhoto photo) async => '/tmp/${photo.name}.jpg';

  group('quy tắc eKYC', () {
    test('CCCD đúng 12 số; từ 18 tuổi', () {
      expect(IdentityRules.isValidIdNumber('079012345678'), isTrue);
      expect(IdentityRules.isValidIdNumber('07901234567'), isFalse);
      expect(IdentityRules.isValidIdNumber('07901234567a'), isFalse);
      final now = DateTime(2026, 11, 22);
      expect(IdentityRules.isAdult(DateTime(2008, 11, 22), now), isTrue);
      expect(IdentityRules.isAdult(DateTime(2008, 11, 23), now), isFalse);
    });
  });

  testWidgets('eKYC: chưa gửi → nhập CCCD + chụp 3 ảnh → gửi → chờ duyệt', (tester) async {
    await pump(tester, IdentityVerificationScreen(pickPhoto: fakePick));
    expect(find.text(IdentityStrings.statusNone), findsOneWidget);

    // Gửi khi còn trống: báo từng mục.
    await tester.tap(find.text(IdentityStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(IdentityStrings.required), findsNWidgets(2)); // họ tên + ngày sinh
    expect(find.text(IdentityStrings.invalidIdNumber), findsOneWidget);
    expect(find.text(IdentityStrings.missingPhoto), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, IdentityStrings.fullName), 'Nguyễn Văn A');
    await tester.enterText(find.widgetWithText(TextFormField, IdentityStrings.idNumber), '079012345678');
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    for (var i = 0; i < IdentityPhoto.values.length; i++) {
      await tester.tap(find.text(IdentityStrings.takePhoto).first);
      await tester.pumpAndSettle();
    }
    expect(find.text(IdentityStrings.retake), findsNWidgets(3));

    await tester.tap(find.text(IdentityStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(IdentityStrings.statusPending), findsOneWidget);
    expect(find.text(IdentityStrings.submit), findsNothing); // đang chờ: không gửi lại
    final saved = (await identity.getMyVerification())!;
    expect(saved.status, IdentityStatus.pending);
    expect(saved.idNumber, '079012345678');
  });

  testWidgets('eKYC: bị từ chối → hiện lý do, điền lại thông tin cũ, gửi lại được', (tester) async {
    identity = MockIdentityRepository(
      latency: Duration.zero,
      initial: IdentityVerification(
        status: IdentityStatus.rejected,
        fullName: 'Nguyễn Văn A',
        idNumber: '079012345678',
        dateOfBirth: DateTime(1999, 5, 1),
        rejectReason: 'Ảnh mờ',
      ),
    );
    AppRepositories.identity = identity;
    await pump(tester, IdentityVerificationScreen(pickPhoto: fakePick));

    expect(find.text(IdentityStrings.rejectedNote('Ảnh mờ')), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('079012345678'), findsOneWidget);
    expect(find.text(IdentityStrings.resubmit), findsOneWidget);
  });

  group('Đổi Điểm ra tiền của người chơi (thẻ 41, chạy giả lập)', () {
    Finder withdrawButton() => find.text(WalletStrings.withdrawButton);

    testWidgets('chưa eKYC: hiện nhắc, bấm đổi thì chuyển sang màn chụp CCCD', (tester) async {
      await pump(tester, const WithdrawScreen(policy: WithdrawalPolicy.player));
      expect(find.text(WalletStrings.identityRequired), findsOneWidget);
      expect(
        find.text(WalletStrings.playerWithdrawalNote(Formatters.bankVnd(200000), Formatters.bankVnd(5000))),
        findsOneWidget,
      );

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      expect(find.byType(IdentityVerificationScreen), findsOneWidget);
    });

    testWidgets('đang chờ duyệt eKYC: báo chờ duyệt, không gửi lệnh', (tester) async {
      identity = MockIdentityRepository(
        latency: Duration.zero,
        initial: const IdentityVerification(status: IdentityStatus.pending),
      );
      AppRepositories.identity = identity;
      await pump(tester, const WithdrawScreen(policy: WithdrawalPolicy.player));
      await tester.enterText(find.byType(TextField), '300000');
      await tester.tap(withdrawButton());
      await tester.pump();
      expect(find.text(WalletStrings.identityPending), findsWidgets);
      expect(find.byType(IdentityVerificationScreen), findsNothing);
      expect(await wallet.getPendingWithdrawalAmount(), 0);
    });

    testWidgets('đã eKYC: chặn dưới 200.000, hiện tổng trừ ví gồm phí 5.000', (tester) async {
      identity = MockIdentityRepository(
        latency: Duration.zero,
        initial: const IdentityVerification(status: IdentityStatus.approved),
      );
      AppRepositories.identity = identity;
      await pump(tester, const WithdrawScreen(policy: WithdrawalPolicy.player));
      expect(find.text(WalletStrings.identityRequired), findsNothing);

      await tester.enterText(find.byType(TextField), '150000');
      await tester.pump();
      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      expect(find.text(WalletStrings.belowMinWithdrawal(Formatters.vnd(200000))), findsOneWidget);

      await tester.enterText(find.byType(TextField), '300000');
      await tester.pump();
      expect(find.text(WalletStrings.withdrawTotalDeduct(Formatters.vnd(305000))), findsOneWidget);
    });

    testWidgets('Chủ sân giữ luật cũ: không cần eKYC, tối thiểu 50.000, miễn phí', (tester) async {
      await pump(tester, const WithdrawScreen());
      expect(find.text(WalletStrings.identityRequired), findsNothing);
      expect(
        find.text(WalletStrings.minWithdrawalNote(Formatters.vnd(WalletRules.minWithdrawal), WalletStrings.free)),
        findsOneWidget,
      );
    });
  });

  testWidgets('Bố cục eKYC + đổi ra tiền: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final problems = <String>[
      ...await collectLayoutProblems(tester, 'eKYC chưa gửi', () => IdentityVerificationScreen(pickPhoto: fakePick)),
      ...await collectLayoutProblems(tester, 'Đổi ra tiền (chưa eKYC)', () => const WithdrawScreen(policy: WithdrawalPolicy.player)),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
