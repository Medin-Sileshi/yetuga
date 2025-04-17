import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding_data.dart';
import '../utils/logger.dart';
import 'storage_provider.dart';

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, AsyncValue<OnboardingData>>(
        (ref) {
  return OnboardingNotifier(ref);
});

class OnboardingNotifier extends StateNotifier<AsyncValue<OnboardingData>> {
  final Ref? _ref;

  OnboardingNotifier([this._ref]) : super(const AsyncValue.loading()) {
    // Load data from Hive when the provider is initialized
    if (_ref != null) {
      _loadDataFromHive();
    }
  }

  Future<void> _loadDataFromHive() async {
    try {
      Logger.d('OnboardingProvider', 'OnboardingNotifier: Loading data from Hive...');
      state = const AsyncValue.loading();

      final storageService = _ref!.read(storageServiceProvider);
      final data = await storageService.getOnboardingData();

      if (data != null) {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: Data loaded from Hive: $data');
        state = AsyncValue.data(data);
      } else {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: No data found in Hive, using empty data');
        state = AsyncValue.data(OnboardingData());
      }
    } catch (e) {
      Logger.d('OnboardingProvider', 'OnboardingNotifier: Error loading data from Hive: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Method to sync data with Firebase
  Future<void> syncWithFirebase() async {
    try {
      Logger.d('OnboardingProvider', 'OnboardingNotifier: Syncing with Firebase...');
      state = const AsyncValue.loading();

      final storageService = _ref!.read(storageServiceProvider);

      // Force a direct sync with Firebase
      final userId = storageService.getCurrentUserId();
      if (userId == null) {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: No user logged in, cannot sync');
        state = AsyncValue.data(OnboardingData());
        return;
      }

      // First try to get data from Firebase directly
      Logger.d('OnboardingProvider', 'OnboardingNotifier: Checking Firebase directly...');
      final firebaseService = storageService.getFirebaseService();
      final userProfile = await firebaseService.getUserProfile();

      if (userProfile != null) {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: Found user profile in Firebase: $userProfile');

        // Check if onboarding is completed in Firebase
        final onboardingCompleted = userProfile['onboardingCompleted'] == true;
        Logger.d('OnboardingProvider', 'OnboardingNotifier: onboardingCompleted in Firebase: $onboardingCompleted');

        // Create OnboardingData from Firebase data
        final completedData = OnboardingData()
          ..accountType = userProfile['accountType']
          ..displayName = userProfile['displayName']
          ..username = userProfile['username']
          ..birthday = userProfile['birthday']?.toDate() // Convert Timestamp to DateTime
          ..phoneNumber = userProfile['phoneNumber']
          ..profileImageUrl = userProfile['profileImageUrl']
          ..interests = List<String>.from(userProfile['interests'] ?? [])
          ..onboardingCompleted = onboardingCompleted;

        // Save to Hive and update state
        Logger.d('OnboardingProvider', 'OnboardingNotifier: Saving Firebase data to Hive');
        await storageService.saveOnboardingData(completedData);

        // Double-check that the data was saved correctly
        final savedData = await storageService.getOnboardingDataFromHive();
        Logger.d('OnboardingProvider', 'OnboardingNotifier: Data saved to Hive: $savedData');
        Logger.d('OnboardingProvider', 'OnboardingNotifier: Is complete: ${savedData?.isComplete()}');

        state = AsyncValue.data(completedData);
        return;
      } else {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: No user profile found in Firebase');
      }

      // If not found in Firebase, try the normal sync process
      final data = await storageService.syncWithFirebase(userId);

      if (data != null) {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: Data synced from Firebase: $data');
        state = AsyncValue.data(data);
      } else {
        Logger.d('OnboardingProvider', 'OnboardingNotifier: No data found in Firebase, using empty data');
        state = AsyncValue.data(OnboardingData());
      }
    } catch (e) {
      Logger.d('OnboardingProvider', 'OnboardingNotifier: Error syncing with Firebase: $e');
      // Don't update state to error to avoid breaking the UI
      // Just keep the current state
    }
  }

  // Simple method to update the state with new data
  void updateData(OnboardingData data) {
    state = AsyncValue.data(data);
  }

  bool get isComplete => state.when(
        data: (data) => data.isComplete(),
        loading: () => false,
        error: (_, __) => false,
      );

  void setAccountType(String type) {
    state.whenData((data) {
      data.accountType = type;
      updateData(data);
    });
  }

  void setDisplayName(String name) {
    state.whenData((data) {
      data.displayName = name;
      updateData(data);
    });
  }

  void setUsername(String username) {
    state.whenData((data) {
      data.username = username;
      updateData(data);
    });
  }

  void setBirthday(DateTime birthday) {
    state.whenData((data) {
      data.birthday = birthday;
      updateData(data);
    });
  }

  void setPhoneNumber(String phone) {
    state.whenData((data) {
      data.phoneNumber = phone;
      updateData(data);
    });
  }

  void setProfileImage(String imageUrl) {
    state.whenData((data) {
      data.profileImageUrl = imageUrl;
      updateData(data);
    });
  }

  void setInterests(List<String> interests) {
    state.whenData((data) {
      data.interests = interests;
      updateData(data);
    });
  }

  // Method to save all data at once (for final submission)
  Future<void> saveData(OnboardingData data) async {
    try {
      // Update the state first
      updateData(data);

      // Then save to Hive using the storage service
      if (_ref != null) {
        final storageService = _ref.read(storageServiceProvider);
        await storageService.saveOnboardingData(data);
        Logger.d('OnboardingProvider', 'Successfully saved to Hive');
      } else {
        Logger.d('OnboardingProvider', 'Ref is null, skipping Hive save');
      }
      return Future.value();
    } catch (e) {
      Logger.d('OnboardingProvider', 'Error saving to Hive: $e');
      throw Exception('Failed to save to Hive: $e');
    }
  }

  Future<void> clearData() async {
    state = AsyncValue.data(OnboardingData());

    // Also clear data from Hive
    if (_ref != null) {
      try {
        final storageService = _ref.read(storageServiceProvider);
        await storageService.clearOnboardingData();
        Logger.d('OnboardingProvider', 'Successfully cleared data from Hive');
      } catch (e) {
        Logger.d('OnboardingProvider', 'Error clearing data from Hive: $e');
      }
    }
  }
}
