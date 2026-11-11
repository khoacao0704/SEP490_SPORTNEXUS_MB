// Dùng chung cho các test kiểm bố cục: dựng màn ở nhiều cỡ máy × cỡ chữ, gom lỗi tràn (RenderFlex overflow).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Máy rất nhỏ (iPhone SE 1 / Android 5"), máy phổ biến, máy lớn, tablet.
const layoutSizes = [Size(320, 568), Size(360, 640), Size(412, 915), Size(800, 1280)];

/// Cỡ chữ mặc định và chữ phóng to (người dùng chỉnh trong Cài đặt máy).
const layoutTextScales = [1.0, 1.3, 1.5];

/// Cho vài khung hình chạy (không dùng pumpAndSettle vì màn đang tải có vòng xoay chạy mãi).
Future<void> settleFrames(WidgetTester tester, {int frames = 4}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Dựng [build] ở mọi cỡ máy × cỡ chữ; [interact] chạy thêm thao tác (mở tab, sang bước…).
/// Trả danh sách lỗi tràn dạng "Tên 320×568 chữ ×1.3: … @ lib/…dart:dòng".
Future<List<String>> collectLayoutProblems(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  final problems = <String>[];
  final previous = FlutterError.onError;
  try {
    for (final size in layoutSizes) {
      for (final scale in layoutTextScales) {
        var where = '$name ${size.width.toInt()}×${size.height.toInt()} chữ ×$scale';
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (!text.contains('overflowed')) return;
          // Vị trí widget gây tràn để biết sửa ở đâu.
          final source = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0) ?? '?';
          problems.add('$where: ${text.split('\n').first} @ $source');
        };
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = size * 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: build()));
        await settleFrames(tester, frames: 6);
        if (interact != null) {
          where = '$where (sau thao tác)';
          try {
            await interact(tester);
          } catch (_) {
            // Thao tác không làm được ở cỡ này (vd. nút nằm ngoài màn): chỉ kiểm phần đã dựng.
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6)); // cho timer / SnackBar / đếm ngược chạy hết
      }
    }
  } finally {
    FlutterError.onError = previous;
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
  return problems;
}

/// Như [collectLayoutProblems] nhưng test thất bại nếu có lỗi tràn.
Future<void> expectNoOverflow(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  final problems = await collectLayoutProblems(tester, name, build, interact: interact);
  expect(problems, isEmpty, reason: problems.join('\n'));
}
