import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/providers/firebase_provider.dart';

import '../../models/event_model.dart';
import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/user_cache_provider.dart';
import '../../services/follow_service.dart';
import '../../utils/logger.dart';
import '../../utils/confirmation_dialog.dart';
import '../../widgets/event_feed_card.dart';
import '../../widgets/profile_image_picker_dialog.dart';

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
                  // Profile header with improved design
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _isBusinessAccount(user, onboardingData, ref)
                              ? const Color(0xFFFFD700).withAlpha(50) // Gold tint for business accounts
                              : Theme.of(context).colorScheme.primary.withAlpha(30),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Profile image with edit button for current user
                        Center(
                          child: GestureDetector(
                            onTap: widget.userId == null && user != null
                                ? () => _showProfileImagePickerDialog(context, user, onboardingData)
                                : null,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _isBusinessAccount(user, onboardingData, ref)
                                          ? const Color(0xFFFFD700) // Gold color for business
                                          : Theme.of(context).colorScheme.secondary,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(40),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60, // Larger for profile page
                                    backgroundColor: Colors.grey[300],
                                    child: _getUserProfileImage(user, onboardingData, ref),
                                  ),
                                ),
                                // Edit button overlay (only for current user's profile)
                                if (widget.userId == null && user != null)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(40),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Display name
                        Text(
                          _getUserDisplayName(user, onboardingData, ref),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Username
                        Text(
                          '@${_getUserUsername(user, onboardingData, ref)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        // Account type badge
                        if (_isBusinessAccount(user, onboardingData, ref))
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withAlpha(50),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFD700),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Business Account',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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

                  // Joined Events Section (without divider)
                  _buildJoinedEventsSection(),
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

    // Generate a unique key that includes both the user ID and a timestamp
    // This forces the widget to rebuild when the user changes
    final cacheKey = '${userId ?? "unknown"}_profile_image';

    // Add a timestamp to the URL as a query parameter to bypass cache
    final timestampedUrl = '$imageUrl${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}';

    Logger.d('ProfileScreen', 'Loading profile image for user: $userId, URL: $timestampedUrl');

    return ClipOval(
      // Use a unique key to force rebuild when user changes
      key: ValueKey('profile_image_${userId ?? "unknown"}_${DateTime.now().millisecondsSinceEpoch}'),
      child: CachedNetworkImage(
        imageUrl: timestampedUrl,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) {
          Logger.e('ProfileScreen', 'Error loading profile image: $error');
          return const Icon(Icons.error);
        },
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        cacheKey: cacheKey,
        // Disable caching in memory to ensure fresh image is loaded
        memCacheWidth: null,
        memCacheHeight: null,
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

  // Show profile image picker bottom sheet
  Future<void> _showProfileImagePickerDialog(BuildContext context, User user, OnboardingData? onboardingData) async {
    // Get current profile image URL
    String? currentImageUrl;
    if (onboardingData != null && onboardingData.profileImageUrl != null) {
      currentImageUrl = onboardingData.profileImageUrl;
    } else if (user.photoURL != null) {
      currentImageUrl = user.photoURL;
    }

    // Show the bottom sheet
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ProfileImagePickerDialog(
        currentImageUrl: currentImageUrl,
      ),
    );

    // If the image was updated successfully, refresh the profile data
    if (result == true && mounted) {
      // Clear the Flutter image cache to ensure the UI updates with the new image
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      Logger.d('ProfileScreen', 'Cleared Flutter image cache after profile image update');

      // Clear the user's image cache
      final userCacheService = ref.read(userCacheServiceProvider);
      await userCacheService.clearImageCache(user.uid);
      Logger.d('ProfileScreen', 'Cleared user image cache for: ${user.uid}');

      setState(() {
        _isLoading = true;
      });

      // Reload user data
      await _loadUserData();

      // Force a rebuild of the UI with a new timestamp to ensure fresh image loading
      if (mounted) {
        setState(() {});
      }
    }
  }



  // Build the joined events section
  Widget _buildJoinedEventsSection() {
    // Get the user ID (current user or profile user)
    final userId = widget.userId ?? ref.read(currentUserProvider)?.uid;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    // Get the event service
    final eventService = ref.read(eventServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Joined Events',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),

        // Stream builder for joined events
        StreamBuilder<List<EventModel>>(
          stream: eventService.getJoinedEvents(limit: 10),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final events = snapshot.data ?? [];

            if (events.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No joined events yet'),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return EventFeedCard(
                  event: event,
                  onJoin: () {
                    // Handle join action
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You are already joined to this event')),
                    );
                  },
                  onIgnore: null, // Disable ignore button for joined events
                  disableIgnore: true, // Gray out the ignore button
                );
              },
            );
          },
        ),
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
        // Show confirmation dialog before unfollowing
        final confirmed = await ConfirmationDialog.show(
          context: context,
          title: 'Unfollow User',
          message: 'Are you sure you want to unfollow ${_getUserDisplayName(null, null, ref)}?',
          confirmText: 'Unfollow',
          isDestructive: true,
        );

        if (!confirmed) {
          setState(() {
            _isFollowLoading = false;
          });
          return;
        }

        // Unfollow user
        await followService.unfollowUser(widget.userId!);
        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
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
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Following ${_getUserDisplayName(null, null, ref)}'))
          );
        }
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error following/unfollowing user', e);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
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
