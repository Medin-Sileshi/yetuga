import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

final followServiceProvider = Provider<FollowService>((ref) => FollowService());

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to follow users');
      }

      if (currentUser.uid == targetUserId) {
        throw Exception('You cannot follow yourself');
      }

      final currentUserId = currentUser.uid;
      final batch = _firestore.batch();

      // Add to current user's following collection
      final followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);

      // Add to target user's followers collection
      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);

      // Get current user data for the follower entry
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data();

      if (currentUserData == null) {
        throw Exception('Current user data not found');
      }

      // Get target user data for the following entry
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      final targetUserData = targetUserDoc.data();

      if (targetUserData == null) {
        throw Exception('Target user data not found');
      }

      // Prepare follower data
      final followerData = {
        'userId': currentUserId,
        'displayName': currentUserData['displayName'] ?? 'User',
        'username': currentUserData['username'] ?? 'username',
        'profileImageUrl': currentUserData['profileImageUrl'] ?? '',
        'accountType': currentUserData['accountType'] ?? 'personal',
        'followedAt': FieldValue.serverTimestamp(),
      };

      // Prepare following data
      final followingData = {
        'userId': targetUserId,
        'displayName': targetUserData['displayName'] ?? 'User',
        'username': targetUserData['username'] ?? 'username',
        'profileImageUrl': targetUserData['profileImageUrl'] ?? '',
        'accountType': targetUserData['accountType'] ?? 'personal',
        'followedAt': FieldValue.serverTimestamp(),
      };

      // Add operations to batch
      batch.set(followingRef, followingData);
      batch.set(followerRef, followerData);

      // Update follower and following counts
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'followingCount': FieldValue.increment(1)
      });

      batch.update(_firestore.collection('users').doc(targetUserId), {
        'followersCount': FieldValue.increment(1)
      });

      // Commit the batch
      await batch.commit();

      Logger.d('FollowService', 'Successfully followed user: $targetUserId');
    } catch (e) {
      Logger.e('FollowService', 'Error following user', e);
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to unfollow users');
      }

      final currentUserId = currentUser.uid;
      final batch = _firestore.batch();

      // References to the documents to delete
      final followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);

      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);

      // Add delete operations to batch
      batch.delete(followingRef);
      batch.delete(followerRef);

      // Update follower and following counts
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'followingCount': FieldValue.increment(-1)
      });

      batch.update(_firestore.collection('users').doc(targetUserId), {
        'followersCount': FieldValue.increment(-1)
      });

      // Commit the batch
      await batch.commit();

      Logger.d('FollowService', 'Successfully unfollowed user: $targetUserId');
    } catch (e) {
      Logger.e('FollowService', 'Error unfollowing user', e);
      rethrow;
    }
  }

  // Check if current user is following a target user
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final followingDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId)
          .get();

      return followingDoc.exists;
    } catch (e) {
      Logger.e('FollowService', 'Error checking follow status', e);
      return false;
    }
  }

  // Get followers count for a user
  Future<int> getFollowersCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData != null && userData.containsKey('followersCount')) {
        return userData['followersCount'] as int;
      }

      // If the count field doesn't exist, count the documents
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();

      return followersSnapshot.count ?? 0;
    } catch (e) {
      Logger.e('FollowService', 'Error getting followers count', e);
      return 0;
    }
  }

  // Get following count for a user
  Future<int> getFollowingCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData != null && userData.containsKey('followingCount')) {
        return userData['followingCount'] as int;
      }

      // If the count field doesn't exist, count the documents
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();

      return followingSnapshot.count ?? 0;
    } catch (e) {
      Logger.e('FollowService', 'Error getting following count', e);
      return 0;
    }
  }

  // Get followers for a user
  Stream<List<Map<String, dynamic>>> getFollowers(String userId) {
    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .orderBy('followedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      Logger.e('FollowService', 'Error getting followers', e);
      return Stream.value([]);
    }
  }

  // Get users that a user is following
  Stream<List<Map<String, dynamic>>> getFollowing(String userId) {
    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .orderBy('followedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      Logger.e('FollowService', 'Error getting following', e);
      return Stream.value([]);
    }
  }
}
