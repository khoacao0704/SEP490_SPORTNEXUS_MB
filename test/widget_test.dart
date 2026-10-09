import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test1/main.dart'; // Ensure package name matches your pubspec

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SportNexusApp());

    // Verify that the title is displayed
    expect(find.text('SportNexus'), findsOneWidget);
  });
}
