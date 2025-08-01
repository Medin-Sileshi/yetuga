import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/event_model.dart';
import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/user_cache_provider.dart';
import '../../utils/logger.dart';
import '../../utils/confirmation_dialog.dart';
import '../../widgets/event_feed_card.dart';
import '../../widgets/profile_image_picker_dialog.dart';
import '../../widgets/payment_webview.dart';
import '../../services/follow_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileId = widget.userId ?? ref.read(currentUserProvider)?.uid;
      if (profileId == null) {
        throw Exception("User not found");
      }

      final firebaseService = ref.read(firebaseServiceProvider);
      _userData = await firebaseService.getUserProfileById(profileId);
      Logger.d('ProfileScreen', 'Loaded profile data for user: $profileId');

      if (widget.userId != null && widget.userId != ref.read(currentUserProvider)?.uid) {
        await _loadFollowData();
      } else {
        await _loadFollowCounts(profileId);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error loading user data', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load profile: $e';
        });
      }
    }
  }

  Future<void> _loadFollowData() async {
    if (widget.userId == null) return;
    try {
      final followService = ref.read(followServiceProvider);
      final isFollowing = await followService.isFollowing(widget.userId!);
      await _loadFollowCounts(widget.userId!);

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error loading follow data', e);
    }
  }

  Future<void> _loadFollowCounts(String userId) async {
    try {
      final followService = ref.read(followServiceProvider);
      final followersCount = await followService.getFollowersCount(userId);
      final followingCount = await followService.getFollowingCount(userId);
      if (mounted) {
        setState(() {
          _followersCount = followersCount;
          _followingCount = followingCount;
        });
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error loading follow counts', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    final isCurrentUserProfile = widget.userId == null || widget.userId == currentUser?.uid;
    final isBusiness = _userData?['accountType'] == 'business';
    final isVerified = _userData?['verified'] == true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _userData == null
                  ? const Center(child: Text('User profile not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildProfileHeader(isCurrentUserProfile, isBusiness, isVerified),
                          const SizedBox(height: 16),
                          if (!isCurrentUserProfile)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: _buildFollowButton(),
                            ),
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
                          if (isCurrentUserProfile && isBusiness && !isVerified)
                            BusinessVerifyBanner(onVerify: _handleVerifyBusiness),
                          _buildJoinedEventsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProfileHeader(bool isCurrentUserProfile, bool isBusiness, bool isVerified) {
    final userDisplayName = _userData?['displayName'] ?? 'User';
    final userUsername = _userData?['username'] ?? 'username';
    final profileImageUrl = _userData?['profileImageUrl'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isBusiness
                ? const Color(0xFFFFD700).withAlpha(50)
                : Theme.of(context).colorScheme.primary.withAlpha(30),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: isCurrentUserProfile
                ? () => _showProfileImagePickerDialog(context, ref.read(currentUserProvider)!)
                : null,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isBusiness
                          ? const Color(0xFFFFD700)
                          : Theme.of(context).colorScheme.secondary,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              placeholder: (context, url) => const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                          )
                        : const Icon(Icons.person, size: 60, color: Colors.white70),
                  ),
                ),
                if (isCurrentUserProfile)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                userDisplayName,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (isBusiness && isVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.verified, color: Colors.blue, size: 20),
                ),
            ],
          ),
          Text(
            '@$userUsername',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          if (isBusiness)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withAlpha(50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
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
    );
  }

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

  Future<void> _showProfileImagePickerDialog(BuildContext context, User user) async {
    // Get current profile image URL
    String? currentImageUrl;
    if (user.photoURL != null) {
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
      Logger.d('ProfileScreen',
          'Cleared Flutter image cache after profile image update');

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
                      const SnackBar(
                          content:
                              Text('You are already joined to this event')),
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
          message:
              'Are you sure you want to unfollow ${_userData?['displayName']}?',
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
          scaffoldMessenger.showSnackBar(SnackBar(
              content:
                  Text('Unfollowed ${_userData?['displayName']}')));
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
          scaffoldMessenger.showSnackBar(SnackBar(
              content:
                  Text('Following ${_userData?['displayName']}')));
        }
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error following/unfollowing user', e);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        _isFollowLoading = false;
      });
    }
  }

  Future<Map<String, String>?> _showNameInputDialog() async {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false, // User must enter names or cancel
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Full Name'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(
                  height: 30,
                ),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop({
                    'firstName': firstNameController.text.trim(),
                    'lastName': lastNameController.text.trim(),
                  });
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _handleVerifyBusiness() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Business Verification'),
        content: const Text(
            'To verify your business account, you need to make a one-time payment of 500 ETB. Do you want to proceed to payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Prompt for user's name after confirmation
    final names = await _showNameInputDialog();
    if (names == null) return; // User cancelled the name input dialog

    final user = ref.read(currentUserProvider);
    final email = user?.email ?? '';
    final phone = user?.phoneNumber ?? '';
    final userId = user?.uid;

    final firstName = names['firstName']!;
    final lastName = names['lastName']!;

    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User details are missing.')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse(
            'https://us-central1-yetuga-1d0d9.cloudfunctions.net/createPaymentSession/create-payment-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'email': email,
          'amount': '500',
          'currency': 'ETB',
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'description': '500 ETB to verify your account on Yetuga.',
        }),
      );

      if (context.mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data['checkoutUrl'];

        if (checkoutUrl != null && context.mounted) {
          final verificationStream = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots();

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PaymentWebView(url: checkoutUrl),
            ),
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Verifying payment, please wait...')),
            );
          }

          // Listen for the verification update
          final sub = verificationStream.listen((snapshot) {
            if (snapshot.exists && snapshot.data()?['verified'] == true) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Business verified successfully!')),
                );
                _loadUserData(); // Refresh profile data
              }
            }
          });

          // Cancel the listener after a timeout
          Future.delayed(const Duration(seconds: 60), () {
            sub.cancel();
          });
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to get payment URL.')),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error creating payment session: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }
}

// Banner widget for business verification
class BusinessVerifyBanner extends StatelessWidget {
  final VoidCallback onVerify;
  const BusinessVerifyBanner({super.key, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your business account is not verified. Tap verify to start the process.',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: onVerify,
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}
