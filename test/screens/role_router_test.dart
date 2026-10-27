import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/user_role.dart';
import 'package:test1/screens/auth/add_phone_screen.dart';
import 'package:test1/screens/auth/role_router.dart';

void main() {
  testWidgets('tài khoản Google / Facebook chưa có SĐT: vào màn Thêm số điện thoại thay cho màn chính', (tester) async {
    const user = AppUser(id: 'u1', fullName: 'A', email: 'a@gmail.com', phone: '', role: UserRole.player);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => goToHome(context, user), child: const Text('vào')),
      ),
    ));
    await tester.tap(find.text('vào'));
    await tester.pumpAndSettle();
    tester.takeException(); // ảnh nền màn xác thực tải từ mạng, trong test luôn lỗi

    expect(find.byType(AddPhoneScreen), findsOneWidget);
    expect(find.text(AuthStrings.addPhoneTitle), findsOneWidget);
    expect(find.text(AuthStrings.logout), findsOneWidget);
  });

  test('app mobile chỉ cho Player và Chủ sân, chặn Admin', () {
    expect(isRoleAllowedOnMobile(UserRole.player), isTrue);
    expect(isRoleAllowedOnMobile(UserRole.courtOwner), isTrue);
    expect(isRoleAllowedOnMobile(UserRole.admin), isFalse);
  });

  test('đọc đúng role từ giá trị BE trả về', () {
    expect(UserRole.fromApi('Admin'), UserRole.admin);
    expect(UserRole.fromApi('courtowner'), UserRole.courtOwner);
    expect(UserRole.fromApi('Player'), UserRole.player);
  });
}
