import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/providers/onboarding_form_provider.dart';
import 'package:yetuga/models/onboarding_data.dart';

void main() {
  group('OnboardingFormProvider Tests', () {
    late OnboardingFormNotifier notifier;

    setUp(() {
      notifier = OnboardingFormNotifier();
    });

    test('Initial state should be empty', () {
      // Verify initial state
      expect(notifier.state.accountType, isNull);
      expect(notifier.state.displayName, isNull);
      expect(notifier.state.username, isNull);
      expect(notifier.state.birthday, isNull);
      expect(notifier.state.phoneNumber, isNull);
      expect(notifier.state.profileImageUrl, isNull);
      expect(notifier.state.interests, isNull);
      expect(notifier.state.onboardingCompleted, isFalse);
    });

    test('setAccountType should update state', () {
      // Act
      notifier.setAccountType('personal');
      
      // Assert
      expect(notifier.state.accountType, equals('personal'));
    });

    test('setDisplayName should update state', () {
      // Act
      notifier.setDisplayName('John Doe');
      
      // Assert
      expect(notifier.state.displayName, equals('John Doe'));
    });

    test('setUsername should update state', () {
      // Act
      notifier.setUsername('johndoe');
      
      // Assert
      expect(notifier.state.username, equals('johndoe'));
    });

    test('setBirthday should update state', () {
      // Arrange
      final birthday = DateTime(1990, 1, 1);
      
      // Act
      notifier.setBirthday(birthday);
      
      // Assert
      expect(notifier.state.birthday, equals(birthday));
    });

    test('setPhoneNumber should update state', () {
      // Act
      notifier.setPhoneNumber('+1234567890');
      
      // Assert
      expect(notifier.state.phoneNumber, equals('+1234567890'));
    });

    test('setProfileImage should update state', () {
      // Act
      notifier.setProfileImage('https://example.com/image.jpg');
      
      // Assert
      expect(notifier.state.profileImageUrl, equals('https://example.com/image.jpg'));
    });

    test('setInterests should update state', () {
      // Arrange
      final interests = ['Sports', 'Music', 'Art'];
      
      // Act
      notifier.setInterests(interests);
      
      // Assert
      expect(notifier.state.interests, equals(interests));
    });

    test('setOnboardingCompleted should update state', () {
      // Act
      notifier.setOnboardingCompleted(true);
      
      // Assert
      expect(notifier.state.onboardingCompleted, isTrue);
    });

    test('reset should clear state', () {
      // Arrange - Set some values
      notifier.setAccountType('personal');
      notifier.setDisplayName('John Doe');
      
      // Act
      notifier.reset();
      
      // Assert
      expect(notifier.state.accountType, isNull);
      expect(notifier.state.displayName, isNull);
    });

    test('isComplete should return true when all required fields are set', () {
      // Arrange
      notifier.setAccountType('personal');
      notifier.setDisplayName('John Doe');
      notifier.setUsername('johndoe');
      notifier.setBirthday(DateTime(1990, 1, 1));
      notifier.setPhoneNumber('+1234567890');
      notifier.setProfileImage('https://example.com/image.jpg');
      notifier.setInterests(['Sports']);
      
      // Assert
      expect(notifier.state.isComplete(), isTrue);
    });

    test('isComplete should return false when any required field is missing', () {
      // Arrange - Set all fields except username
      notifier.setAccountType('personal');
      notifier.setDisplayName('John Doe');
      // Missing username
      notifier.setBirthday(DateTime(1990, 1, 1));
      notifier.setPhoneNumber('+1234567890');
      notifier.setProfileImage('https://example.com/image.jpg');
      notifier.setInterests(['Sports']);
      
      // Assert
      expect(notifier.state.isComplete(), isFalse);
    });
  });
}
