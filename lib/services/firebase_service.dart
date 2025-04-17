import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/logger.dart';

class FirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate file size
      if (imageFile.lengthSync() > 2 * 1024 * 1024) {
        throw Exception('Image size must be less than 2MB');
      }

      // Validate file type
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Only JPG and PNG images are allowed');
      }

      final ref = _storage.ref().child('profile_images/${user.uid}');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // Save user profile data
  Future<void> saveUserProfile({
    required String? accountType,
    required String? displayName,
    required String? username,
    DateTime? birthday,
    required String? phoneNumber,
    required String? profileImageUrl,
    List<String>? interests,
    DateTime? establishedDate,
    List<String>? businessTypes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate common required fields
      if (accountType == null ||
          displayName == null ||
          username == null ||
          phoneNumber == null ||
          profileImageUrl == null) {
        throw Exception('Common fields are required');
      }

      // Validate username format - allow lowercase letters, numbers, and underscores
      // First trim any whitespace
      username = username.trim();

      // Check length
      if (username.length < 2 || username.length > 15) {
        throw Exception('Invalid username format - must be 2-15 characters and contain only lowercase letters, numbers, and underscores');
      }

      // Check characters
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
        throw Exception('Invalid username format - must be 2-15 characters and contain only lowercase letters, numbers, and underscores');
      }

      // Check username availability
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username is already taken');
      }

      // Validate phone number format (Ethiopian)
      // Skip validation for now to allow the data to be saved
      Logger.d('FirebaseService', 'Phone number being saved to Firebase: $phoneNumber');

      // We'll just make sure it's not empty
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number cannot be empty');
      }

      // Create a map to hold the user data
      final Map<String, dynamic> userData = {
        'accountType': accountType,
        'displayName': displayName,
        'username': username,
        'phoneNumber': phoneNumber,
        'profileImageUrl': profileImageUrl,
        'onboardingCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add account-specific fields
      if (accountType == 'business') {
        // Business account validation
        if (businessTypes == null || businessTypes.isEmpty) {
          throw Exception('Business types are required for business accounts');
        }

        if (establishedDate == null) {
          throw Exception('Established date is required for business accounts');
        }

        // Add business-specific fields
        userData['businessTypes'] = businessTypes;
        userData['establishedDate'] = Timestamp.fromDate(establishedDate);
      } else {
        // Personal account validation
        if (birthday == null) {
          throw Exception('Birthday is required for personal accounts');
        }

        if (interests == null || interests.isEmpty) {
          throw Exception('At least one interest is required for personal accounts');
        }

        // Add personal-specific fields
        userData['birthday'] = Timestamp.fromDate(birthday);
        userData['interests'] = interests;
      }

      Logger.d('FirebaseService', 'Firebase: Saving user data to Firestore...');
      await _firestore.collection('users').doc(user.uid).set(userData);
    } on FirebaseException catch (e) {
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to save user profile: $e');
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      return result.docs.isEmpty;
    } on FirebaseException catch (e) {
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to check username availability: $e');
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        Logger.d('FirebaseService', 'FirebaseService: No user logged in');
        return null;
      }

      return getUserProfileById(user.uid);
    } catch (e) {
      Logger.e('FirebaseService', 'Error getting user profile', e);
      return null;
    }
  }

  // Get user profile by ID
  Future<Map<String, dynamic>?> getUserProfileById(String userId) async {
    try {
      Logger.d('FirebaseService', 'FirebaseService: Getting profile for user: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data();
        Logger.d('FirebaseService', 'FirebaseService: User profile found: $data');
        return data;
      } else {
        Logger.d('FirebaseService', 'FirebaseService: User profile not found for user: $userId');
        return null;
      }
    } catch (e) {
      Logger.e('FirebaseService', 'Error getting user profile by ID', e);
      return null;
    }
  }
}
