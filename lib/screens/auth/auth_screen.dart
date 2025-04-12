import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yetuga/providers/onboarding_provider.dart';
import 'package:yetuga/screens/onboarding/onboarding_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/auth_page_template.dart';
import 'email_signin_screen.dart';
import '../home_screen.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Signing in...'),
              ],
            ),
          ),
        );
      }

      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();

      if (userCredential != null && context.mounted) {
        // Close the loading dialog
        Navigator.of(context).pop();

        // Show a new loading dialog for checking onboarding status
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking onboarding status...'),
                ],
              ),
            ),
          );
        }

        try {
          // Check Firebase directly for onboarding status
          final firebaseService = ref.read(firebaseServiceProvider);
          final userProfile = await firebaseService.getUserProfile();
          print('DEBUG: User profile from Firebase: $userProfile');

          // Close the loading dialog
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          if (userProfile != null && userProfile['onboardingCompleted'] == true) {
            print('DEBUG: Onboarding is completed in Firebase, navigating to home screen');

            // Update Hive with the onboarding data from Firebase
            try {
              print('DEBUG: Updating Hive with onboarding data from Firebase');
              final onboardingNotifier = ref.read(onboardingProvider.notifier);

              // Create a new OnboardingData object with the data from Firebase
              final onboardingData = OnboardingData()
                ..accountType = userProfile['accountType']
                ..displayName = userProfile['displayName']
                ..username = userProfile['username']
                ..birthday = userProfile['birthday']?.toDate() // Convert Timestamp to DateTime
                ..phoneNumber = userProfile['phoneNumber']
                ..profileImageUrl = userProfile['profileImageUrl']
                ..interests = List<String>.from(userProfile['interests'] ?? [])
                ..onboardingCompleted = true;

              // Save to Hive
              await onboardingNotifier.saveData(onboardingData);
              print('DEBUG: Successfully updated Hive with onboarding data from Firebase');
            } catch (e) {
              print('DEBUG: Error updating Hive: $e');
              // Continue even if there's an error updating Hive
            }

            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
          } else {
            print('DEBUG: Onboarding is not completed in Firebase, navigating to onboarding screen');
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            }
          }
        } catch (e) {
          print('DEBUG: Error checking Firebase for onboarding status: $e');
          // Close the loading dialog if it's still open
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          // Fall back to checking the onboarding provider
          final onboardingState = ref.read(onboardingProvider);
          onboardingState.when(
            data: (data) {
              if (data.isComplete()) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            loading: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            },
            error: (error, stack) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            },
          );
        }
      }
    } catch (e) {
      // Close any open loading dialogs
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in with Google: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return AuthPageTemplate(
      title: "First Let's\nSign-In to Verify\nYour Account",
      body: GestureDetector(
        onTap: () => _handleGoogleSignIn(context, ref),
        child: Image.asset(
          isDark
              ? 'assets/dark/signin_with_google_dark.png'
              : 'assets/light/signin_with_google_light.png',
          height: 80,
          fit: BoxFit.contain,
        ),
      ),
      bottomButtons: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EmailSignInScreen(),
              ),
            );
          },
          child: const Text('Sign in with Email'),
        ),
      ],
    );
  }
}
