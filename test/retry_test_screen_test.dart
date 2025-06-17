import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/screens/test/retry_test_screen.dart';

void main() {
  testWidgets('RetryTestScreen shows retry UI', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RetryTestScreen(),
        ),
      ),
    );

    // Check for retry button and input fields
    expect(find.byType(TextField), findsWidgets);
    expect(find.textContaining('Retry'), findsWidgets);
  });
}
