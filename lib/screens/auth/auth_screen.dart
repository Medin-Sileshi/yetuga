import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yetuga/screens/pdf_viewer_screen.dart';
import 'package:yetuga/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/providers/onboarding_provider.dart';
import 'package:yetuga/screens/onboarding/onboarding_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/auth_page_template.dart';
import 'email_signin_screen.dart';
import '../authenticated_home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
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

      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.signInWithGoogle(ref);

      // check if the user actually signed in (user canceled if no user exists)
      if (FirebaseAuth.instance.currentUser == null) {
        // user canceled google sign-in; close the dialog and do nothing.
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      if (context.mounted) {
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
          // First check Hive for cached onboarding data
          final onboardingState = ref.read(onboardingProvider);

          // Check if we have valid data in Hive
          bool onboardingCompletedInHive = false;

          await onboardingState.when(
            data: (data) async {
              if (data.isComplete()) {
                onboardingCompletedInHive = true;
                Logger.d('AuthScreen',
                    'Onboarding is completed in Hive: ${data.toString()}');
              } else {
                Logger.d('AuthScreen', 'Onboarding is not completed in Hive');
              }
            },
            loading: () {
              Logger.d('AuthScreen', 'Onboarding data is loading from Hive');
            },
            error: (error, stack) {
              Logger.d('AuthScreen',
                  'Error loading onboarding data from Hive: $error');
            },
          );

          // If onboarding is completed in Hive, navigate to home screen
          if (onboardingCompletedInHive) {
            // Close the loading dialog
            if (context.mounted) {
              Navigator.of(context).pop();

              // Navigate to home screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => const AuthenticatedHomeScreen()),
                (route) => false,
              );
              return; // Exit early
            }
          }

          // If not found in Hive, check Firebase
          final firebaseService = ref.read(firebaseServiceProvider);
          final userProfile = await firebaseService.getUserProfile();
          Logger.d('AuthScreen', 'User profile from Firebase: $userProfile');

          // Close the loading dialog
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          if (userProfile != null &&
              userProfile['onboardingCompleted'] == true) {
            Logger.d('AuthScreen',
                'Onboarding is completed, navigating to home screen');

            // Update Hive with the onboarding data from Firebase
            try {
              Logger.d('AuthScreen',
                  'Updating Hive with onboarding data from Firebase');
              final onboardingNotifier = ref.read(onboardingProvider.notifier);

              // Create a new OnboardingData object with the data from Firebase
              final onboardingData = OnboardingData()
                ..accountType = userProfile['accountType']
                ..displayName = userProfile['displayName']
                ..username = userProfile['username']
                ..birthday = userProfile['birthday']
                    ?.toDate() // Convert Timestamp to DateTime
                ..phoneNumber = userProfile['phoneNumber']
                ..profileImageUrl = userProfile['profileImageUrl']
                ..interests = List<String>.from(userProfile['interests'] ?? [])
                ..onboardingCompleted = true;

              // Save to Hive
              await onboardingNotifier.saveData(onboardingData);
              Logger.d('AuthScreen',
                  'Successfully updated Hive with onboarding data from Firebase');
            } catch (e) {
              Logger.d('AuthScreen', 'Error updating Hive: $e');
              // Continue even if there's an error updating Hive
            }

            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => const AuthenticatedHomeScreen()),
                (route) => false,
              );
            }
          } else {
            Logger.d('AuthScreen',
                'Onboarding is not completed, navigating to onboarding screen');
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            }
          }
        } catch (e) {
          Logger.d('AuthScreen',
              'Error checking onboarding status: $e');
          // Close the loading dialog if it's still open
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          // Fall back to checking the onboarding provider again
          // This is a safety check in case the first check missed something
          final onboardingState = ref.read(onboardingProvider);

          // Check if we have valid data in Hive one more time
          bool onboardingCompletedInHive = false;

          await onboardingState.when(
            data: (data) async {
              if (data.isComplete()) {
                onboardingCompletedInHive = true;
                Logger.d('AuthScreen',
                    'Onboarding is completed in Hive (fallback check): ${data.toString()}');
              }
            },
            loading: () {
              Logger.d(
                  'AuthScreen', 'Onboarding data is still loading from Hive');
            },
            error: (error, stack) {
              Logger.d('AuthScreen',
                  'Error loading onboarding data from Hive: $error');
            },
          );

          if (onboardingCompletedInHive && context.mounted) {
            // If onboarding is completed in Hive, navigate to home screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const AuthenticatedHomeScreen()),
              (route) => false,
            );
          } else if (context.mounted) {
            // If not completed or error, navigate to onboarding screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              (route) => false,
            );
          }
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
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return AuthPageTemplate(
      title: "First Let's\nSign-In to Verify\nYour Account",
      body: GestureDetector(
        onTap: () => _handleGoogleSignIn(context, ref),
        child: Image.asset(
          isDark
              ? 'assets/light/signin_with_google_dark.png'
              : 'assets/dark/signin_with_google_light.png',
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
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: _buildTermsAndPolicyText(context),
        ),
      ],
    );
  }

  Widget _buildTermsAndPolicyText(BuildContext context) {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            const TextSpan(text: 'By continuing to sign up, you agree to the '),
            TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(
                  color: Colors.blue, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PdfViewerScreen(
                        title: 'Privacy Policy',
                        assetPath: 'assets/pdf/PrivacyPolicy.pdf',
                      ),
                    ),
                  );
                },
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Terms & Conditions',
              style: const TextStyle(
                  color: Colors.blue, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PdfViewerScreen(
                        title: 'Terms & Conditions',
                        assetPath: 'assets/pdf/Terms&Conditions.pdf',
                      ),
                    ),
                  );
                },
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
