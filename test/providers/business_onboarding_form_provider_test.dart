import 'package:flutter_test/flutter_test.dart';
import 'package:yetuga/providers/business_onboarding_form_provider.dart';

void main() {
  group('BusinessOnboardingFormProvider Tests', () {
    late BusinessOnboardingFormNotifier notifier;

    setUp(() {
      notifier = BusinessOnboardingFormNotifier();
    });

    test('Initial state should be empty', () {
      // Verify initial state
      expect(notifier.state.accountType, isNull);
      expect(notifier.state.businessName, isNull);
      expect(notifier.state.username, isNull);
      expect(notifier.state.establishedDate, isNull);
      expect(notifier.state.phoneNumber, isNull);
      expect(notifier.state.profileImageUrl, isNull);
      expect(notifier.state.businessTypes, isNull);
      expect(notifier.state.onboardingCompleted, isFalse);
    });

    test('setAccountType should update state', () {
      // Act
      notifier.setAccountType('business');

      // Assert
      expect(notifier.state.accountType, equals('business'));
    });

    test('setBusinessName should update state', () {
      // Act
      notifier.setBusinessName('Acme Corp');

      // Assert
      expect(notifier.state.businessName, equals('Acme Corp'));
    });

    test('setUsername should update state', () {
      // Act
      notifier.setUsername('acmecorp');

      // Assert
      expect(notifier.state.username, equals('acmecorp'));
    });

    test('setEstablishedDate should update state', () {
      // Arrange
      final date = DateTime(2010, 1, 1);

      // Act
      notifier.setEstablishedDate(date);

      // Assert
      expect(notifier.state.establishedDate, equals(date));
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

    test('setBusinessTypes should update state', () {
      // Arrange
      final types = ['Retail', 'Technology', 'Services'];

      // Act
      notifier.setBusinessTypes(types);

      // Assert
      expect(notifier.state.businessTypes, equals(types));
    });

    test('setOnboardingCompleted should update state', () {
      // Act
      notifier.setOnboardingCompleted(true);

      // Assert
      expect(notifier.state.onboardingCompleted, isTrue);
    });

    test('reset should clear state', () {
      // Arrange - Set some values
      notifier.setAccountType('business');
      notifier.setBusinessName('Acme Corp');

      // Act
      notifier.reset();

      // Assert
      expect(notifier.state.accountType, isNull);
      expect(notifier.state.businessName, isNull);
    });

    test('isComplete should return true when all required fields are set', () {
      // Arrange
      notifier.setAccountType('business');
      notifier.setBusinessName('Acme Corp');
      notifier.setUsername('acmecorp');
      notifier.setEstablishedDate(DateTime(2010, 1, 1));
      notifier.setPhoneNumber('+1234567890');
      notifier.setProfileImage('https://example.com/image.jpg');
      notifier.setBusinessTypes(['Retail']);

      // Assert
      expect(notifier.state.isComplete(), isTrue);
    });

    test('isComplete should return false when any required field is missing', () {
      // Arrange - Set all fields except username
      notifier.setAccountType('business');
      notifier.setBusinessName('Acme Corp');
      // Missing username
      notifier.setEstablishedDate(DateTime(2010, 1, 1));
      notifier.setPhoneNumber('+1234567890');
      notifier.setProfileImage('https://example.com/image.jpg');
      notifier.setBusinessTypes(['Retail']);

      // Assert
      expect(notifier.state.isComplete(), isFalse);
    });
  });
}
