import 'package:hive/hive.dart';

part 'onboarding_data.g.dart';

@HiveType(typeId: 0)
class OnboardingData extends HiveObject {
  @HiveField(0)
  String? accountType;

  @HiveField(1)
  String? displayName;

  @HiveField(2)
  DateTime? birthday;

  @HiveField(3)
  String? phoneNumber;

  @HiveField(4)
  String? profileImageUrl;

  @HiveField(5)
  List<String>? interests;

  @HiveField(6)
  String? username;

  @HiveField(7)
  bool onboardingCompleted = false;

  bool isStepComplete(int step) {
    switch (step) {
      case 0:
        return accountType != null;
      case 1:
        return displayName != null &&
            displayName!.isNotEmpty &&
            username != null &&
            username!.isNotEmpty;
      case 2:
        return birthday != null;
      case 3:
        return phoneNumber != null && phoneNumber!.isNotEmpty;
      case 4:
        return profileImageUrl != null;
      case 5:
        return interests != null && interests!.isNotEmpty;
      default:
        return false;
    }
  }

  bool isComplete() {
    // If onboardingCompleted is explicitly set to true (from Firebase), return true
    if (onboardingCompleted) {
      print('DEBUG: OnboardingData.isComplete: true (onboardingCompleted flag is set)');
      return true;
    }

    // Otherwise, check if all fields are filled
    final complete = accountType != null &&
        displayName != null &&
        username != null &&
        birthday != null &&
        phoneNumber != null &&
        profileImageUrl != null &&
        interests != null &&
        interests!.isNotEmpty;

    print('DEBUG: OnboardingData.isComplete: $complete (based on field checks)');
    print('DEBUG: accountType: $accountType');
    print('DEBUG: displayName: $displayName');
    print('DEBUG: username: $username');
    print('DEBUG: birthday: $birthday');
    print('DEBUG: phoneNumber: $phoneNumber');
    print('DEBUG: profileImageUrl: $profileImageUrl');
    print('DEBUG: interests: $interests');

    return complete;
  }

  @override
  String toString() {
    return 'OnboardingData{'
        'accountType: $accountType, '
        'displayName: $displayName, '
        'username: $username, '
        'birthday: $birthday, '
        'phoneNumber: $phoneNumber, '
        'profileImageUrl: $profileImageUrl, '
        'interests: $interests, '
        'onboardingCompleted: $onboardingCompleted, '
        'isComplete: ${isComplete()}'
        '}';
  }
}
