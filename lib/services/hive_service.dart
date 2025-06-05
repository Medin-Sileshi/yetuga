import 'package:hive_flutter/hive_flutter.dart';
import '../models/onboarding_data.dart';

class HiveService {
  Future<void> updateOnboardingData(String uid, Map<String, dynamic> data) async {
    try {
      final onboardingBox = Hive.box<OnboardingData>('onboarding');
      final onboardingData = OnboardingData()
        ..accountType = data['accountType']
        ..displayName = data['displayName']
        ..username = data['username']
        ..birthday = data['birthday']?.toDate()
        ..phoneNumber = data['phoneNumber']
        ..profileImageUrl = data['profileImageUrl']
        ..interests = List<String>.from(data['interests'] ?? [])
        ..onboardingCompleted = true;

      await onboardingBox.put(uid, onboardingData);
    } catch (e) {
      throw Exception('Error updating Hive: $e');
    }
  }
}
