import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_onboarding_data.dart';
import 'base_form_notifier.dart';
import '../utils/logger.dart';

/// Provider that stores business onboarding form data in memory only
/// This avoids the need to save to Hive after each step
final businessOnboardingFormProvider =
    StateNotifierProvider<BusinessOnboardingFormNotifier, BusinessOnboardingData>((ref) {
  return BusinessOnboardingFormNotifier();
});

class BusinessOnboardingFormNotifier extends BaseFormNotifier<BusinessOnboardingData> {
  BusinessOnboardingFormNotifier() : super(BusinessOnboardingData(), 'BusinessForm');

  @override
  void updateField(String fieldName, dynamic value) {
    // Create a new state object with all existing values
    final updatedData = BusinessOnboardingData()
      ..accountType = state.accountType
      ..businessName = state.businessName
      ..username = state.username
      ..establishedDate = state.establishedDate
      ..phoneNumber = state.phoneNumber
      ..profileImageUrl = state.profileImageUrl
      ..businessTypes = state.businessTypes
      ..onboardingCompleted = state.onboardingCompleted;

    // Update the specific field
    switch (fieldName) {
      case 'accountType':
        updatedData.accountType = value as String;
        break;
      case 'businessName':
        updatedData.businessName = value as String;
        break;
      case 'username':
        updatedData.username = value as String;
        break;
      case 'establishedDate':
        updatedData.establishedDate = value as DateTime;
        break;
      case 'phoneNumber':
        updatedData.phoneNumber = value as String;
        break;
      case 'profileImageUrl':
        updatedData.profileImageUrl = value as String;
        break;
      case 'businessTypes':
        updatedData.businessTypes = value as List<String>;
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

  void setBusinessName(String name) {
    updateField('businessName', name);
  }

  void setUsername(String username) {
    updateField('username', username);
  }

  void setEstablishedDate(DateTime date) {
    updateField('establishedDate', date);
  }

  void setPhoneNumber(String phone) {
    updateField('phoneNumber', phone);
  }

  void setProfileImage(String imageUrl) {
    updateField('profileImageUrl', imageUrl);
  }

  void setBusinessTypes(List<String> types) {
    updateField('businessTypes', types);
  }

  void setOnboardingCompleted(bool completed) {
    updateField('onboardingCompleted', completed);
  }

  @override
  void reset() {
    state = BusinessOnboardingData();
  }
}
