import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

// Provider for the FirestoreConfigService
final firestoreConfigServiceProvider = Provider<FirestoreConfigService>((ref) => FirestoreConfigService());

class FirestoreConfigService {
  // Default cache size is 40MB
  static const int _defaultCacheSizeBytes = 40 * 1024 * 1024;

  // Initialize Firestore with persistence enabled
  Future<void> initializeFirestore({int cacheSizeBytes = _defaultCacheSizeBytes}) async {
    try {
      Logger.d('FirestoreConfigService', 'Initializing Firestore with persistence');

      // Set the cache size
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: cacheSizeBytes,
      );

      Logger.d('FirestoreConfigService', 'Firestore persistence enabled with cache size: ${cacheSizeBytes / (1024 * 1024)} MB');
    } catch (e) {
      Logger.e('FirestoreConfigService', 'Error initializing Firestore persistence', e);
      // Fall back to default settings if there's an error
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    }
  }

  // Enable offline persistence
  Future<void> enablePersistence() async {
    try {
      Logger.d('FirestoreConfigService', 'Enabling Firestore persistence');

      // This is already handled by the settings above, but we're keeping this method
      // for explicit control if needed in the future

      Logger.d('FirestoreConfigService', 'Firestore persistence enabled');
    } catch (e) {
      Logger.e('FirestoreConfigService', 'Error enabling Firestore persistence', e);
    }
  }

  // Disable offline persistence
  Future<void> disablePersistence() async {
    try {
      Logger.d('FirestoreConfigService', 'Disabling Firestore persistence');

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );

      Logger.d('FirestoreConfigService', 'Firestore persistence disabled');
    } catch (e) {
      Logger.e('FirestoreConfigService', 'Error disabling Firestore persistence', e);
    }
  }

  // Clear the persistent cache
  Future<void> clearPersistentCache() async {
    try {
      Logger.d('FirestoreConfigService', 'Clearing Firestore persistent cache');

      await FirebaseFirestore.instance.clearPersistence();

      Logger.d('FirestoreConfigService', 'Firestore persistent cache cleared');
    } catch (e) {
      Logger.e('FirestoreConfigService', 'Error clearing Firestore persistent cache', e);
      rethrow;
    }
  }

  // Check if the device is online
  Future<bool> isOnline() async {
    try {
      // Try to get a user document instead of system/status
      // This should work with existing security rules
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Try to get the current user's document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get(const GetOptions(source: Source.server));

        Logger.d('FirestoreConfigService', 'Device is online');
        return true;
      } else {
        // If no user is logged in, try to get a document from events collection
        await FirebaseFirestore.instance
            .collection('events')
            .limit(1)
            .get(const GetOptions(source: Source.server));

        Logger.d('FirestoreConfigService', 'Device is online');
        return true;
      }
    } catch (e) {
      Logger.d('FirestoreConfigService', 'Device appears to be offline: ${e.toString()}');
      return false;
    }
  }

  // Force a document to be fetched from the server
  Future<DocumentSnapshot?> forceRefresh(String collection, String documentId) async {
    try {
      Logger.d('FirestoreConfigService', 'Forcing refresh of $collection/$documentId from server');

      final docSnapshot = await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .get(const GetOptions(source: Source.server));

      return docSnapshot;
    } catch (e) {
      Logger.e('FirestoreConfigService', 'Error forcing refresh from server', e);
      return null;
    }
  }
}
