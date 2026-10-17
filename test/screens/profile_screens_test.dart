import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/core/strings/profile_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/screens/profile/change_password_screen.dart';
import 'package:test1/screens/profile/edit_profile_screen.dart';
import 'package:test1/screens/profile/profile_screen.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.wallet = MockWalletRepository(latency: Duration.zero);
    AppRepositories.review = MockReviewRepository(latency: Duration.zero);
    await auth.login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Hồ sơ: hiện tên, tên đăng nhập, Fair Play; sửa họ tên rồi quay lại thấy tên mới', (tester) async {
    await pump(tester, const ProfileScreen());
    expect(find.text('Khoa Cao'), findsOneWidget);
    expect(find.text('@player1'), findsOneWidget);
    expect(find.text('C'), findsOneWidget); // chưa có ảnh: chữ cái đầu của tên
    expect(find.text(ProfileStrings.changePassword), findsOneWidget);

    await tester.tap(find.byTooltip(ProfileStrings.editProfile));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget); // SĐT chỉ xem

    await tester.enterText(find.byType(TextFormField), 'Khoa Cao Mới');
    await tester.tap(find.text(ProfileStrings.save));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Khoa Cao Mới'), findsOneWidget);
  });

  testWidgets('Sửa hồ sơ: họ tên trống thì báo lỗi, không gửi', (tester) async {
    await pump(tester, EditProfileScreen(user: (await SessionStore.readUser())!));
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text(ProfileStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.requiredField), findsOneWidget);
    expect((await SessionStore.readUser())!.fullName, 'Khoa Cao');
  });

  testWidgets('Đổi mật khẩu: mật khẩu mới trùng cũ bị chặn; đổi xong về màn đăng nhập', (tester) async {
    await pump(tester, const ChangePasswordScreen());
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'Player@123');
    await tester.enterText(fields.at(1), 'Player@123');
    await tester.enterText(fields.at(2), 'Player@123');
    await tester.tap(find.text(ProfileStrings.changePasswordButton));
    await tester.pumpAndSettle();
    expect(find.text(ProfileStrings.samePassword), findsOneWidget);

    await tester.enterText(fields.at(1), 'MatKhau99');
    await tester.enterText(fields.at(2), 'MatKhau99');
    await tester.tap(find.text(ProfileStrings.changePasswordButton));
    await tester.pumpAndSettle();

    tester.takeException(); // ảnh nền màn đăng nhập tải từ mạng, trong test luôn lỗi
    expect(find.text(AuthStrings.loginTitle), findsOneWidget);
    expect(find.text(ProfileStrings.passwordChanged), findsOneWidget);
    expect(await SessionStore.readUser(), isNull);
  });

  testWidgets('Xóa tài khoản: cảnh báo → nhập mật khẩu; sai thì báo lỗi, đúng thì về màn đăng nhập', (tester) async {
    await pump(tester, EditProfileScreen(user: (await SessionStore.readUser())!));
    await tester.ensureVisible(find.text(ProfileStrings.deleteAccount));
    await tester.tap(find.text(ProfileStrings.deleteAccount));
    await tester.pumpAndSettle();
    expect(find.text(ProfileStrings.deleteWarningTitle), findsOneWidget);

    await tester.tap(find.text(ProfileStrings.deleteContinue));
    await tester.pumpAndSettle();
    final password = find.widgetWithText(TextField, ProfileStrings.deletePasswordLabel);
    await tester.enterText(password, 'sai');
    await tester.tap(find.text(ProfileStrings.deleteButton));
    await tester.pumpAndSettle();
    expect(find.text(ProfileStrings.wrongDeletePassword), findsOneWidget);

    await tester.enterText(password, 'Player@123');
    await tester.tap(find.text(ProfileStrings.deleteButton));
    await tester.pumpAndSettle();
    tester.takeException(); // ảnh nền màn đăng nhập tải từ mạng, trong test luôn lỗi
    expect(find.text(AuthStrings.loginTitle), findsOneWidget);
    expect(find.text(ProfileStrings.deleted), findsOneWidget);
  });
}
