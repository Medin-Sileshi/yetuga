import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/providers/onboarding_provider.dart';
import 'package:yetuga/screens/onboarding/onboarding_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/auth_page_template.dart';
import 'email_signin_screen.dart';
import '../home_screen.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();

      // if (userCredential != null && context.mounted) {
      //   Navigator.of(context).pushReplacement(
      //     MaterialPageRoute(builder: (context) => const HomeScreen()),
      //   );
      // }

      if (userCredential != null && context.mounted) {
        // Check onboarding status and navigate accordingly
        final onboardingState = ref.read(onboardingProvider);
        if (onboardingState.isComplete) {
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
      }
    } catch (e) {
      if (context.mounted) {
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
