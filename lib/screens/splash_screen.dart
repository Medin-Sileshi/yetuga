import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_provider.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'auth/auth_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use a delay to ensure the widget is fully built
    Future.delayed(Duration.zero, () {
      _checkAuthStatus();
    });
  }

  void _checkAuthStatus() {
    try {
      print('DEBUG: SplashScreen: Checking auth status');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('DEBUG: SplashScreen: No user logged in');
        _navigateToAuthScreen();
      } else {
        print('DEBUG: SplashScreen: User is logged in: ${user.uid}');
        _checkOnboardingStatus();
      }
    } catch (e) {
      print('DEBUG: SplashScreen: Error checking auth status: $e');
      _showError('Error checking auth status: $e');
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      print('DEBUG: SplashScreen: Checking onboarding status');
      final firebaseService = ref.read(firebaseServiceProvider);
      final userProfile = await firebaseService.getUserProfile();

      print('DEBUG: SplashScreen: User profile: $userProfile');

      if (userProfile != null && userProfile['onboardingCompleted'] == true) {
        print('DEBUG: SplashScreen: Onboarding is complete');
        _navigateToHomeScreen();
      } else {
        print('DEBUG: SplashScreen: Onboarding is not complete');
        _navigateToOnboardingScreen();
      }
    } catch (e) {
      print('DEBUG: SplashScreen: Error checking onboarding status: $e');
      _showError('Error checking onboarding status: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  void _navigateToAuthScreen() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  void _navigateToHomeScreen() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _navigateToOnboardingScreen() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _checkAuthStatus();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
