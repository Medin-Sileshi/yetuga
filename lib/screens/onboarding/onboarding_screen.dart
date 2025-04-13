import 'dart:async';
import 'package:yetuga/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/onboarding_template.dart';
import 'steps/account_type_step.dart';
import 'steps/display_name_step.dart';
import 'steps/birthday_step.dart';
import 'steps/phone_step.dart';
import 'steps/profile_image_step.dart';
import 'steps/interests_step.dart';
import 'steps/established_in_step.dart';
import 'steps/business_type_step.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/onboarding_form_provider.dart';
import '../../providers/business_onboarding_form_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../screens/home_screen.dart';
import '../../utils/logger.dart';
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

  // Logger tag for this class
  final String _logTag = 'OnboardingScreen';
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
      Logger.d(_logTag, 'Syncing with Firebase...');
      await ref.read(onboardingProvider.notifier).syncWithFirebase();
      Logger.d(_logTag, 'Sync with Firebase completed');
    } catch (e) {
      Logger.e(_logTag, 'Error syncing with Firebase', e);
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      // Save data before navigating to the next page
      _saveCurrentPageData();

      // Debug log the current form data
      final formData = ref.read(onboardingFormProvider);
      Logger.d(_logTag, 'Moving to next page. Current data:');
      Logger.d(_logTag, 'Account Type: ${formData.accountType}');
      Logger.d(_logTag, 'Display Name: ${formData.displayName}');
      Logger.d(_logTag, 'Username: ${formData.username}');
      Logger.d(_logTag, 'Birthday: ${formData.birthday}');
      Logger.d(_logTag, 'Phone Number: ${formData.phoneNumber}');
      Logger.d(_logTag, 'Profile Image: ${formData.profileImageUrl}');
      Logger.d(_logTag, 'Interests: ${formData.interests}');

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
      final accountType = formData.accountType;
      final isBusiness = accountType == 'business';

      // For business accounts, we need to get the business form data
      var businessFormData = isBusiness ? ref.read(businessOnboardingFormProvider) : null;

      // Debug log the form data
      Logger.d('OnboardingScreen', 'Submitting onboarding data:');
      Logger.d('OnboardingScreen', 'Account Type: ${formData.accountType}');
      Logger.d('OnboardingScreen', 'Display Name: ${formData.displayName}');
      Logger.d('OnboardingScreen', 'Username: ${formData.username}');
      Logger.d('OnboardingScreen', 'Birthday: ${formData.birthday}');
      Logger.d('OnboardingScreen', 'Phone Number: ${formData.phoneNumber}');
      Logger.d('OnboardingScreen', 'Profile Image: ${formData.profileImageUrl}');
      Logger.d('OnboardingScreen', 'Interests: ${formData.interests}');
      Logger.d('OnboardingScreen', 'Is Complete: ${formData.isComplete()}');

      if (isBusiness && businessFormData != null) {
        Logger.d('OnboardingScreen', 'Business Form Data:');
        Logger.d('OnboardingScreen', 'Business Name: ${businessFormData.businessName}');
        Logger.d('OnboardingScreen', 'Established Date: ${businessFormData.establishedDate}');
        Logger.d('OnboardingScreen', 'Business Types: ${businessFormData.businessTypes}');
      }

      // Check if form is complete
      if (isBusiness) {
        if (businessFormData == null) {
          Logger.e('OnboardingScreen', 'Business form data is null!');
          throw Exception('Please complete all steps');
        }

        // Log business form data
        Logger.d('OnboardingScreen', 'Business form data:');
        Logger.d('OnboardingScreen', 'accountType: ${businessFormData.accountType}');
        Logger.d('OnboardingScreen', 'businessName: ${businessFormData.businessName}');
        Logger.d('OnboardingScreen', 'username: ${businessFormData.username}');
        Logger.d('OnboardingScreen', 'establishedDate: ${businessFormData.establishedDate}');
        Logger.d('OnboardingScreen', 'phoneNumber: ${businessFormData.phoneNumber}');
        Logger.d('OnboardingScreen', 'profileImageUrl: ${businessFormData.profileImageUrl}');
        Logger.d('OnboardingScreen', 'businessTypes: ${businessFormData.businessTypes}');
        Logger.d('OnboardingScreen', 'isComplete: ${businessFormData.isComplete()}');

        // Make sure the account type is set in the business form provider
        if (businessFormData.accountType == null || businessFormData.accountType != 'business') {
          Logger.d('OnboardingScreen', 'Setting account type in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setAccountType('business');
        }

        // Make sure the business name is set in the business form provider
        if (businessFormData.businessName == null && formData.displayName != null) {
          Logger.d('OnboardingScreen', 'Setting business name in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setBusinessName(formData.displayName!);
        }

        // Make sure the username is set in the business form provider
        if (businessFormData.username == null && formData.username != null) {
          Logger.d('OnboardingScreen', 'Setting username in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setUsername(formData.username!);
        }

        // Make sure the established date is set in the business form provider
        if (businessFormData.establishedDate == null && formData.birthday != null) {
          Logger.d('OnboardingScreen', 'Setting established date in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setEstablishedDate(formData.birthday!);
        }

        // Make sure the phone number is set in the business form provider
        if (businessFormData.phoneNumber == null && formData.phoneNumber != null) {
          Logger.d('OnboardingScreen', 'Setting phone number in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setPhoneNumber(formData.phoneNumber!);
        }

        // Make sure the profile image is set in the business form provider
        if (businessFormData.profileImageUrl == null && formData.profileImageUrl != null) {
          Logger.d('OnboardingScreen', 'Setting profile image in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setProfileImage(formData.profileImageUrl!);
        }

        // Make sure the business types are set in the business form provider
        if ((businessFormData.businessTypes == null || businessFormData.businessTypes!.isEmpty) &&
            formData.interests != null && formData.interests!.isNotEmpty) {
          Logger.d('OnboardingScreen', 'Setting business types in business form provider');
          ref.read(businessOnboardingFormProvider.notifier).setBusinessTypes(formData.interests!);
        }

        // Check again if the form is complete
        businessFormData = ref.read(businessOnboardingFormProvider);
        if (!businessFormData.isComplete()) {
          Logger.d('OnboardingScreen', 'Business form is still incomplete!');
          Logger.d('OnboardingScreen', 'accountType: ${businessFormData.accountType}');
          Logger.d('OnboardingScreen', 'businessName: ${businessFormData.businessName}');
          Logger.d('OnboardingScreen', 'username: ${businessFormData.username}');
          Logger.d('OnboardingScreen', 'establishedDate: ${businessFormData.establishedDate}');
          Logger.d('OnboardingScreen', 'phoneNumber: ${businessFormData.phoneNumber}');
          Logger.d('OnboardingScreen', 'profileImageUrl: ${businessFormData.profileImageUrl}');
          Logger.d('OnboardingScreen', 'businessTypes: ${businessFormData.businessTypes}');
          throw Exception('Please complete all steps');
        }
      } else {
        if (!formData.isComplete()) {
          Logger.d('OnboardingScreen', 'Personal form is incomplete!');
          throw Exception('Please complete all steps');
        }
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
      Logger.d('OnboardingScreen', 'Saving to Firebase and Hive');

      // Save to Hive first
      try {
        Logger.d('OnboardingScreen', 'Saving to Hive...');
        await ref.read(onboardingProvider.notifier).saveData(formData);
        Logger.d('OnboardingScreen', 'Successfully saved to Hive');
      } catch (e) {
        Logger.d('OnboardingScreen', 'Error saving to Hive: $e');
        throw Exception('Failed to save to Hive: $e');
      }

      // Then save to Firebase
      try {
        Logger.d('OnboardingScreen', 'Saving to Firebase...');

        if (isBusiness && businessFormData != null) {
          // For business accounts
          Logger.d('OnboardingScreen', 'Saving business data to Firebase');
          await firebaseService.saveUserProfile(
            accountType: businessFormData.accountType,
            displayName: businessFormData.businessName,
            username: businessFormData.username,
            phoneNumber: businessFormData.phoneNumber,
            profileImageUrl: businessFormData.profileImageUrl,
            establishedDate: businessFormData.establishedDate,
            businessTypes: businessFormData.businessTypes,
          );
        } else {
          // For personal accounts
          Logger.d('OnboardingScreen', 'Saving personal data to Firebase');
          await firebaseService.saveUserProfile(
            accountType: formData.accountType,
            displayName: formData.displayName,
            username: formData.username,
            birthday: formData.birthday,
            phoneNumber: formData.phoneNumber,
            profileImageUrl: formData.profileImageUrl,
            interests: formData.interests,
          );
        }

        Logger.d('OnboardingScreen', 'Successfully saved to Firebase');
      } catch (e) {
        Logger.d('OnboardingScreen', 'Error saving to Firebase: $e');
        throw Exception('Failed to save to Firebase: $e');
      }

      Logger.d('OnboardingScreen', 'Successfully saved to both Firebase and Hive');

      // Set onboardingCompleted to true in the form data
      ref.read(onboardingFormProvider.notifier).setOnboardingCompleted(true);
      if (isBusiness && businessFormData != null) {
        ref.read(businessOnboardingFormProvider.notifier).setOnboardingCompleted(true);
      }

      // Get the updated form data with onboardingCompleted = true
      final updatedFormData = ref.read(onboardingFormProvider);

      // Save the updated data with onboardingCompleted = true
      await ref.read(onboardingProvider.notifier).saveData(updatedFormData);

      // Reset form data
      ref.read(onboardingFormProvider.notifier).reset();
      if (isBusiness) {
        ref.read(businessOnboardingFormProvider.notifier).reset();
      }

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
      Logger.d('OnboardingScreen', 'Error in _submitOnboarding: $e');

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

    Logger.d('OnboardingScreen', '_updateValidityState called with field: $field, value: $value');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        switch (field) {
          case 'displayName':
            _isDisplayNameValid = value;
            Logger.d('OnboardingScreen', '_isDisplayNameValid updated to: $value');
            break;
          case 'phone':
            _isPhoneValid = value;
            Logger.d('OnboardingScreen', '_isPhoneValid updated to: $value');
            break;
          case 'profileImage':
            _isProfileImageValid = value;
            Logger.d('OnboardingScreen', '_isProfileImageValid updated to: $value');
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
    Logger.d('OnboardingScreen', 'Build - Current page: $_currentPage');
    Logger.d('OnboardingScreen', 'Build - Account Type: ${formData.accountType}');
    Logger.d('OnboardingScreen', 'Build - Display Name: ${formData.displayName}');
    Logger.d('OnboardingScreen', 'Build - Username: ${formData.username}');
    Logger.d('OnboardingScreen', 'Build - Birthday: ${formData.birthday}');
    Logger.d('OnboardingScreen', 'Build - Phone Number: ${formData.phoneNumber}');
    Logger.d('OnboardingScreen', 'Build - Profile Image: ${formData.profileImageUrl}');
    Logger.d('OnboardingScreen', 'Build - Interests: ${formData.interests}');

    // Check if the account type is set and we're on the first page
    if (_currentPage == 0 && formData.accountType != null && formData.accountType!.isNotEmpty) {
      Logger.d('OnboardingScreen', 'Account type is set on page 0: ${formData.accountType}');
    }

    // Check if the display name and username are set and we're on the second page
    if (_currentPage == 1) {
      Logger.d('OnboardingScreen', 'On display name page - Display name: ${formData.displayName}');
      Logger.d('OnboardingScreen', 'On display name page - Username: ${formData.username}');
      Logger.d('OnboardingScreen', 'On display name page - _isDisplayNameValid: $_isDisplayNameValid');
    }

    // Check if the phone number is set and we're on the fourth page
    if (_currentPage == 3) {
      Logger.d('OnboardingScreen', 'On phone page - Phone number: ${formData.phoneNumber}');
      Logger.d('OnboardingScreen', 'On phone page - _isPhoneValid: $_isPhoneValid');
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
          Logger.d('OnboardingScreen', 'onNext button pressed on page $_currentPage');
          Logger.d('OnboardingScreen', '_isDisplayNameValid: $_isDisplayNameValid');
          Logger.d('OnboardingScreen', '_isPhoneValid: $_isPhoneValid');
          Logger.d('OnboardingScreen', '_isProfileImageValid: $_isProfileImageValid');
          Logger.d('OnboardingScreen', 'formData.accountType: ${formData.accountType}');
          Logger.d('OnboardingScreen', 'formData.displayName: ${formData.displayName}');
          Logger.d('OnboardingScreen', 'formData.username: ${formData.username}');
          Logger.d('OnboardingScreen', 'formData.birthday: ${formData.birthday}');
          Logger.d('OnboardingScreen', 'formData.phoneNumber: ${formData.phoneNumber}');
          Logger.d('OnboardingScreen', 'formData.profileImageUrl: ${formData.profileImageUrl}');
          Logger.d('OnboardingScreen', 'formData.interests: ${formData.interests}');

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
    // Get the account type to determine which steps to show
    final formData = ref.read(onboardingFormProvider);
    final accountType = formData.accountType;
    final isBusiness = accountType == 'business';

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
        // Use EstablishedInStep for business accounts, BirthdayStep for personal accounts
        return isBusiness
            ? EstablishedInStep(
                onNext: _nextPage,
                onBack: _previousPage,
              )
            : BirthdayStep(
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
        // Use BusinessTypeStep for business accounts, InterestsStep for personal accounts
        return isBusiness
            ? BusinessTypeStep(
                onNext: _submitOnboarding,
                onBack: _previousPage,
              )
            : InterestsStep(
                onNext: _submitOnboarding,
                onBack: _previousPage,
              );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStepTitle(int step) {
    // Get the account type to determine which titles to show
    final formData = ref.read(onboardingFormProvider);
    final accountType = formData.accountType;
    final isBusiness = accountType == 'business';

    switch (step) {
      case 0:
        return 'Choose Account Type';
      case 1:
        return isBusiness ? 'What\'s the name of your Business?' : 'Create Your Profile';
      case 2:
        return isBusiness ? 'When was your business established?' : 'When Were You Born?';
      case 3:
        return isBusiness ? 'What\'s the primary number to your business?' : 'Verify Your Phone';
      case 4:
        return isBusiness ? 'Upload an image to represent your business' : 'Add Profile Picture';
      case 5:
        return isBusiness ? 'What services do you offer?' : 'Select Your Interests';
      default:
        return '';
    }
  }

  bool _isNextButtonEnabled() {
    final formData = ref.read(onboardingFormProvider);
    final accountType = formData.accountType;
    final isBusiness = accountType == 'business';

    // For business accounts, we need to check the business form provider for some steps
    final businessFormData = isBusiness ? ref.read(businessOnboardingFormProvider) : null;

    switch (_currentPage) {
      case 0: // Account Type Step
        return formData.accountType != null && formData.accountType!.isNotEmpty;
      case 1: // Display Name Step
        return _isDisplayNameValid;
      case 2: // Birthday Step (personal) or Established In Step (business)
        if (isBusiness) {
          return businessFormData?.establishedDate != null;
        } else {
          return formData.birthday != null;
        }
      case 3: // Phone Step
        return _isPhoneValid;
      case 4: // Profile Image Step
        return _isProfileImageValid;
      case 5: // Interests Step (personal) or Business Type Step (business)
        if (isBusiness) {
          return businessFormData?.businessTypes != null && businessFormData!.businessTypes!.isNotEmpty;
        } else {
          return formData.interests != null && formData.interests!.isNotEmpty;
        }
      default:
        return false;
    }
  }


}
