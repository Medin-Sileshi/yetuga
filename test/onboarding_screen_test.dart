import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/screens/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen shows account type selection', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    // Check for account type selection widgets
    expect(find.textContaining('Account type'), findsWidgets);
    // Add more checks for each onboarding step as needed
  });
}
