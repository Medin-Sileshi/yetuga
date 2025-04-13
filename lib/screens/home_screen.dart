import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding_data.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/user_cache_provider.dart';
import '../utils/logger.dart';
import '../widgets/create_event_sheet.dart';
import '../widgets/home_header.dart';
import 'auth/auth_screen.dart';
import 'profile/profile_screen.dart';
import 'settings/theme_settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _currentFilter = "NEW"; // Default filter
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List of available filters
  final List<String> _filters = ["JOINED", "NEW", "SHOW ALL"];

  // Controller for page view
  final PageController _pageController = PageController(initialPage: 1); // Default to NEW

  @override
  void initState() {
    super.initState();
    // Update page controller to the correct index after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _getFilterIndex();
      if (index != 1) { // Only update if not already at the default index
        _pageController.jumpToPage(index);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleFilterChanged(String filter) {
    setState(() {
      _currentFilter = filter;
    });

    // Update page view to match selected filter
    int index = _filters.indexOf(filter);
    if (index != -1 && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    Logger.d('HomeScreen', 'Filter changed to: $_currentFilter');
  }

  void _handleMenuPressed() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleScanPressed() {
    // QR code scanning functionality will be implemented later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR code scanning coming soon!')),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (context.mounted) {
        // Navigate back to auth screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final onboardingDataAsync = ref.watch(onboardingProvider);

    // Get onboarding data for profile image
    OnboardingData? onboardingData;
    onboardingDataAsync.whenData((data) {
      onboardingData = data;
    });

    return Scaffold(
      key: _scaffoldKey,
      // Use theme's background color instead of hardcoding it

      drawer: Drawer(
        // Use the same background color as the rest of the app
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Custom drawer header with close button
              Container(
                height: 200,
                color: const Color(0xFF0A2942), // Fixed color for both light and dark themes
                child: Stack(
                  children: [
                    // Close button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    // User profile section
                    Padding(
                      padding: const EdgeInsets.only(top: 50, left: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profile picture with border
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                // Golden border for business accounts, secondary color for personal
                                color: _isBusinessAccount(user, onboardingData)
                                  ? const Color(0xFFFFD700) // Gold color
                                  : Theme.of(context).colorScheme.secondary,
                                width: 3,
                              ),
                              // Add glow effect for business accounts
                              boxShadow: _isBusinessAccount(user, onboardingData)
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withAlpha(128), // 0.5 opacity
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[300],
                              child: _getUserProfileImage(user, onboardingData),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // User info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getUserDisplayName(user, onboardingData),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '@${_getUserUsername(user, onboardingData)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Profile button
            ListTile(
              leading: Icon(Icons.account_circle, color: Theme.of(context).iconTheme.color),
              title: Text('Profile', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            // Settings button
            ListTile(
              leading: Icon(Icons.settings, color: Theme.of(context).iconTheme.color),
              title: Text('Settings', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).iconTheme.color),
              title: Text('Sign Out', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _handleSignOut(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header with filter tabs
            HomeHeader(
              onMenuPressed: _handleMenuPressed,
              onScanPressed: _handleScanPressed,
              onFilterChanged: _handleFilterChanged,
              currentFilter: _currentFilter,
            ),

            // Main content area with swipe support
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  _handleFilterChanged(_getFilterName(index));
                },
                children: [
                  _buildFilteredContent("JOINED"),
                  _buildFilteredContent("NEW"),
                  _buildFilteredContent("SHOW ALL"),
                ],
              ),
            ),
          ],
        ),
      ),

      // Search floating action button at bottom left
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Search button at bottom left
            FloatingActionButton(
              heroTag: 'search_fab',
              onPressed: () {
                // Handle search button press
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search button pressed')),
                );
              },
              // Make it look like a simple icon button
              backgroundColor: Colors.transparent,
              elevation: 0,
              mini: true,
              child: Icon(
                Icons.search,
                color: Theme.of(context).iconTheme.color,
                size: 30,
              ),
            ),

            // Add button at bottom right
            FloatingActionButton(
              heroTag: 'add_fab',
              onPressed: () {
                // Show the create event bottom sheet
                _showCreateEventSheet(context);
              },
              // Make it look like a simple icon button
              backgroundColor: Colors.transparent,
              elevation: 0,
              mini: true,
              child: Icon(
                Icons.add,
                color: Theme.of(context).iconTheme.color,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredContent(String filter) {
    // This will be replaced with actual filtered content
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Current Filter: $filter',
            style: TextStyle(
              // Use theme's text color
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Content for $filter will be displayed here',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to get the current filter index
  int _getFilterIndex() {
    int index = _filters.indexOf(_currentFilter);
    return index != -1 ? index : 1; // Default to NEW (index 1) if not found
  }

  // Helper method to get filter name by index
  String _getFilterName(int index) {
    if (index >= 0 && index < _filters.length) {
      return _filters[index];
    }
    return "NEW"; // Default to NEW if index is out of bounds
  }

  // Helper method to check if user has a business account
  bool _isBusinessAccount(User? user, OnboardingData? onboardingData) {
    if (user == null) return false;

    // Use the UserCacheService to check if the user has a business account
    final cacheService = ref.read(userCacheServiceProvider);
    return cacheService.isBusinessAccount(user.uid, onboardingData);
  }

  // Helper method to get user profile image widget
  Widget _getUserProfileImage(User? user, OnboardingData? onboardingData) {
    if (user == null) {
      return const Icon(Icons.person, size: 40, color: Colors.white70);
    }

    // Use the UserCacheService to get the profile image URL
    final cacheService = ref.read(userCacheServiceProvider);
    final imageUrl = cacheService.getProfileImageUrl(user.uid, onboardingData, user);

    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person, size: 40, color: Colors.white70);
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        // Use user ID in the cache key to ensure user-specific caching
        cacheKey: '${user.uid}_profile_image',
      ),
    );
  }

  // Helper method to get display name
  String _getUserDisplayName(User? user, OnboardingData? onboardingData) {
    if (user == null) return 'User';

    // Use the UserCacheService to get the display name
    final cacheService = ref.read(userCacheServiceProvider);
    return cacheService.getDisplayName(user.uid, onboardingData, user);
  }

  // Helper method to get username
  String _getUserUsername(User? user, OnboardingData? onboardingData) {
    if (user == null) return 'username';

    // Use the UserCacheService to get the username
    final cacheService = ref.read(userCacheServiceProvider);
    return cacheService.getUsername(user.uid, onboardingData, user);
  }

  // Show the create event bottom sheet
  void _showCreateEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the bottom sheet expandable
      backgroundColor: Colors.transparent, // Transparent background to use the sheet's own decoration
      builder: (context) => const CreateEventSheet(),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height,
        maxWidth: MediaQuery.of(context).size.width,
      ),
    );
  }
}
