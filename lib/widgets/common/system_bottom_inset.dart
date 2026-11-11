import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// Chừa chỗ cho thanh điều hướng của Android (3 nút hoặc thanh cử chỉ) cho TOÀN APP.
///
/// Android 15+ bắt buộc vẽ tràn viền (edge-to-edge): nội dung nằm dưới thanh điều hướng hệ thống.
/// Các danh sách có `padding` tự đặt (vd. `EdgeInsets.all(16)`) không tự cộng safe area nên mục
/// cuối bị che. Bọc ở `MaterialApp.builder` để mọi màn (danh sách, nút cố định ở đáy, bottom sheet)
/// đều kết thúc phía trên thanh điều hướng; bên dưới chỉ để lại một dải nền trắng.
///
/// Bên trong, `MediaQuery.padding.bottom` = 0 nên các `SafeArea` / `BottomNavigationBar` cũ
/// không bị cộng trùng. Khi mở bàn phím, Android báo inset bàn phím (viewInsets) thay vì
/// padding nên dải này tự biến mất, Scaffold vẫn đẩy ô đang nhập lên như cũ.
class SystemBottomInset extends StatelessWidget {
  final Widget child;

  const SystemBottomInset({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ColoredBox(
        color: AppColors.white,
        child: SafeArea(top: false, left: false, right: false, child: child),
      ),
    );
  }
}

/// Khoảng trống cuối danh sách cuộn để mục cuối không dính sát mép dưới.
const double kScrollEndGap = 16;
