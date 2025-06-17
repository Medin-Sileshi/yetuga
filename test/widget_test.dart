// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/screens/auth/auth_screen.dart';

void main() {
  testWidgets('AuthScreen shows sign-in buttons and legal text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthScreen(),
        ),
      ),
    );

    // Check for Google sign-in button (by image or text)
    expect(find.byType(Image), findsWidgets);

    // Check for legal text
    expect(find.textContaining('agree to the Privacy Policy'), findsOneWidget);
    expect(find.textContaining('Terms & Conditions'), findsOneWidget);

    // Check that the clickable text is present
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
  });
}
