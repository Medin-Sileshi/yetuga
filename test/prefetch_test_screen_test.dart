import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/screens/test/prefetch_test_screen.dart';

void main() {
  testWidgets('PrefetchTestScreen shows prefetch UI', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PrefetchTestScreen(),
        ),
      ),
    );

    // Check for event/user ID fields and buttons
    expect(find.byType(TextField), findsWidgets);
    expect(find.textContaining('Track'), findsWidgets);
    expect(find.textContaining('Prefetch'), findsWidgets);
  });
}
