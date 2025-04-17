import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/providers/firebase_provider.dart';

import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/user_cache_provider.dart';
import '../../services/follow_service.dart';
import '../../utils/logger.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // Optional userId parameter, if null shows current user's profile

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? _profileUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  // Follow-related state
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Set the profile user (current user or null if viewing someone else's profile)
      _profileUser = widget.userId == null ? ref.read(currentUserProvider) : null;

      // If userId is provided, load that user's data from Firestore
      if (widget.userId != null) {
        final firebaseService = ref.read(firebaseServiceProvider);
        _userData = await firebaseService.getUserProfileById(widget.userId!);
        Logger.d('ProfileScreen', 'Loaded profile data for user: ${widget.userId}');

        // Load follow data only when viewing another user's profile
        await _loadFollowData();
      } else {
        // Load follow counts for current user
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          await _loadFollowCounts(currentUser.uid);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Logger.e('ProfileScreen', 'Error loading user data', e);
      setState(() {
        _isLoading = false;
        _error = 'Failed to load profile: $e';
      });
    }
  }

  // Load follow data (follow status and counts)
  Future<void> _loadFollowData() async {
    if (widget.userId == null) return;

    try {
      final followService = ref.read(followServiceProvider);

      // Check if current user is following this profile
      final isFollowing = await followService.isFollowing(widget.userId!);

      // Get follower and following counts
      final followersCount = await followService.getFollowersCount(widget.userId!);
      final followingCount = await followService.getFollowingCount(widget.userId!);

      setState(() {
        _isFollowing = isFollowing;
        _followersCount = followersCount;
        _followingCount = followingCount;
      });

      Logger.d('ProfileScreen', 'Loaded follow data: isFollowing=$isFollowing, followers=$followersCount, following=$followingCount');
    } catch (e) {
      Logger.e('ProfileScreen', 'Error loading follow data', e);
      // Don't set error state, as this is not critical
    }
  }

  // Load follow counts for a user
  Future<void> _loadFollowCounts(String userId) async {
    try {
      final followService = ref.read(followServiceProvider);

      // Get follower and following counts
      final followersCount = await followService.getFollowersCount(userId);
      final followingCount = await followService.getFollowingCount(userId);

      setState(() {
        _followersCount = followersCount;
        _followingCount = followingCount;
      });

      Logger.d('ProfileScreen', 'Loaded follow counts: followers=$followersCount, following=$followingCount');
    } catch (e) {
      Logger.e('ProfileScreen', 'Error loading follow counts', e);
      // Don't set error state, as this is not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only use these providers for the current user
    final theme = Theme.of(context);
    final user = widget.userId == null ? ref.watch(currentUserProvider) : _profileUser;
    final onboardingDataAsync = widget.userId == null ? ref.watch(onboardingProvider) : null;

    // Get onboarding data for current user
    OnboardingData? onboardingData;
    if (onboardingDataAsync != null) {
      onboardingDataAsync.whenData((data) {
        onboardingData = data;
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : (user == null && widget.userId == null)
                  ? const Center(child: Text('Please sign in to view your profile'))
                  : (widget.userId != null && _userData == null)
                      ? const Center(child: Text('User profile not found'))
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

                  // Follow/Unfollow button (only show when viewing other profiles)
                  if (widget.userId != null && ref.read(currentUserProvider) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: _buildFollowButton(),
                    ),

                  // Followers and following counts
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCountItem('Followers', _followersCount),
                        const SizedBox(width: 32),
                        _buildCountItem('Following', _followingCount),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

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
                  if (user?.email != null || (_userData != null && _userData!['email'] != null))
                    ListTile(
                      leading: Icon(
                        Icons.email,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      title: const Text('Email'),
                      subtitle: Text(
                        user?.email ?? _userData!['email'] ?? 'Not available',
                      ),
                    ),

                  // Phone number
                  if (onboardingData?.phoneNumber != null || (_userData != null && _userData!['phoneNumber'] != null))
                    ListTile(
                      leading: Icon(
                        Icons.phone,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      title: const Text('Phone'),
                      subtitle: Text(
                        onboardingData?.phoneNumber ?? _userData!['phoneNumber'] ?? 'Not available',
                      ),
                    ),

                  // Birthday or Established date
                  if (_hasBirthdayOrEstablishedDate(user, onboardingData))
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
                        _getFormattedDate(user, onboardingData),
                      ),
                    ),

                  // Interests or Business types
                  Builder(builder: (context) {
                    final List<String> interests = _getInterestsOrBusinessTypes(user, onboardingData);
                    if (interests.isNotEmpty) {
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
    if (widget.userId != null) {
      // For other user's profile, check account type from Firestore data
      if (_userData != null && _userData!.containsKey('accountType')) {
        final accountType = _userData!['accountType'] as String?;
        return accountType == 'business';
      }
      return false;
    } else if (user != null) {
      // For current user's profile, use the cache service
      final cacheService = ref.read(userCacheServiceProvider);
      return cacheService.isBusinessAccount(user.uid, onboardingData);
    }

    return false;
  }

  // Helper method to get user profile image widget
  Widget _getUserProfileImage(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    String? imageUrl;
    String? userId;

    if (widget.userId != null) {
      // For other user's profile, get image URL from Firestore data
      userId = widget.userId;
      if (_userData != null && _userData!.containsKey('profileImageUrl')) {
        imageUrl = _userData!['profileImageUrl'] as String?;
      }
    } else if (user != null) {
      // For current user's profile, use the cache service
      userId = user.uid;
      final cacheService = ref.read(userCacheServiceProvider);
      imageUrl = cacheService.getProfileImageUrl(user.uid, onboardingData, user);
    }

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
        cacheKey: '${userId ?? "unknown"}_profile_image',
      ),
    );
  }

  // Helper method to get display name
  String _getUserDisplayName(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    if (widget.userId != null) {
      // For other user's profile, get display name from Firestore data
      if (_userData != null && _userData!.containsKey('displayName')) {
        final displayName = _userData!['displayName'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
      return 'User';
    } else if (user != null) {
      // For current user's profile, use the cache service
      final cacheService = ref.read(userCacheServiceProvider);
      return cacheService.getDisplayName(user.uid, onboardingData, user);
    }

    return 'User';
  }

  // Helper method to get username
  String _getUserUsername(User? user, OnboardingData? onboardingData, WidgetRef ref) {
    if (widget.userId != null) {
      // For other user's profile, get username from Firestore data
      if (_userData != null && _userData!.containsKey('username')) {
        final username = _userData!['username'] as String?;
        if (username != null && username.isNotEmpty) {
          return username;
        }
      }
      return 'username';
    } else if (user != null) {
      // For current user's profile, use the cache service
      final cacheService = ref.read(userCacheServiceProvider);
      return cacheService.getUsername(user.uid, onboardingData, user);
    }

    return 'username';
  }

  // Helper method to check if user has birthday or established date
  bool _hasBirthdayOrEstablishedDate(User? user, OnboardingData? onboardingData) {
    if (onboardingData?.birthday != null) {
      return true;
    }

    if (_userData != null) {
      // Check for birthday or establishedDate in Firestore data
      if (_userData!.containsKey('birthday') && _userData!['birthday'] != null) {
        return true;
      }
      if (_userData!.containsKey('establishedDate') && _userData!['establishedDate'] != null) {
        return true;
      }
    }

    return false;
  }

  // Helper method to get formatted date
  String _getFormattedDate(User? user, OnboardingData? onboardingData) {
    // First try to get from onboarding data
    if (onboardingData?.birthday != null) {
      return _formatDate(onboardingData!.birthday!);
    }

    // Then try to get from Firestore data
    if (_userData != null) {
      if (_userData!.containsKey('birthday') && _userData!['birthday'] != null) {
        final timestamp = _userData!['birthday'] as dynamic;
        if (timestamp is DateTime) {
          return _formatDate(timestamp);
        } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
          // Handle Firestore Timestamp
          final seconds = timestamp.seconds as int;
          final nanoseconds = timestamp.nanoseconds as int;
          final dateTime = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          );
          return _formatDate(dateTime);
        }
      }

      if (_userData!.containsKey('establishedDate') && _userData!['establishedDate'] != null) {
        final timestamp = _userData!['establishedDate'] as dynamic;
        if (timestamp is DateTime) {
          return _formatDate(timestamp);
        } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
          // Handle Firestore Timestamp
          final seconds = timestamp.seconds as int;
          final nanoseconds = timestamp.nanoseconds as int;
          final dateTime = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          );
          return _formatDate(dateTime);
        }
      }
    }

    return 'Not available';
  }

  // Helper method to get interests or business types
  List<String> _getInterestsOrBusinessTypes(User? user, OnboardingData? onboardingData) {
    // First try to get from onboarding data
    if (onboardingData?.interests != null && onboardingData!.interests!.isNotEmpty) {
      return onboardingData.interests!;
    }

    // Then try to get from Firestore data
    if (_userData != null) {
      if (_userData!.containsKey('interests') && _userData!['interests'] != null) {
        final interests = _userData!['interests'] as List<dynamic>?;
        if (interests != null) {
          return interests.map((e) => e.toString()).toList();
        }
      }

      if (_userData!.containsKey('businessTypes') && _userData!['businessTypes'] != null) {
        final businessTypes = _userData!['businessTypes'] as List<dynamic>?;
        if (businessTypes != null) {
          return businessTypes.map((e) => e.toString()).toList();
        }
      }
    }

    return [];
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Build follow/unfollow button
  Widget _buildFollowButton() {
    return _isFollowLoading
        ? const CircularProgressIndicator()
        : ElevatedButton(
            onPressed: _handleFollowButtonPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing
                  ? Colors.grey[300]
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: _isFollowing
                  ? Colors.black87
                  : Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
          );
  }

  // Build count item (followers/following)
  Widget _buildCountItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  // Handle follow/unfollow button press
  Future<void> _handleFollowButtonPressed() async {
    if (widget.userId == null) return;

    setState(() {
      _isFollowLoading = true;
    });

    try {
      final followService = ref.read(followServiceProvider);

      if (_isFollowing) {
        // Unfollow user
        await followService.unfollowUser(widget.userId!);
        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unfollowed ${_getUserDisplayName(null, null, ref)}'))
          );
        }
      } else {
        // Follow user
        await followService.followUser(widget.userId!);
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Following ${_getUserDisplayName(null, null, ref)}'))
          );
        }
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error following/unfollowing user', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    } finally {
      setState(() {
        _isFollowLoading = false;
      });
    }
  }
}
