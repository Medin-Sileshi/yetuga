import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    required DateTime? birthday,
    required String? phoneNumber,
    required String? profileImageUrl,
    required List<String>? interests,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate required fields
      if (accountType == null ||
          displayName == null ||
          username == null ||
          birthday == null ||
          phoneNumber == null ||
          profileImageUrl == null ||
          interests == null) {
        throw Exception('All fields are required');
      }

      // Validate username format
      if (!RegExp(r'^[a-z0-9]{2,15}$').hasMatch(username)) {
        throw Exception('Invalid username format');
      }

      // Check username availability
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username is already taken');
      }

      // Validate phone number format (Ethiopian)
      if (!RegExp(r'^9\d{8}$').hasMatch(phoneNumber)) {
        throw Exception('Invalid Ethiopian phone number format');
      }

      // Validate interests
      if (interests.isEmpty) {
        throw Exception('At least one interest is required');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'accountType': accountType,
        'displayName': displayName,
        'username': username,
        'birthday': birthday,
        'phoneNumber': phoneNumber,
        'profileImageUrl': profileImageUrl,
        'interests': interests,
        'onboardingCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } on FirebaseException catch (e) {
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }
}
