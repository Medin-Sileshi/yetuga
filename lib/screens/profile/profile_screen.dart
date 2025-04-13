import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/user_cache_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final onboardingDataAsync = ref.watch(onboardingProvider);

    // Get onboarding data
    OnboardingData? onboardingData;
    onboardingDataAsync.whenData((data) {
      onboardingData = data;
    });

    // No need to create a local cacheService variable here as it's used in helper methods

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view your profile'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile image
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isBusinessAccount(user, onboardingData, ref)
                              ? const Color(0xFFFFD700) // Gold color for business
                              : Theme.of(context).colorScheme.secondary,
                          width: 3,
                        ),
                        boxShadow: _isBusinessAccount(user, onboardingData, ref)
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withAlpha(128),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 60, // Larger for profile page
                        backgroundColor: Colors.grey[300],
                        child: _getUserProfileImage(user, onboardingData, ref),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display name
                  Text(
                    _getUserDisplayName(user, onboardingData, ref),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),

                  // Username
                  Text(
                    '@${_getUserUsername(user, onboardingData, ref)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                  ),

                  const SizedBox(height: 32),

                  // Account type
                  ListTile(
                    leading: Icon(
                      _isBusinessAccount(user, onboardingData, ref)
                          ? Icons.business
                          : Icons.person,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    title: const Text('Account Type'),
                    subtitle: Text(
                      _isBusinessAccount(user, onboardingData, ref)
                          ? 'Business'
                          : 'Personal',
                    ),
                  ),

                  // Email
                  if (user.email != null)
                    ListTile(
                      leading: Icon(
                        Icons.email,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      title: const Text('Email'),
                      subtitle: Text(user.email!),
                    ),

                  // Phone number
                  if (onboardingData?.phoneNumber != null)
                    ListTile(
                      leading: Icon(
                        Icons.phone,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      title: const Text('Phone'),
                      subtitle: Text(onboardingData!.phoneNumber!),
                    ),

                  // Birthday or Established date
                  if (_isBusinessAccount(user, onboardingData, ref)
                      ? onboardingData?.birthday != null
                      : onboardingData?.birthday != null)
                    ListTile(
                      leading: Icon(
                        _isBusinessAccount(user, onboardingData, ref)
                            ? Icons.calendar_today
                            : Icons.cake,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      title: Text(
                        _isBusinessAccount(user, onboardingData, ref)
                            ? 'Established'
                            : 'Birthday',
                      ),
                      subtitle: Text(
                        _formatDate(onboardingData!.birthday!),
                      ),
                    ),

                  // Interests or Business types
                  Builder(builder: (context) {
                    final interests = onboardingData?.interests;
                    if (interests != null && interests.isNotEmpty) {
                      return ListTile(
                        leading: Icon(
                          _isBusinessAccount(user, onboardingData, ref)
                              ? Icons.category
                              : Icons.interests,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        title: Text(
                          _isBusinessAccount(user, onboardingData, ref)
                              ? 'Business Types'
                              : 'Interests',
                        ),
                        subtitle: Text(interests.join(', ')),
                      );
                    } else {
                      return const SizedBox.shrink(); // Empty widget if no interests
                    }
                  }),
                ],
              ),
            ),
    );
  }

  // Helper method to check if user has a business account
  bool _isBusinessAccount(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    if (user == null) return false;

    // Use the UserCacheService to check if the user has a business account
    final cacheService = ref.read(userCacheServiceProvider);
    return cacheService.isBusinessAccount(user.uid, onboardingData);
  }

  // Helper method to get user profile image widget
  Widget _getUserProfileImage(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    if (user == null) {
      return const Icon(Icons.person, size: 60, color: Colors.white70);
    }

    // Use the UserCacheService to get the profile image URL
    final cacheService = ref.read(userCacheServiceProvider);
    final imageUrl = cacheService.getProfileImageUrl(user.uid, onboardingData, user);

    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person, size: 60, color: Colors.white70);
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        // Use user ID in the cache key to ensure user-specific caching
        cacheKey: '${user.uid}_profile_image',
      ),
    );
  }

  // Helper method to get display name
  String _getUserDisplayName(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    if (user == null) return 'User';

    // Use the UserCacheService to get the display name
    final cacheService = ref.read(userCacheServiceProvider);
    return cacheService.getDisplayName(user.uid, onboardingData, user);
  }

  // Helper method to get username
  String _getUserUsername(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    if (user == null) return 'username';

    // Use the UserCacheService to get the username
    final cacheService = ref.read(userCacheServiceProvider);
    return cacheService.getUsername(user.uid, onboardingData, user);
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
