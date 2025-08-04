import 'package:hive/hive.dart';
import 'onboarding_data.dart';

part 'business_onboarding_data.g.dart';

@HiveType(typeId: 1)
class BusinessOnboardingData extends OnboardingData {
  @HiveField(8)
  String? businessName;

  @HiveField(9)
  DateTime? establishedDate;

  @HiveField(10)
  List<String>? businessTypes;

  @HiveField(11)
  bool verified = false;

  BusinessOnboardingData({
    String? accountType,
    this.businessName,
    this.establishedDate,
    String? phoneNumber,
    String? profileImageUrl,
    this.businessTypes,
    String? username,
    String? displayName,
    DateTime? birthday,
    List<String>? interests,
    bool onboardingCompleted = false,
    this.verified = false,
  }) : super() {
    this.accountType = accountType;
    this.username = username;
    this.displayName = displayName;
    this.birthday = birthday;
    this.phoneNumber = phoneNumber;
    this.profileImageUrl = profileImageUrl;
    this.interests = interests;
    this.onboardingCompleted = onboardingCompleted;
  }

  void setVerified(bool value) {
    verified = value;
  }

  bool isStepComplete(int step) {
    switch (step) {
      case 0:
        return accountType != null;
      case 1:
        return businessName != null &&
            businessName!.isNotEmpty &&
            username != null &&
            username!.isNotEmpty;
      case 2:
        return establishedDate != null;
      case 3:
        return phoneNumber != null && phoneNumber!.isNotEmpty;
      case 4:
        return profileImageUrl != null;
      case 5:
        return businessTypes != null && businessTypes!.isNotEmpty;
      default:
        return false;
    }
  }

  bool isComplete() {
    if (onboardingCompleted) {
      return true;
    }
    final complete = accountType != null &&
        businessName != null &&
        username != null &&
        establishedDate != null &&
        phoneNumber != null &&
        profileImageUrl != null &&
        businessTypes != null &&
        businessTypes!.isNotEmpty;
    return complete;
  }

  @override
  String toString() {
    return 'BusinessOnboardingData{'
        'accountType: $accountType, '
        'businessName: $businessName, '
        'username: $username, '
        'establishedDate: $establishedDate, '
        'phoneNumber: $phoneNumber, '
        'profileImageUrl: $profileImageUrl, '
        'businessTypes: $businessTypes, '
        'onboardingCompleted: $onboardingCompleted, '
        'verified: $verified, '
        'isComplete: ${isComplete()}'
        '}';
  }
}
