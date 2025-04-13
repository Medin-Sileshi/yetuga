import 'package:hive/hive.dart';
import 'package:yetuga/utils/logger.dart';

part 'business_onboarding_data.g.dart';

@HiveType(typeId: 1)
class BusinessOnboardingData extends HiveObject {
  @HiveField(0)
  String? accountType;

  @HiveField(1)
  String? businessName;

  @HiveField(2)
  DateTime? establishedDate;

  @HiveField(3)
  String? phoneNumber;

  @HiveField(4)
  String? profileImageUrl;

  @HiveField(5)
  List<String>? businessTypes;

  @HiveField(6)
  String? username;

  @HiveField(7)
  bool onboardingCompleted = false;

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
    // If onboardingCompleted is explicitly set to true (from Firebase), return true
    if (onboardingCompleted) {
      // Onboarding is already marked as completed
      return true;
    }

    // Otherwise, check if all fields are filled
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
        'isComplete: ${isComplete()}'
        '}';
  }
}
