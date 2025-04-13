import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/onboarding_data.dart';
import '../utils/logger.dart';

class UserCacheService {
  static final UserCacheService _instance = UserCacheService._internal();
  static const String _cacheBoxName = 'user_cache';
  
  // Private constructor
  UserCacheService._internal();
  
  // Factory constructor to return the same instance
  factory UserCacheService() {
    return _instance;
  }
  
  // Initialize the cache service
  Future<void> init() async {
    try {
      Logger.d('UserCacheService', 'Initializing user cache service...');
      if (!Hive.isBoxOpen(_cacheBoxName)) {
        await Hive.openBox(_cacheBoxName);
      }
      Logger.d('UserCacheService', 'User cache service initialized successfully');
    } catch (e) {
      Logger.d('UserCacheService', 'Failed to initialize user cache service: $e');
    }
  }
  
  // Get the user's profile image URL from cache or onboarding data
  String? getProfileImageUrl(String userId, OnboardingData? onboardingData, User? user) {
    try {
      // First try to get from onboarding data
      if (onboardingData != null && onboardingData.profileImageUrl != null && onboardingData.profileImageUrl!.isNotEmpty) {
        // Cache the URL for future use
        _cacheProfileImageUrl(userId, onboardingData.profileImageUrl!);
        return onboardingData.profileImageUrl!;
      }
      
      // Then try to get from Firebase user
      if (user?.photoURL != null) {
        // Cache the URL for future use
        _cacheProfileImageUrl(userId, user!.photoURL!);
        return user.photoURL!;
      }
      
      // Finally, try to get from cache
      final cachedUrl = _getCachedProfileImageUrl(userId);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        return cachedUrl;
      }
      
      return null;
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting profile image URL: $e');
      return null;
    }
  }
  
  // Get the user's display name from cache or onboarding data
  String getDisplayName(String userId, OnboardingData? onboardingData, User? user) {
    try {
      // First try to get from onboarding data
      if (onboardingData != null && onboardingData.displayName != null && onboardingData.displayName!.isNotEmpty) {
        // Cache the display name for future use
        _cacheDisplayName(userId, onboardingData.displayName!);
        return onboardingData.displayName!;
      }
      
      // Then try to get from Firebase user
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        // Cache the display name for future use
        _cacheDisplayName(userId, user.displayName!);
        return user.displayName!;
      }
      
      // Finally, try to get from cache
      final cachedName = _getCachedDisplayName(userId);
      if (cachedName != null && cachedName.isNotEmpty) {
        return cachedName;
      }
      
      return 'User';
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting display name: $e');
      return 'User';
    }
  }
  
  // Get the user's username from cache or onboarding data
  String getUsername(String userId, OnboardingData? onboardingData, User? user) {
    try {
      // First try to get from onboarding data
      if (onboardingData != null && onboardingData.username != null && onboardingData.username!.isNotEmpty) {
        // Cache the username for future use
        _cacheUsername(userId, onboardingData.username!);
        return onboardingData.username!;
      }
      
      // Then try to get from email (if available)
      if (user?.email != null) {
        final emailUsername = user!.email!.split('@').first;
        // Cache the username for future use
        _cacheUsername(userId, emailUsername);
        return emailUsername;
      }
      
      // Finally, try to get from cache
      final cachedUsername = _getCachedUsername(userId);
      if (cachedUsername != null && cachedUsername.isNotEmpty) {
        return cachedUsername;
      }
      
      return 'username';
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting username: $e');
      return 'username';
    }
  }
  
  // Check if the user has a business account
  bool isBusinessAccount(String userId, OnboardingData? onboardingData) {
    try {
      // First try to get from onboarding data
      if (onboardingData != null && onboardingData.accountType != null) {
        final isBusiness = onboardingData.accountType == 'business';
        // Cache the account type for future use
        _cacheAccountType(userId, isBusiness);
        return isBusiness;
      }
      
      // Finally, try to get from cache
      final cachedIsBusiness = _getCachedAccountType(userId);
      if (cachedIsBusiness != null) {
        return cachedIsBusiness;
      }
      
      return false;
    } catch (e) {
      Logger.d('UserCacheService', 'Error checking if business account: $e');
      return false;
    }
  }
  
  // Pre-cache the user's profile image
  void preCacheProfileImage(String userId, String imageUrl) {
    try {
      if (imageUrl.isNotEmpty) {
        // Cache the URL
        _cacheProfileImageUrl(userId, imageUrl);
        
        // Pre-cache the image
        CachedNetworkImage(imageUrl: imageUrl);
        Logger.d('UserCacheService', 'Pre-cached profile image: $imageUrl');
      }
    } catch (e) {
      Logger.d('UserCacheService', 'Error pre-caching profile image: $e');
    }
  }
  
  // Clear the cache for a specific user
  Future<void> clearCache(String userId) async {
    try {
      final box = Hive.box(_cacheBoxName);
      await box.delete('${userId}_profileImageUrl');
      await box.delete('${userId}_displayName');
      await box.delete('${userId}_username');
      await box.delete('${userId}_accountType');
      Logger.d('UserCacheService', 'Cleared cache for user: $userId');
    } catch (e) {
      Logger.d('UserCacheService', 'Error clearing cache: $e');
    }
  }
  
  // Clear all cached data
  Future<void> clearAllCache() async {
    try {
      final box = Hive.box(_cacheBoxName);
      await box.clear();
      Logger.d('UserCacheService', 'Cleared all cache');
    } catch (e) {
      Logger.d('UserCacheService', 'Error clearing all cache: $e');
    }
  }
  
  // Private methods for caching and retrieving data
  void _cacheProfileImageUrl(String userId, String url) {
    try {
      final box = Hive.box(_cacheBoxName);
      box.put('${userId}_profileImageUrl', url);
    } catch (e) {
      Logger.d('UserCacheService', 'Error caching profile image URL: $e');
    }
  }
  
  String? _getCachedProfileImageUrl(String userId) {
    try {
      final box = Hive.box(_cacheBoxName);
      return box.get('${userId}_profileImageUrl');
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting cached profile image URL: $e');
      return null;
    }
  }
  
  void _cacheDisplayName(String userId, String name) {
    try {
      final box = Hive.box(_cacheBoxName);
      box.put('${userId}_displayName', name);
    } catch (e) {
      Logger.d('UserCacheService', 'Error caching display name: $e');
    }
  }
  
  String? _getCachedDisplayName(String userId) {
    try {
      final box = Hive.box(_cacheBoxName);
      return box.get('${userId}_displayName');
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting cached display name: $e');
      return null;
    }
  }
  
  void _cacheUsername(String userId, String username) {
    try {
      final box = Hive.box(_cacheBoxName);
      box.put('${userId}_username', username);
    } catch (e) {
      Logger.d('UserCacheService', 'Error caching username: $e');
    }
  }
  
  String? _getCachedUsername(String userId) {
    try {
      final box = Hive.box(_cacheBoxName);
      return box.get('${userId}_username');
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting cached username: $e');
      return null;
    }
  }
  
  void _cacheAccountType(String userId, bool isBusiness) {
    try {
      final box = Hive.box(_cacheBoxName);
      box.put('${userId}_accountType', isBusiness);
    } catch (e) {
      Logger.d('UserCacheService', 'Error caching account type: $e');
    }
  }
  
  bool? _getCachedAccountType(String userId) {
    try {
      final box = Hive.box(_cacheBoxName);
      return box.get('${userId}_accountType');
    } catch (e) {
      Logger.d('UserCacheService', 'Error getting cached account type: $e');
      return null;
    }
  }
}

// Singleton instance
final userCacheService = UserCacheService();
