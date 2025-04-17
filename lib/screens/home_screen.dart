import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_model.dart';
import '../models/onboarding_data.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/user_cache_provider.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';
import '../widgets/create_event_sheet.dart';
import '../widgets/event_feed.dart';
import '../widgets/home_header.dart';
import 'auth/auth_screen.dart';
import 'notifications_screen.dart';
import 'profile/profile_screen.dart';
import 'qr/qr_scanner_screen.dart';
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

  // No need for a card controller with our custom implementation

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
    // Navigate to the QR scanner screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QrScannerScreen(),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.signOut(ref);
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
            // Notifications button with badge
            StreamBuilder<int>(
              stream: ref.read(notificationServiceProvider).getUnreadCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return ListTile(
                  leading: Stack(
                    children: [
                      Icon(Icons.notifications, color: Theme.of(context).iconTheme.color),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
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

  // State variables for pagination
  final Map<String, dynamic> _lastDocuments = {};
  final Map<String, List<EventModel>> _eventsCache = {};
  final Map<String, bool> _hasMoreEvents = {};
  final int _eventsPerPage = 10;

  Widget _buildFilteredContent(String filter) {
    final eventService = ref.watch(eventServiceProvider);

    // Initialize cache for this filter if not already done
    if (!_eventsCache.containsKey(filter)) {
      _eventsCache[filter] = [];
      _hasMoreEvents[filter] = true;
    }

    return StreamBuilder<List<EventModel>>(
      stream: _getFilteredEventsStream(filter, eventService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _eventsCache[filter]!.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && _eventsCache[filter]!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading events',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Update cache with new data
        if (snapshot.hasData) {
          final newEvents = snapshot.data ?? [];

          if (newEvents.isNotEmpty) {
            // Store the last event ID for pagination
            if (snapshot.data!.isNotEmpty) {
              final lastEvent = snapshot.data!.last;
              // Store the last document ID for pagination
              _updateLastDocument(filter, lastEvent.id);
            }

            // If we got fewer events than requested, there are no more to load
            if (newEvents.length < _eventsPerPage) {
              _hasMoreEvents[filter] = false;
            }

            // Update the cache
            if (_eventsCache[filter]!.isEmpty) {
              _eventsCache[filter] = newEvents;
            } else {
              // Merge new events with existing ones, avoiding duplicates
              final existingIds = _eventsCache[filter]!.map((e) => e.id).toSet();
              final uniqueNewEvents = newEvents.where((e) => !existingIds.contains(e.id)).toList();
              _eventsCache[filter]!.addAll(uniqueNewEvents);
            }
          } else if (_eventsCache[filter]!.isEmpty) {
            // If we got no events and the cache is empty, there are no events to show
            _hasMoreEvents[filter] = false;
          }
        }

        final events = _eventsCache[filter] ?? [];

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No events available',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filter == 'JOINED'
                      ? 'You haven\'t joined or created any events yet'
                      : 'Check back later or create a new event',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          );
        }

        // Create a scroll controller for pagination
        final scrollController = ScrollController();

        // Add post-frame callback to ensure the controller is attached before adding listener
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollController.addListener(() {
            // Check if we've scrolled to the bottom
            if (scrollController.hasClients &&
                scrollController.position.pixels >= scrollController.position.maxScrollExtent * 0.8) {
              // Load more events when reaching 80% of the list
              if (_hasMoreEvents[filter] == true) {
                _loadMoreEvents(filter, eventService);
              }
            }
          });
        });

        return EventFeed(
          events: events,
          onJoin: _handleJoinEvent,
          onIgnore: _handleIgnoreEvent,
          scrollController: scrollController,
          filterType: filter,
        );
      },
    );
  }

  // Helper method to update the last document for pagination
  void _updateLastDocument(String filter, String eventId) {
    // We'll fetch the document when we need it for pagination
    // This avoids using await in the StreamBuilder
    _lastDocuments[filter] = eventId;
  }

  // Load more events for pagination
  Future<void> _loadMoreEvents(String filter, EventService eventService) async {
    if (_hasMoreEvents[filter] == false) return;

    // Get the last document ID for this filter
    final lastEventId = _lastDocuments[filter];
    if (lastEventId == null) return;

    // Fetch the actual document to use for pagination
    try {
      final eventsCollection = FirebaseFirestore.instance.collection('events');
      final docRef = eventsCollection.doc(lastEventId as String);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Mark that we're loading more events to prevent duplicate calls
        _hasMoreEvents[filter] = false;

        // Get more events
        final moreEvents = await _getFilteredEventsStream(filter, eventService, startAfter: docSnapshot)
            .first;

        // Update the cache with the new events
        if (moreEvents.isNotEmpty) {
          // Merge new events with existing ones, avoiding duplicates
          final existingIds = _eventsCache[filter]!.map((e) => e.id).toSet();
          final uniqueNewEvents = moreEvents.where((e) => !existingIds.contains(e.id)).toList();
          _eventsCache[filter]!.addAll(uniqueNewEvents);

          // Update the last document
          if (moreEvents.isNotEmpty) {
            _updateLastDocument(filter, moreEvents.last.id);
          }

          // If we got fewer events than requested, there are no more to load
          if (moreEvents.length < _eventsPerPage) {
            _hasMoreEvents[filter] = false;
          } else {
            _hasMoreEvents[filter] = true;
          }

          // Force a rebuild
          if (mounted) {
            setState(() {});
          }
        } else {
          // No more events
          _hasMoreEvents[filter] = false;
        }
      }
    } catch (e) {
      Logger.e('HomeScreen', 'Error loading more events', e);
      _hasMoreEvents[filter] = true; // Allow retry on error
    }
  }

  Stream<List<EventModel>> _getFilteredEventsStream(String filter, EventService eventService, {DocumentSnapshot? startAfter}) {
    Logger.d('HomeScreen', 'Getting events for filter: $filter, pagination: ${startAfter != null}');

    switch (filter) {
      case 'JOINED':
        // Get events that the current user has joined
        Logger.d('HomeScreen', 'Getting joined events for JOINED filter');
        return eventService.getJoinedEvents(limit: _eventsPerPage, startAfter: startAfter);

      case 'NEW':
        // Get public events with pagination
        Logger.d('HomeScreen', 'Getting public events for NEW filter');
        return eventService.getPublicEvents(limit: _eventsPerPage, startAfter: startAfter);

      case 'SHOW ALL':
      default:
        // Get all events with pagination
        Logger.d('HomeScreen', 'Getting all events for SHOW ALL filter');
        return eventService.getEvents(limit: _eventsPerPage, startAfter: startAfter);
    }
  }

  void _handleJoinEvent(EventModel event) {
    // Update the event in the cache
    for (final filter in _filters) {
      if (_eventsCache.containsKey(filter)) {
        final events = _eventsCache[filter]!;
        final index = events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          // Update the event in the cache
          setState(() {
            events[index] = event;
          });
        }
      }
    }

    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joined event: ${event.inquiry}')),
    );
  }

  void _handleIgnoreEvent(EventModel event) {
    // Remove the event from the cache
    for (final filter in _filters) {
      if (_eventsCache.containsKey(filter)) {
        final events = _eventsCache[filter]!;
        final index = events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          // Remove the event from the cache
          setState(() {
            events.removeAt(index);
          });
        }
      }
    }

    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ignored event: ${event.inquiry}')),
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
