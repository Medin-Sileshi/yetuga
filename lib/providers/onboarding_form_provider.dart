import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/utils/logger.dart';
import '../models/onboarding_data.dart';
import 'base_form_notifier.dart';

/// Provider that stores onboarding form data in memory only
/// This avoids the need to save to Hive after each step
final onboardingFormProvider =
    StateNotifierProvider<OnboardingFormNotifier, OnboardingData>((ref) {
  return OnboardingFormNotifier();
});

class OnboardingFormNotifier extends BaseFormNotifier<OnboardingData> {
  OnboardingFormNotifier() : super(OnboardingData(), 'OnboardingForm');

  @override
  void updateField(String fieldName, dynamic value) {
    // Create a new state object with all existing values
    final updatedData = OnboardingData()
      ..accountType = state.accountType
      ..displayName = state.displayName
      ..username = state.username
      ..birthday = state.birthday
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..interests = state.interests
      ..onboardingCompleted = state.onboardingCompleted;

    // Update the specific field
    switch (fieldName) {
      case 'accountType':
        updatedData.accountType = value as String;
        break;
      case 'displayName':
        updatedData.displayName = value as String;
        break;
      case 'username':
        updatedData.username = value as String;
        break;
      case 'birthday':
        updatedData.birthday = value as DateTime;
        break;
      case 'phoneNumber':
        updatedData.phoneNumber = value as String;
        break;
      case 'profileImageUrl':
        updatedData.profileImageUrl = value as String;
        break;
      case 'interests':
        updatedData.interests = value as List<String>;
        break;
      case 'onboardingCompleted':
        updatedData.onboardingCompleted = value as bool;
        break;
    }

    state = updatedData;
    logUpdate(fieldName, value);
  }

  // Convenience methods to make the API cleaner
  void setAccountType(String type) {
    updateField('accountType', type);
  }

  void setDisplayName(String name) {
    updateField('displayName', name);
  }

  void setUsername(String username) {
    updateField('username', username);
  }

  void setBirthday(DateTime birthday) {
    updateField('birthday', birthday);
  }

  void setPhoneNumber(String phone) {
    updateField('phoneNumber', phone);
  }

  void setProfileImage(String imageUrl) {
    updateField('profileImageUrl', imageUrl);
  }

  void setInterests(List<String> interests) {
    updateField('interests', interests);
  }

  void setOnboardingCompleted(bool completed) {
    updateField('onboardingCompleted', completed);
  }

  @override
  void reset() {
    state = OnboardingData();
  }
}
