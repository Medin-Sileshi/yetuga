import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/business_onboarding_data.dart';
import '../models/onboarding_data.dart';
import '../utils/logger.dart';
import 'firebase_service.dart';

class StorageService {
  static const String _onboardingBoxName = 'onboarding';
  Box<OnboardingData>? _onboardingBox;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> init() async {
    try {
      Logger.d('StorageService', 'StorageService: Initializing...');
      if (Hive.isBoxOpen(_onboardingBoxName)) {
        Logger.d('StorageService', 'StorageService: Box is already open');
        _onboardingBox = Hive.box<OnboardingData>(_onboardingBoxName);
      } else {
        Logger.d('StorageService', 'StorageService: Opening box');
        _onboardingBox = await Hive.openBox<OnboardingData>(_onboardingBoxName);
      }
      Logger.d('StorageService', 'StorageService: Box opened successfully');
      Logger.d('StorageService', 'StorageService: Box keys: ${_onboardingBox?.keys.toList()}');
      Logger.info('StorageService: Initialized successfully');
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Failed to initialize: $e');
      Logger.error('StorageService: Failed to initialize', e);
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await _onboardingBox?.close();
      _onboardingBox = null;
      Logger.info('StorageService: Disposed successfully');
    } catch (e) {
      Logger.error('StorageService: Failed to dispose', e);
      rethrow;
    }
  }

  Future<OnboardingData?> getOnboardingData() async {
    _ensureInitialized();
    try {
      // Get current user ID
      final user = _auth.currentUser;
      if (user == null) {
        Logger.d('StorageService', 'StorageService: No user logged in, returning null');
        return null;
      }

      final userId = user.uid;
      Logger.d('StorageService', 'StorageService: Getting onboarding data for user: $userId');
      Logger.d('StorageService', 'StorageService: Box keys: ${_onboardingBox?.keys.toList()}');

      // Try to get data from Hive
      final data = _onboardingBox?.get(userId);
      Logger.d('StorageService', 'StorageService: Retrieved data from Hive: $data');

      // If no data in Hive, try to get from Firebase
      if (data == null) {
        Logger.d('StorageService', 'StorageService: No data in Hive, checking Firebase');
        return await syncWithFirebase(userId);
      }

      return data;
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Failed to get onboarding data: $e');
      Logger.error('StorageService: Failed to get onboarding data', e);
      rethrow;
    }
  }

  Future<void> saveOnboardingData(OnboardingData data) async {
    _ensureInitialized();
    try {
      // Get current user ID
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userId = user.uid;
      Logger.d('StorageService', 'StorageService: Saving onboarding data for user: $userId');
      Logger.d('StorageService', 'StorageService: Data to save: $data');

      // Save to Hive with user ID as key
      await _onboardingBox?.put(userId, data);

      Logger.d('StorageService', 'StorageService: Saved onboarding data successfully');
      Logger.d('StorageService', 'StorageService: Box keys: ${_onboardingBox?.keys.toList()}');
      Logger.d('StorageService', 'StorageService: Data in box: ${_onboardingBox?.get(userId)}');
      Logger.info('StorageService: Saved onboarding data successfully');
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Failed to save onboarding data: $e');
      Logger.error('StorageService: Failed to save onboarding data', e);
      rethrow;
    }
  }

  Future<void> clearOnboardingData() async {
    _ensureInitialized();
    try {
      // Get current user ID
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userId = user.uid;
      Logger.d('StorageService', 'StorageService: Clearing onboarding data for user: $userId');
      Logger.d('StorageService', 'StorageService: Box keys before clear: ${_onboardingBox?.keys.toList()}');

      // Delete only the current user's data
      await _onboardingBox?.delete(userId);

      Logger.d('StorageService', 'StorageService: Box keys after clear: ${_onboardingBox?.keys.toList()}');
      Logger.info('StorageService: Cleared onboarding data successfully');
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Failed to clear onboarding data: $e');
      Logger.error('StorageService: Failed to clear onboarding data', e);
      rethrow;
    }
  }

  // Clear all onboarding data from Hive (for all users)
  // This is useful when creating a new account to ensure no old data is used
  Future<void> clearAllOnboardingData() async {
    _ensureInitialized();
    try {
      Logger.d('StorageService', 'StorageService: Clearing ALL onboarding data');
      Logger.d('StorageService', 'StorageService: Box keys before clear: ${_onboardingBox?.keys.toList()}');

      // Clear all data in the box
      await _onboardingBox?.clear();

      Logger.d('StorageService', 'StorageService: Box keys after clear: ${_onboardingBox?.keys.toList()}');
      Logger.info('StorageService: Cleared ALL onboarding data successfully');
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Failed to clear all onboarding data: $e');
      Logger.error('StorageService: Failed to clear all onboarding data', e);
      rethrow;
    }
  }

  // New method to sync data with Firebase
  Future<OnboardingData?> syncWithFirebase(String userId) async {
    try {
      Logger.d('StorageService', 'StorageService: Syncing with Databse for user: $userId');

      // Get user profile from Firebase
      final userProfile = await _firebaseService.getUserProfile();

      if (userProfile == null) {
        Logger.d('StorageService', 'StorageService: No data found in Firebase');
        return null;
      }

      Logger.d('StorageService', 'StorageService: Data found in Firebase: $userProfile');

      // Check if onboarding is completed in Firebase
      final onboardingCompleted = userProfile['onboardingCompleted'] ?? false;
      Logger.d('StorageService', 'StorageService: onboardingCompleted in Firebase: $onboardingCompleted');

      // Convert Firebase data to OnboardingData
      OnboardingData onboardingData;
      if (userProfile['accountType'] == 'business') {
        onboardingData = BusinessOnboardingData(
          accountType: userProfile['accountType'],
          businessName: userProfile['businessName'],
          username: userProfile['username'],
          establishedDate: userProfile['establishedDate']?.toDate(),
          phoneNumber: userProfile['phoneNumber'],
          profileImageUrl: userProfile['profileImageUrl'],
          businessTypes: List<String>.from(userProfile['businessTypes'] ?? []),
          onboardingCompleted: onboardingCompleted,
          verified: userProfile['verified'] ?? false,
        );
      } else {
        onboardingData = OnboardingData()
          ..accountType = userProfile['accountType']
          ..displayName = userProfile['displayName']
          ..username = userProfile['username']
          ..birthday = userProfile['birthday']?.toDate() // Convert Timestamp to DateTime
          ..phoneNumber = userProfile['phoneNumber']
          ..profileImageUrl = userProfile['profileImageUrl']
          ..interests = List<String>.from(userProfile['interests'] ?? [])
          ..onboardingCompleted = onboardingCompleted;
      }

      // Save the synced data to Hive
      await _onboardingBox?.put(userId, onboardingData);

      Logger.d('StorageService', 'StorageService: Synced data saved to Hive');
      return onboardingData;
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Failed to sync with Firebase: $e');
      Logger.error('StorageService: Failed to sync with Firebase', e);
      return null; // Return null but don't rethrow to avoid crashing the app
    }
  }

  void _ensureInitialized() {
    if (_onboardingBox == null) {
      throw StateError('StorageService not initialized');
    }
  }

  // Get the current user ID
  String? getCurrentUserId() {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // Get the Firebase service instance
  FirebaseService getFirebaseService() {
    return _firebaseService;
  }

  // Get onboarding data directly from Hive without Firebase check
  Future<OnboardingData?> getOnboardingDataFromHive() async {
    _ensureInitialized();
    final userId = getCurrentUserId();
    if (userId == null) return null;

    try {
      final data = _onboardingBox?.get(userId);
      Logger.d('StorageService', 'StorageService: Got onboarding data from Hive for user: $userId');
      Logger.d('StorageService', 'StorageService: Data: $data');
      return data;
    } catch (e) {
      Logger.d('StorageService', 'StorageService: Error getting onboarding data from Hive: $e');
      return null;
    }
  }
}