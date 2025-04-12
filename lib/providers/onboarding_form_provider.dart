import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/onboarding_data.dart';

/// Provider that stores onboarding form data in memory only
/// This avoids the need to save to Hive after each step
final onboardingFormProvider =
    StateNotifierProvider<OnboardingFormNotifier, OnboardingData>((ref) {
  return OnboardingFormNotifier();
});

class OnboardingFormNotifier extends StateNotifier<OnboardingData> {
  OnboardingFormNotifier() : super(OnboardingData());

  void setAccountType(String type) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = type
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
    print('DEBUG: Account type updated in provider: ${state.accountType}');
  }

  void setDisplayName(String name) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = name
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
    print('DEBUG: Display name updated in provider: ${state.displayName}');
  }

  void setUsername(String username) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
    print('DEBUG: Username updated in provider: ${state.username}');
  }

  void setBirthday(DateTime birthday) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
  }

  void setPhoneNumber(String phone) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = phone
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
    print('DEBUG: Phone number updated in provider: ${state.phoneNumber}');
  }

  void setProfileImage(String imageUrl) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = imageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
  }

  void setInterests(List<String> interests) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = interests
      ..onboardingCompleted = state.onboardingCompleted;

    state = updatedData;
  }

  void setOnboardingCompleted(bool completed) {
    // Create a new state object to ensure the UI updates
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = completed;

    state = updatedData;
    print('DEBUG: onboardingCompleted updated in provider: ${state.onboardingCompleted}');
  }

  void reset() {
    state = OnboardingData();
  }
}
