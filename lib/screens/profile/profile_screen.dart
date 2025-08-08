import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
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

  // Navigation state
  String _currentTab = "Events"; // Default tab
  late final PageController _pageController;
  bool _isChangingPage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Initialize page controller
    _pageController = PageController(initialPage: 0, keepPage: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

      if (widget.userId != null &&
          widget.userId != ref.read(currentUserProvider)?.uid) {
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

    final isCurrentUserProfile =
        widget.userId == null || widget.userId == currentUser?.uid;
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
                  : Column(
                      children: [
                        _buildProfileBanner(
                            isCurrentUserProfile, isBusiness, isVerified),
                        const SizedBox(height: 16),
                        if (isCurrentUserProfile && isBusiness && !isVerified)
                          BusinessVerifyBanner(onVerify: _handleVerifyBusiness),
                        // Navigation tabs
                        _buildNavigationTabs(isBusiness),
                        // Main content area
                        Expanded(
                          child: _buildTabContent(),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildProfileBanner(
      bool isCurrentUserProfile, bool isBusiness, bool isVerified) {
    final userDisplayName = _userData?['displayName'] ?? 'User';
    final userUsername = _userData?['username'] ?? 'username';
    final profileImageUrl = _userData?['profileImageUrl'];
    final businessType = _userData?['businessTypes'] ?? 'Business';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0A2942),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              // Profile Image Section
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 40, bottom: 40),
                child: _buildProfileImageSection(
                    isCurrentUserProfile, isBusiness, profileImageUrl),
              ),
              const SizedBox(width: 16),
              // User Info Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 40),
                  child: _buildUserInfoSection(
                      userDisplayName, userUsername, isBusiness, isVerified),
                ),
              ),
              // Right Section with Events Count and Options
              Padding(
                padding: const EdgeInsets.only(top: 0, right: 0),
                child: _buildRightSection(
                    isCurrentUserProfile, isBusiness, businessType[0]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection(
      bool isCurrentUserProfile, bool isBusiness, String? profileImageUrl) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isBusiness
                  ? const Color(0xFFE6C34E)
                  : const Color(0xFF29C7E4),
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 35,
            backgroundColor: Colors.grey[300],
            child: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profileImageUrl,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    ),
                  )
                : const Icon(Icons.person, size: 60, color: Colors.white70),
          ),
        ),
        // Show add icon only if not following and not current user
        if (!isCurrentUserProfile && !_isFollowing)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _handleFollowButtonPressed,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A2942), width: 2),
                ),
                child: const Icon(
                  Icons.add,
                  size: 20,
                  color: Color(0xFF0A2942),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfoSection(String userDisplayName, String userUsername,
      bool isBusiness, bool isVerified) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              userDisplayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (isBusiness && isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 2.0),
                child: Icon(Icons.verified, color: Colors.blue, size: 20),
              ),
          ],
        ),
        Text(
          '@$userUsername',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCountItem('Following', _followingCount),
            const SizedBox(width: 32),
            _buildCountItem('Followers', _followersCount),
          ],
        ),
      ],
    );
  }

  Widget _buildRightSection(
      bool isCurrentUserProfile, bool isBusiness, String businessType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Business Type Label
        if (isBusiness)
          Container(
            // Remove top margin for flush alignment
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Text(
              businessType,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        // Options Menu
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _showOptionsMenu(isCurrentUserProfile),
          icon: const Icon(
            Icons.more_vert,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildCountItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showOptionsMenu(bool isCurrentUserProfile) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentUserProfile)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _showProfileImagePickerDialog(
                      context, ref.read(currentUserProvider)!);
                },
              )
            else
              ListTile(
                leading:
                    Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                title: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFollowButtonPressed();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfileImagePickerDialog(
      BuildContext context, User user) async {
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

  Widget _buildNavigationTabs(bool isBusiness) {
    // Determine available tabs based on account type
    List<String> tabs = [];

    if (isBusiness) {
      // For business accounts, check businessTypes
      final businessTypes = _userData?['businessTypes'] ?? [];
      final isRestaurant = businessTypes.contains('Restaurant');

      if (isRestaurant) {
        tabs = ["Menu", "Events"];
      } else {
        tabs = ["Services", "Events"];
      }
    } else {
      // For personal accounts, only show Events
      tabs = ["Events"];
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tabs
            .map((tab) => Expanded(
                  child: _buildTab(tab, _currentTab == tab),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _handleTabChanged(label),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(128),
            fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  void _handleTabChanged(String tab) {
    // Prevent infinite loop
    if (_isChangingPage) {
      Logger.d('ProfileScreen',
          'Ignoring tab change to $tab because page is already changing');
      return;
    }

    // Don't do anything if the tab hasn't changed
    if (_currentTab == tab) {
      Logger.d('ProfileScreen', 'Tab is already set to $tab, ignoring');
      return;
    }

    Logger.d('ProfileScreen', 'Handling tab change from $_currentTab to $tab');

    setState(() {
      _currentTab = tab;
    });

    // Update page view to match selected tab
    int index = _getTabIndex(tab);
    if (index != -1 && _pageController.hasClients) {
      Logger.d('ProfileScreen', 'Animating to page $index for tab $tab');
      _isChangingPage = true;
      _pageController
          .animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      )
          .then((_) {
        if (mounted) {
          setState(() {
            _isChangingPage = false;
          });
        }
        Logger.d('ProfileScreen', 'Animation to page $index completed');
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _isChangingPage = false;
          });
        }
        Logger.e('ProfileScreen', 'Error animating to page $index', error);
      });
    }

    Logger.d('ProfileScreen', 'Tab changed to: $_currentTab');
  }

  int _getTabIndex(String tab) {
    final isBusiness = _userData?['accountType'] == 'business';
    List<String> tabs = [];

    if (isBusiness) {
      final businessTypes = _userData?['businessTypes'] ?? [];
      final isRestaurant = businessTypes.contains('Restaurant');

      if (isRestaurant) {
        tabs = ["Menu", "Events"];
      } else {
        tabs = ["Services", "Events"];
      }
    } else {
      tabs = ["Events"];
    }

    return tabs.indexOf(tab);
  }

  Widget _buildTabContent() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _getTotalTabCount(),
      onPageChanged: (index) {
        // Only handle page change if it wasn't triggered by tab change
        if (!_isChangingPage) {
          final tab = _getTabByIndex(index);
          _handleTabChanged(tab);
        }
      },
      itemBuilder: (context, index) {
        final tab = _getTabByIndex(index);
        return KeyedSubtree(
          key: ValueKey('page_${tab}'),
          child: _buildTabContentForTab(tab),
        );
      },
    );
  }

  int _getTotalTabCount() {
    final isBusiness = _userData?['accountType'] == 'business';

    if (isBusiness) {
      final businessTypes = _userData?['businessTypes'] ?? [];
      final isRestaurant = businessTypes.contains('Restaurant');

      return isRestaurant ? 2 : 2; // Menu/Services + Events
    } else {
      return 1; // Only Events
    }
  }

  String _getTabByIndex(int index) {
    final isBusiness = _userData?['accountType'] == 'business';

    if (isBusiness) {
      final businessTypes = _userData?['businessTypes'] ?? [];
      final isRestaurant = businessTypes.contains('Restaurant');

      if (isRestaurant) {
        return index == 0 ? "Menu" : "Events";
      } else {
        return index == 0 ? "Services" : "Events";
      }
    } else {
      return "Events";
    }
  }

  Widget _buildTabContentForTab(String tab) {
    switch (tab) {
      case "Menu":
        return _buildMenuContent();
      case "Services":
        return _buildServicesContent();
      case "Events":
        return _buildEventsContent();
      default:
        return _buildEventsContent();
    }
  }

  Widget _buildMenuContent() {
    final isCurrentUserProfile = widget.userId == null ||
        widget.userId == ref.read(currentUserProvider)?.uid;

    return _buildScrollableContent(
      'menu',
      isCurrentUserProfile,
      'Add Menu Item',
      Icons.restaurant_menu,
    );
  }

  Widget _buildServicesContent() {
    final isCurrentUserProfile = widget.userId == null ||
        widget.userId == ref.read(currentUserProvider)?.uid;

    return _buildScrollableContent(
      'services',
      isCurrentUserProfile,
      'Add Service',
      Icons.miscellaneous_services,
    );
  }

  Widget _buildScrollableContent(String fieldName, bool isCurrentUserProfile,
      String addButtonText, IconData icon) {
    final items = _userData?[fieldName] as List<dynamic>? ?? [];

    if (items.isEmpty && isCurrentUserProfile) {
      // Show add button for current user when no items exist
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${fieldName == 'menu' ? 'Menu Items' : 'Services'} Yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first ${fieldName == 'menu' ? 'menu item' : 'service'} to get started',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddItemDialog(fieldName),
              icon: Icon(Icons.add),
              label: Text(addButtonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    } else if (items.isEmpty) {
      // Show empty state for other users
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${fieldName == 'menu' ? 'Menu Items' : 'Services'} Available',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This ${fieldName == 'menu' ? 'restaurant' : 'business'} hasn\'t added any ${fieldName == 'menu' ? 'menu items' : 'services'} yet',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    // Show items in a scrollable list
    return SingleChildScrollView(
      child: Column(
        children: [
          // Add button at the top for current user
          if (isCurrentUserProfile)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddItemDialog(fieldName),
                icon: const Icon(Icons.add),
                label: Text(addButtonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          // Scrollable list of items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              return _buildItemCard(
                  item, fieldName, index, isCurrentUserProfile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String fieldName, int index,
      bool isCurrentUserProfile) {
    final name = item['name'] ??
        '[ ${fieldName == 'menu' ? 'food name' : 'service name'} ]';
    final description = item['description'] ??
        '[ ${fieldName == 'menu' ? 'ingredients' : 'what the service includes'} ]';
    final price = item['price'] ?? '[ price ]';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2942), // Dark teal color matching the image
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Right side - Price and edit button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$price ETB',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrentUserProfile)
                IconButton(
                  onPressed: () => _showEditItemDialog(fieldName, index, item),
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.white70,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(String fieldName) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${fieldName == 'menu' ? 'Menu Item' : 'Service'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: fieldName == 'menu' ? 'Food Name' : 'Service Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: fieldName == 'menu' ? 'Ingredients' : 'Description',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price (ETB)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                await _addItem(fieldName, {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'price': priceController.text,
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(String fieldName, Map<String, dynamic> item) async {
    try {
      final userId = ref.read(currentUserProvider)?.uid;
      if (userId == null) return;

      final firebaseService = ref.read(firebaseServiceProvider);
      final currentItems = _userData?[fieldName] as List<dynamic>? ?? [];
      currentItems.add(item);

      await firebaseService.updateUserField(userId, fieldName, currentItems);

      // Refresh user data
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${fieldName == 'menu' ? 'Menu item' : 'Service'} added successfully')),
        );
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error adding $fieldName item', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error adding ${fieldName == 'menu' ? 'menu item' : 'service'}: $e')),
        );
      }
    }
  }

  Future<void> _updateItem(
      String fieldName, int index, Map<String, dynamic> item) async {
    try {
      final userId = ref.read(currentUserProvider)?.uid;
      if (userId == null) return;

      final firebaseService = ref.read(firebaseServiceProvider);
      final currentItems = _userData?[fieldName] as List<dynamic>? ?? [];

      if (index < currentItems.length) {
        currentItems[index] = item;
        await firebaseService.updateUserField(userId, fieldName, currentItems);

        // Refresh user data
        await _loadUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${fieldName == 'menu' ? 'Menu item' : 'Service'} updated successfully')),
          );
        }
      }
    } catch (e) {
      Logger.e('ProfileScreen', 'Error updating $fieldName item', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error updating ${fieldName == 'menu' ? 'menu item' : 'service'}: $e')),
        );
      }
    }
  }

  void _showEditItemDialog(
      String fieldName, int index, Map<String, dynamic> item) {
    final nameController = TextEditingController(text: item['name'] ?? '');
    final descriptionController =
        TextEditingController(text: item['description'] ?? '');
    final priceController = TextEditingController(text: item['price'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${fieldName == 'menu' ? 'Menu Item' : 'Service'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: fieldName == 'menu' ? 'Food Name' : 'Service Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: fieldName == 'menu' ? 'Ingredients' : 'Description',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price (ETB)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                await _updateItem(fieldName, index, {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'price': priceController.text,
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsContent() {
    // Get the user ID (current user or profile user)
    final userId = widget.userId ?? ref.read(currentUserProvider)?.uid;
    final currentUserId = ref.read(currentUserProvider)?.uid;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    // Get the event service
    final eventService = ref.read(eventServiceProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All Events Section using EventFeedCard
          StreamBuilder<List<EventModel>>(
            stream: eventService.getUserEventsFromArrays(userId, limit: 20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allEvents = snapshot.data ?? [];

              if (allEvents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No events yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: allEvents.length,
                itemBuilder: (context, index) {
                  final event = allEvents[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: EventFeedCard(
                      event: event,
                      onJoin: () {
                        // Handle join action
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('You are already joined to this event')),
                        );
                      },
                      onIgnore:
                          null, // Disable ignore button for profile events
                      disableIgnore: true, // Gray out the ignore button
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
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
              content: Text('Unfollowed ${_userData?['displayName']}')));
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
              content: Text('Following ${_userData?['displayName']}')));
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
