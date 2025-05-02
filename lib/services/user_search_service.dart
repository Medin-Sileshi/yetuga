import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

// Provider for the UserSearchService
final userSearchServiceProvider = Provider<UserSearchService>((ref) {
  return UserSearchService();
});

class UserModel {
  final String id;
  final String displayName;
  final String username;
  final String? profileImageUrl;
  final String accountType;
  final bool isFollowing;

  UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    this.profileImageUrl,
    required this.accountType,
    this.isFollowing = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc, {bool isFollowing = false}) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'User',
      username: data['username'] as String? ?? 'username',
      profileImageUrl: data['profileImageUrl'] as String?,
      accountType: data['accountType'] as String? ?? 'personal',
      isFollowing: isFollowing,
    );
  }
}

class UserSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Search users by query
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      Logger.d('UserSearchService', 'Searching users with query: "$query"');

      if (query.isEmpty) {
        return [];
      }

      // Normalize the query
      final normalizedQuery = query.toLowerCase().trim();

      // Get users where displayName or username contains the query
      // Firestore doesn't support direct contains queries, so we'll use startAt and endAt
      // with the query and query + '\uf8ff' (high code point) to simulate a "starts with" query

      // First, search by displayName
      final displayNameQuery = _firestore.collection('users')
          .orderBy('displayName')
          .startAt([normalizedQuery])
          .endAt(['$normalizedQuery\uf8ff'])
          .limit(20);

      // Then, search by username
      final usernameQuery = _firestore.collection('users')
          .orderBy('username')
          .startAt([normalizedQuery])
          .endAt(['$normalizedQuery\uf8ff'])
          .limit(20);

      // Execute both queries
      final displayNameSnapshot = await displayNameQuery.get();
      final usernameSnapshot = await usernameQuery.get();

      // Combine results, avoiding duplicates
      final Map<String, UserModel> userMap = {};

      // Process displayName results
      for (final doc in displayNameSnapshot.docs) {
        userMap[doc.id] = UserModel.fromFirestore(doc);
      }

      // Process username results
      for (final doc in usernameSnapshot.docs) {
        if (!userMap.containsKey(doc.id)) {
          userMap[doc.id] = UserModel.fromFirestore(doc);
        }
      }

      // Convert to list
      final users = userMap.values.toList();

      // If the current user is in the results, remove them
      users.removeWhere((user) => user.id == _currentUserId);

      // Check which users the current user is following
      if (_currentUserId.isNotEmpty && users.isNotEmpty) {
        final followingSnapshot = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('following')
            .get();

        final followingIds = followingSnapshot.docs.map((doc) => doc.id).toSet();

        // Update isFollowing status
        for (int i = 0; i < users.length; i++) {
          final user = users[i];
          if (followingIds.contains(user.id)) {
            users[i] = UserModel(
              id: user.id,
              displayName: user.displayName,
              username: user.username,
              profileImageUrl: user.profileImageUrl,
              accountType: user.accountType,
              isFollowing: true,
            );
          }
        }
      }

      // Sort results by relevance
      users.sort((a, b) {
        // First, prioritize exact matches
        final aExactMatch = a.displayName.toLowerCase() == normalizedQuery ||
                           a.username.toLowerCase() == normalizedQuery;
        final bExactMatch = b.displayName.toLowerCase() == normalizedQuery ||
                           b.username.toLowerCase() == normalizedQuery;

        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;

        // Then, prioritize business accounts
        final aIsBusiness = a.accountType == 'business';
        final bIsBusiness = b.accountType == 'business';

        if (aIsBusiness && !bIsBusiness) return -1;
        if (!aIsBusiness && bIsBusiness) return 1;

        // Finally, sort alphabetically by display name
        return a.displayName.compareTo(b.displayName);
      });

      Logger.d('UserSearchService', 'Search returned ${users.length} users');
      return users;
    } catch (e) {
      Logger.e('UserSearchService', 'Error searching users', e);
      return [];
    }
  }

  // Follow a user
  Future<bool> followUser(String userId) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      if (_currentUserId == userId) {
        throw Exception('Cannot follow yourself');
      }

      // Add to following collection
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('following')
          .doc(userId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add to followers collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(_currentUserId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      Logger.e('UserSearchService', 'Error following user', e);
      return false;
    }
  }

  // Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Remove from following collection
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('following')
          .doc(userId)
          .delete();

      // Remove from followers collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(_currentUserId)
          .delete();

      return true;
    } catch (e) {
      Logger.e('UserSearchService', 'Error unfollowing user', e);
      return false;
    }
  }
}
