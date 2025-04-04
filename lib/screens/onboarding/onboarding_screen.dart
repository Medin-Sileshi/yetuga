import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/auth_provider.dart';
import 'steps/account_type_step.dart';
import 'steps/display_name_step.dart';
import 'steps/birthday_step.dart';
import 'steps/phone_step.dart';
import 'steps/profile_image_step.dart';
import 'steps/interests_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await ref.read(authProvider.notifier).signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          AccountTypeStep(onNext: _nextPage),
          DisplayNameStep(onNext: _nextPage, onBack: _previousPage),
          BirthdayStep(onNext: _nextPage, onBack: _previousPage),
          PhoneStep(onNext: _nextPage, onBack: _previousPage),
          ProfileImageStep(onNext: _nextPage, onBack: _previousPage),
          InterestsStep(
            onNext: () {
              // Handle completion
              ref.read(onboardingProvider.notifier).resetOnboarding();
            },
            onBack: _previousPage,
          ),
        ],
      ),
    );
  }
}
