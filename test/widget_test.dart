import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test1/main.dart'; // Ensure package name matches your pubspec

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SportNexusApp());

    // Verify that the title is displayed
    expect(find.text('SportNexus'), findsOneWidget);

    // Cho SplashScreen chạy hết thời gian chờ để không còn Timer treo khi test kết thúc.
    await tester.pump(const Duration(seconds: 1));
  });
}
