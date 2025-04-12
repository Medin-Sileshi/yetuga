import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/onboarding_template.dart';
import 'steps/account_type_step.dart';
import 'steps/display_name_step.dart';
import 'steps/birthday_step.dart';
import 'steps/phone_step.dart';
import 'steps/profile_image_step.dart';
import 'steps/interests_step.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/onboarding_form_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../screens/home_screen.dart';
import '../../screens/auth/auth_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentPage = 0;
  final int _totalPages = 6;
  bool _isDisplayNameValid = false;
  bool _isPhoneValid = false;
  bool _isProfileImageValid = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Sync with Firebase when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithFirebase();
    });
  }

  // Method to sync with Firebase
  Future<void> _syncWithFirebase() async {
    try {
      print('DEBUG: OnboardingScreen: Syncing with Firebase...');
      await ref.read(onboardingProvider.notifier).syncWithFirebase();
      print('DEBUG: OnboardingScreen: Sync with Firebase completed');
    } catch (e) {
      print('DEBUG: OnboardingScreen: Error syncing with Firebase: $e');
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      // Save data before navigating to the next page
      _saveCurrentPageData();

      // Debug log the current form data
      final formData = ref.read(onboardingFormProvider);
      print('DEBUG: Moving to next page. Current data:');
      print('DEBUG: Account Type: ${formData.accountType}');
      print('DEBUG: Display Name: ${formData.displayName}');
      print('DEBUG: Username: ${formData.username}');
      print('DEBUG: Birthday: ${formData.birthday}');
      print('DEBUG: Phone Number: ${formData.phoneNumber}');
      print('DEBUG: Profile Image: ${formData.profileImageUrl}');
      print('DEBUG: Interests: ${formData.interests}');

      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  Future<void> _saveCurrentPageData() async {
    final onboardingData = ref.read(onboardingProvider).value;
    if (onboardingData != null) {
      // Save data
      await ref.read(onboardingProvider.notifier).saveData(onboardingData);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      final auth = ref.read(authProvider.notifier);
      await auth.signOut();
      if (mounted) {
        // Navigate back to auth screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _submitOnboarding() async {
    // Set submitting state to show loading indicator
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get form data
      final formData = ref.read(onboardingFormProvider);

      // Debug log the form data
      print('DEBUG: Submitting onboarding data:');
      print('DEBUG: Account Type: ${formData.accountType}');
      print('DEBUG: Display Name: ${formData.displayName}');
      print('DEBUG: Username: ${formData.username}');
      print('DEBUG: Birthday: ${formData.birthday}');
      print('DEBUG: Phone Number: ${formData.phoneNumber}');
      print('DEBUG: Profile Image: ${formData.profileImageUrl}');
      print('DEBUG: Interests: ${formData.interests}');
      print('DEBUG: Is Complete: ${formData.isComplete()}');

      // Check if form is complete
      if (!formData.isComplete()) {
        print('DEBUG: Form is incomplete!');
        throw Exception('Please complete all steps');
      }

      // Get services
      final firebaseService = ref.read(firebaseServiceProvider);
      final authState = ref.read(authProvider);

      if (authState.value == null) {
        throw Exception('No user found');
      }

      // Ensure user is authenticated
      authState.value!;

      // Save to both Firebase and Hive simultaneously
      print('DEBUG: Saving to Firebase and Hive');

      // Save to Hive first
      try {
        print('DEBUG: Saving to Hive...');
        await ref.read(onboardingProvider.notifier).saveData(formData);
        print('DEBUG: Successfully saved to Hive');
      } catch (e) {
        print('DEBUG: Error saving to Hive: $e');
        throw Exception('Failed to save to Hive: $e');
      }

      // Then save to Firebase
      try {
        print('DEBUG: Saving to Firebase...');
        print('DEBUG: Phone number being sent to Firebase: ${formData.phoneNumber}');
        await firebaseService.saveUserProfile(
          accountType: formData.accountType,
          displayName: formData.displayName,
          username: formData.username,
          birthday: formData.birthday,
          phoneNumber: formData.phoneNumber,
          profileImageUrl: formData.profileImageUrl,
          interests: formData.interests,
        );
        print('DEBUG: Successfully saved to Firebase');
      } catch (e) {
        print('DEBUG: Error saving to Firebase: $e');
        throw Exception('Failed to save to Firebase: $e');
      }

      print('DEBUG: Successfully saved to both Firebase and Hive');

      // Set onboardingCompleted to true in the form data
      ref.read(onboardingFormProvider.notifier).setOnboardingCompleted(true);

      // Get the updated form data with onboardingCompleted = true
      final updatedFormData = ref.read(onboardingFormProvider);

      // Save the updated data with onboardingCompleted = true
      await ref.read(onboardingProvider.notifier).saveData(updatedFormData);

      // Reset form data
      ref.read(onboardingFormProvider.notifier).reset();

      // Reset submitting state
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('DEBUG: Error in _submitOnboarding: $e');

      // Reset submitting state
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Helper method to safely update state after the build phase
  void _updateValidityState(String field, bool value) {
    if (!mounted) return;

    print('DEBUG: _updateValidityState called with field: $field, value: $value');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        switch (field) {
          case 'displayName':
            _isDisplayNameValid = value;
            print('DEBUG: _isDisplayNameValid updated to: $value');
            break;
          case 'phone':
            _isPhoneValid = value;
            print('DEBUG: _isPhoneValid updated to: $value');
            break;
          case 'profileImage':
            _isProfileImageValid = value;
            print('DEBUG: _isProfileImageValid updated to: $value');
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch both providers to react to changes
    final onboardingData = ref.watch(onboardingProvider);
    final formData = ref.watch(onboardingFormProvider);

    // Debug log the current form data on each build
    print('DEBUG: Build - Current page: $_currentPage');
    print('DEBUG: Build - Account Type: ${formData.accountType}');
    print('DEBUG: Build - Display Name: ${formData.displayName}');
    print('DEBUG: Build - Username: ${formData.username}');
    print('DEBUG: Build - Birthday: ${formData.birthday}');
    print('DEBUG: Build - Phone Number: ${formData.phoneNumber}');
    print('DEBUG: Build - Profile Image: ${formData.profileImageUrl}');
    print('DEBUG: Build - Interests: ${formData.interests}');

    // Check if the account type is set and we're on the first page
    if (_currentPage == 0 && formData.accountType != null && formData.accountType!.isNotEmpty) {
      print('DEBUG: Account type is set on page 0: ${formData.accountType}');
    }

    // Check if the display name and username are set and we're on the second page
    if (_currentPage == 1) {
      print('DEBUG: On display name page - Display name: ${formData.displayName}');
      print('DEBUG: On display name page - Username: ${formData.username}');
      print('DEBUG: On display name page - _isDisplayNameValid: $_isDisplayNameValid');
    }

    // Check if the phone number is set and we're on the fourth page
    if (_currentPage == 3) {
      print('DEBUG: On phone page - Phone number: ${formData.phoneNumber}');
      print('DEBUG: On phone page - _isPhoneValid: $_isPhoneValid');
    }

    // Watch theme provider for changes
    ref.watch(themeProvider);

    return onboardingData.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (data) => OnboardingTemplate(
        title: _getStepTitle(_currentPage),
        currentStep: _currentPage + 1,
        totalSteps: _totalPages,
        isNextEnabled: _isNextButtonEnabled(),
        onNext: () {
          print('DEBUG: onNext button pressed on page $_currentPage');
          print('DEBUG: _isDisplayNameValid: $_isDisplayNameValid');
          print('DEBUG: _isPhoneValid: $_isPhoneValid');
          print('DEBUG: _isProfileImageValid: $_isProfileImageValid');
          print('DEBUG: formData.accountType: ${formData.accountType}');
          print('DEBUG: formData.displayName: ${formData.displayName}');
          print('DEBUG: formData.username: ${formData.username}');
          print('DEBUG: formData.birthday: ${formData.birthday}');
          print('DEBUG: formData.phoneNumber: ${formData.phoneNumber}');
          print('DEBUG: formData.profileImageUrl: ${formData.profileImageUrl}');
          print('DEBUG: formData.interests: ${formData.interests}');

          // If we're already submitting, don't do anything
          if (_isSubmitting) {
            return;
          }

          if (_currentPage == 0) {
            if (formData.accountType != null && formData.accountType!.isNotEmpty) {
              _nextPage();
            }
          } else if (_currentPage == 1) {
            // For display name step, check if the data is valid and move to the next page
            if (_isDisplayNameValid &&
                formData.displayName != null && formData.displayName!.isNotEmpty &&
                formData.username != null && formData.username!.isNotEmpty) {
              _nextPage();
            }
          } else if (_currentPage == 2) {
            if (formData.birthday != null) {
              _nextPage();
            }
          } else if (_currentPage == 3) {
            // For phone step, check if the data is valid and move to the next page
            if (_isPhoneValid &&
                formData.phoneNumber != null && formData.phoneNumber!.isNotEmpty) {
              _nextPage();
            }
          } else if (_currentPage == 4) {
            if (_isProfileImageValid) {
              _nextPage();
            }
          } else if (_currentPage == 5) {
            if (formData.interests != null && formData.interests!.isNotEmpty) {
              _submitOnboarding();
            }
          }
        },
        onBack: _currentPage > 0 ? _previousPage : null,
        onLogout: _currentPage == 0 ? _handleSignOut : null,
        onThemeToggle: () {
          ref.read(themeProvider.notifier).toggleTheme();
        },
        content: Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _buildCurrentPage(),
            ),
            if (_isSubmitting && _currentPage == 5)
              Container(
                height: MediaQuery.of(context).size.height * 0.5,
                color: Colors.black.withAlpha(77), // 0.3 opacity
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Saving your profile...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return AccountTypeStep(
          onNext: _nextPage,
          onBack: _handleSignOut,
          backButtonLabel: 'Sign Out',
        );
      case 1:
        return DisplayNameStep(
          onNext: () {
            // This will be called by the DisplayNameStep's validateAndSave method
            // when the user clicks the Continue button in the step
            _nextPage();
          },
          onBack: _previousPage,
          onValidityChanged: (isValid) {
            _updateValidityState('displayName', isValid);
          },
        );
      case 2:
        return BirthdayStep(
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 3:
        return PhoneStep(
          onNext: _nextPage,
          onBack: _previousPage,
          onValidityChanged: (isValid) {
            _updateValidityState('phone', isValid);
          },
        );
      case 4:
        return ProfileImageStep(
          onNext: _nextPage,
          onValidityChanged: (isValid) {
            _updateValidityState('profileImage', isValid);
          },
        );
      case 5:
        return InterestsStep(
          onNext: _submitOnboarding,
          onBack: _previousPage,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Choose Account Type';
      case 1:
        return 'Create Your Profile';
      case 2:
        return 'When Were You Born?';
      case 3:
        return 'Verify Your Phone';
      case 4:
        return 'Add Profile Picture';
      case 5:
        return 'Select Your Interests';
      default:
        return '';
    }
  }

  bool _isNextButtonEnabled() {
    final formData = ref.read(onboardingFormProvider);

    switch (_currentPage) {
      case 0: // Account Type Step
        return formData.accountType != null && formData.accountType!.isNotEmpty;
      case 1: // Display Name Step
        return _isDisplayNameValid;
      case 2: // Birthday Step
        return formData.birthday != null;
      case 3: // Phone Step
        return _isPhoneValid;
      case 4: // Profile Image Step
        return _isProfileImageValid;
      case 5: // Interests Step
        return formData.interests != null && formData.interests!.isNotEmpty;
      default:
        return false;
    }
  }


}
