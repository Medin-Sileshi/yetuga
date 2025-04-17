import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

// Provider for the EventUserService
final eventUserServiceProvider = Provider<EventUserService>((ref) => EventUserService());

class EventUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user display name for an event
  Future<String> getUserDisplayName(String userId) async {
    try {
      Logger.d('EventUserService', 'Getting display name for user: $userId');

      // Try to get from Firestore directly
      Logger.d('EventUserService', 'Attempting to fetch user document from Firestore for userId: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      Logger.d('EventUserService', 'Firestore document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data();
        Logger.d('EventUserService', 'Document data: $data');

        if (data != null && data['displayName'] != null) {
          final displayName = data['displayName'] as String;
          Logger.d('EventUserService', 'Found display name in Firestore: $displayName');
          return displayName;
        } else {
          Logger.d('EventUserService', 'Document exists but displayName is null or missing');
        }
      } else {
        Logger.d('EventUserService', 'User document does not exist for userId: $userId');
      }

      // If not found in Firestore, try to get from Firebase Auth
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid == userId && authUser.displayName != null) {
        Logger.d('EventUserService', 'Using display name from Firebase Auth: ${authUser.displayName}');
        return authUser.displayName!;
      }

      // Default fallback
      Logger.d('EventUserService', 'No display name found, using default');
      return 'User';
    } catch (e) {
      Logger.d('EventUserService', 'Error getting user display name: $e');
      return 'User';
    }
  }

  // Get user username for an event
  Future<String> getUserUsername(String userId) async {
    try {
      Logger.d('EventUserService', 'Getting username for user: $userId');

      // Try to get from Firestore directly
      Logger.d('EventUserService', 'Attempting to fetch user document from Firestore for userId: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      Logger.d('EventUserService', 'Firestore document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data();
        Logger.d('EventUserService', 'Document data: $data');

        if (data != null && data['username'] != null) {
          final username = data['username'] as String;
          Logger.d('EventUserService', 'Found username in Firestore: $username');
          return username;
        } else {
          Logger.d('EventUserService', 'Document exists but username is null or missing');
        }
      } else {
        Logger.d('EventUserService', 'User document does not exist for userId: $userId');
      }

      // If not found in Firestore, try to get from email
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid == userId && authUser.email != null) {
        final emailUsername = authUser.email!.split('@').first;
        Logger.d('EventUserService', 'Using username from email: $emailUsername');
        return emailUsername;
      }

      // Default fallback
      Logger.d('EventUserService', 'No username found, using default');
      return 'username';
    } catch (e) {
      Logger.d('EventUserService', 'Error getting username: $e');
      return 'username';
    }
  }

  // Get user profile image URL for an event
  Future<String?> getUserProfileImageUrl(String userId) async {
    try {
      Logger.d('EventUserService', 'Getting profile image URL for user: $userId');

      // Try to get from Firestore directly
      Logger.d('EventUserService', 'Attempting to fetch user document from Firestore for userId: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      Logger.d('EventUserService', 'Firestore document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data();
        Logger.d('EventUserService', 'Document data: $data');

        if (data != null && data['profileImageUrl'] != null) {
          final imageUrl = data['profileImageUrl'] as String;
          Logger.d('EventUserService', 'Raw profile image URL: $imageUrl');

          if (imageUrl.isNotEmpty) {
            Logger.d('EventUserService', 'Found valid profile image URL in Firestore: $imageUrl');
            return imageUrl;
          } else {
            Logger.d('EventUserService', 'Profile image URL is empty');
          }
        } else {
          Logger.d('EventUserService', 'Document exists but profileImageUrl is null or missing');
        }
      } else {
        Logger.d('EventUserService', 'User document does not exist for userId: $userId');
      }

      // If not found in Firestore, try to get from Firebase Auth
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid == userId && authUser.photoURL != null) {
        Logger.d('EventUserService', 'Using profile image URL from Firebase Auth: ${authUser.photoURL}');
        return authUser.photoURL;
      }

      Logger.d('EventUserService', 'No profile image URL found');
      return null;
    } catch (e) {
      Logger.d('EventUserService', 'Error getting profile image URL: $e');
      return null;
    }
  }

  // Check if user has a business account
  Future<bool> isBusinessAccount(String userId) async {
    try {
      Logger.d('EventUserService', 'Checking if user has a business account: $userId');

      // Try to get from Firestore directly
      Logger.d('EventUserService', 'Attempting to fetch user document from Firestore for userId: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      Logger.d('EventUserService', 'Firestore document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data();
        Logger.d('EventUserService', 'Document data: $data');

        if (data != null && data['accountType'] != null) {
          final isBusinessAccount = data['accountType'] == 'business';
          Logger.d('EventUserService', 'Account type: ${data['accountType']}, Is business: $isBusinessAccount');
          return isBusinessAccount;
        } else {
          Logger.d('EventUserService', 'Document exists but accountType is null or missing');
        }
      } else {
        Logger.d('EventUserService', 'User document does not exist for userId: $userId');
      }

      Logger.d('EventUserService', 'Defaulting to personal account (false)');
      return false;
    } catch (e) {
      Logger.d('EventUserService', 'Error checking if business account: $e');
      return false;
    }
  }

  // Get user profile image widget for an event
  Widget getUserProfileImage(String userId, {double size = 40.0, bool isBusiness = false}) {
    return Builder(
      builder: (context) {
        // Get the theme's secondary color for personal account borders
        final secondaryColor = Theme.of(context).colorScheme.secondary;

        return FutureBuilder<String?>(
          future: getUserProfileImageUrl(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            }

            final imageUrl = snapshot.data;

            if (imageUrl == null || imageUrl.isEmpty) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isBusiness ? Colors.amber : secondaryColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: size * 0.6,
                  ),
                ),
              );
            }

            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBusiness ? Colors.amber : secondaryColor,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  cacheKey: '${userId}_profile_image',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
