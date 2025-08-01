import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/widgets/version_nag_banner.dart';

import '../models/event_model.dart';
import '../models/onboarding_data.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/user_cache_provider.dart';
import '../services/event_cache_service.dart';
import '../services/event_service.dart';
import '../services/rsvp_service.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';

import '../widgets/create_event_sheet.dart';
import '../widgets/event_feed.dart';
import '../widgets/event_qr_dialog.dart';
import '../widgets/home_header.dart';
import '../widgets/notification_badge.dart';
import 'auth/auth_screen.dart';
import 'notifications_screen.dart';
import 'profile/profile_screen.dart';
import 'qr/qr_scanner_screen.dart';
import 'search_screen.dart';
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
  late final PageController _pageController;

  // Stream subscriptions for real-time updates
  final List<StreamSubscription> _eventSubscriptions = [];

  // Debounce mechanism for refresh
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  // Initialize the page controller in initState to avoid issues
  @override
  void initState() {
    super.initState();

    // Initialize the page controller with the correct initial page
    final initialIndex = _filters.indexOf(_currentFilter);
    _pageController = PageController(
        initialPage: initialIndex != -1 ? initialIndex : 1, keepPage: true);

    Logger.d('HomeScreen',
        'Initialized PageController with initial page: ${initialIndex != -1 ? initialIndex : 1}');

    // Add post-frame callback to ensure the page controller is properly initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if we need to refresh events
        _checkAndRefreshEvents();

        // Check for unread notifications
        _checkForUnreadNotifications();

        // Set up real-time subscriptions for events and RSVPs
        _subscribeToEventUpdates();

        // Ensure no duplicate events in cache for all filters during initial load
        _cleanupDuplicateEvents();

        // Force a refresh of the current filter to ensure we have the latest data
        // This is especially important for private events
        _refreshCurrentFilter().then((_) {
          Logger.d('HomeScreen', 'Initial refresh completed');
        });

        setState(() {
          // Force a rebuild after initialization
        });
      }
    });
  }

  // Check if we need to refresh events and do so if needed
  Future<void> _checkAndRefreshEvents() async {
    try {
      final eventService = ref.read(eventServiceProvider);

      // Check if there are any events in the database
      final hasEvents = await eventService.hasEvents();
      Logger.d('HomeScreen', 'Database has events: $hasEvents');

      if (!hasEvents) {
        // If there are no events, refresh all filters to ensure we get the latest data
        Logger.d('HomeScreen', 'No events found, refreshing all filters');
        for (final filter in _filters) {
          await _refreshEvents(filter, eventService);
        }
      }
    } catch (e) {
      Logger.e('HomeScreen', 'Error checking and refreshing events', e);
    }
  }

  // Check for unread notifications and send push notifications if needed
  Future<void> _checkForUnreadNotifications() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.checkAndSendUnreadNotifications();
      Logger.d('HomeScreen', 'Checked for unread notifications');
    } catch (e) {
      Logger.e('HomeScreen', 'Error checking for unread notifications', e);
    }
  }

  // Manually refresh events for the current filter
  Future<void> _refreshCurrentFilter() async {
    // Debounce mechanism to prevent multiple rapid refreshes
    final now = DateTime.now();
    if (_isRefreshing) {
      Logger.d('HomeScreen', 'Already refreshing, ignoring duplicate request');
      return;
    }

    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = now.difference(_lastRefreshTime!);
      if (timeSinceLastRefresh.inSeconds < 3) {
        Logger.d('HomeScreen',
            'Refresh requested too soon (${timeSinceLastRefresh.inMilliseconds}ms since last refresh), ignoring');
        return;
      }
    }

    // Set refreshing state
    _isRefreshing = true;
    _lastRefreshTime = now;

    try {
      Logger.d('HomeScreen',
          'Manually refreshing events for filter: $_currentFilter');

      // Get the event service
      final eventService = ref.read(eventServiceProvider);

      // Get the RSVP service to check for invitations
      final rsvpService = ref.read(rsvpServiceProvider);
      final invitations = await rsvpService.getRSVPs().first;
      Logger.d('HomeScreen',
          'Found ${invitations.length} invitations during manual refresh');

      // Refresh events
      await _refreshEvents(_currentFilter, eventService);

      // Also check for unread notifications
      await _checkForUnreadNotifications();

      // Force a refresh of the event cache
      await eventService.handlePullToRefresh();

      // Cancel existing subscriptions before re-subscribing
      for (var subscription in _eventSubscriptions) {
        subscription.cancel();
      }
      _eventSubscriptions.clear();

      // Re-subscribe to real-time updates to ensure we have the latest data
      // But with a slight delay to avoid immediate triggers
      await Future.delayed(const Duration(milliseconds: 500));
      _subscribeToEventUpdates();

      // Show a snackbar to indicate refresh
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Refreshed events and notifications'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      Logger.e('HomeScreen', 'Error refreshing current filter', e);

      // Show error message
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error refreshing: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Reset refreshing state
      _isRefreshing = false;
    }
  }

  // No need for a card controller with our custom implementation

  @override
  void dispose() {
    _pageController.dispose();

    // Cancel all event subscriptions
    for (var subscription in _eventSubscriptions) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();

    super.dispose();
  }

  // Flag to prevent infinite loop between filter change and page change
  bool _isChangingPage = false;

  void _handleFilterChanged(String filter) {
    // Prevent infinite loop
    if (_isChangingPage) {
      Logger.d('HomeScreen',
          'Ignoring filter change to $filter because page is already changing');
      return;
    }

    // Don't do anything if the filter hasn't changed
    if (_currentFilter == filter) {
      Logger.d('HomeScreen', 'Filter is already set to $filter, ignoring');
      return;
    }

    Logger.d(
        'HomeScreen', 'Handling filter change from $_currentFilter to $filter');

    setState(() {
      _currentFilter = filter;
    });

    // Update page view to match selected filter
    int index = _filters.indexOf(filter);
    if (index != -1) {
      if (_pageController.hasClients) {
        Logger.d('HomeScreen', 'Animating to page $index for filter $filter');
        _isChangingPage = true;
        _pageController
            .animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
            .then((_) {
          // Reset the flag after animation completes
          if (mounted) {
            setState(() {
              _isChangingPage = false;
            });
          }
          Logger.d('HomeScreen', 'Animation to page $index completed');
        }).catchError((error) {
          // Handle any errors during animation
          if (mounted) {
            setState(() {
              _isChangingPage = false;
            });
          }
          Logger.e('HomeScreen', 'Error animating to page $index', error);
        });
      } else {
        Logger.d('HomeScreen', 'PageController has no clients, cannot animate');
        // If the controller doesn't have clients yet, we'll update it when it does
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            Logger.d('HomeScreen',
                'Delayed animation to page $index for filter $filter');
            _pageController.jumpToPage(index);
          }
        });
      }
    } else {
      Logger.e('HomeScreen', 'Invalid filter: $filter, not found in $_filters');
    }

    Logger.d('HomeScreen', 'Filter changed to: $_currentFilter');
  }

  void _handleMenuPressed() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleScanPressed() async {
    // Navigate to the QR scanner screen and wait for result
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QrScannerScreen(),
      ),
    );

    // Check if we got an event ID back from the scanner
    if (result is Map<String, dynamic> && result.containsKey('eventId')) {
      final eventId = result['eventId'] as String;
      Logger.d('HomeScreen', 'Received event ID from QR scanner: $eventId');

      // Show the event QR dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => EventQrDialog(eventId: eventId),
        );
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      // Get the current user ID before signing out
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      Logger.d('HomeScreen', 'Signing out user: $currentUserId');

      if (currentUserId == null) {
        Logger.d('HomeScreen', 'No user ID found, skipping cache clearing');
      } else {
        // Clear ALL caches before signing out

        // 1. Clear onboarding provider state
        try {
          final onboardingNotifier = ref.read(onboardingProvider.notifier);
          await onboardingNotifier.clearData();
          Logger.d('HomeScreen', 'Cleared onboarding provider state');
        } catch (e) {
          Logger.e('HomeScreen', 'Error clearing onboarding provider state', e);
        }

        // 2. Clear event cache
        try {
          final eventService = ref.read(eventServiceProvider);
          await eventService.clearCache();
          Logger.d('HomeScreen', 'Cleared event cache');
        } catch (e) {
          Logger.e('HomeScreen', 'Error clearing event cache', e);
        }

        // 3. Clear user cache service
        try {
          final userCacheService = ref.read(userCacheServiceProvider);
          await userCacheService.clearCache(currentUserId);
          Logger.d('HomeScreen', 'Cleared user cache for: $currentUserId');
        } catch (e) {
          Logger.e('HomeScreen', 'Error clearing user cache', e);
        }

        // 4. Clear storage service data - use clearAllOnboardingData to ensure all data is cleared
        try {
          final storageService = ref.read(storageServiceProvider);
          await storageService.clearAllOnboardingData();
          Logger.d('HomeScreen', 'Cleared ALL onboarding data');
        } catch (e) {
          Logger.e('HomeScreen', 'Error clearing onboarding data', e);
        }

        // 5. Clear all event cache entries
        try {
          _eventsCache.clear();
          _lastDocuments.clear();
          _hasMoreEvents.clear();
          Logger.d(
              'HomeScreen', 'Cleared all event cache entries in HomeScreen');
        } catch (e) {
          Logger.e('HomeScreen', 'Error clearing event cache entries', e);
        }
      }

      // Sign out using auth provider
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.signOut(ref);

      // Force a rebuild of the UI
      if (mounted) {
        setState(() {
          // Force UI refresh
        });
      }

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

  // Check if the user is verified
  Future<bool> _isUserVerified(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()?['verified'] ?? false;
      }
      return false;
    } catch (e) {
      Logger.e('HomeScreen', 'Error checking user verification status', e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isBusinessAccount = _isBusinessAccount(user, ref.read(onboardingProvider).value);

    return FutureBuilder<bool>(
      future: user != null ? _isUserVerified(user.uid) : Future.value(false),
      builder: (context, snapshot) {
        final isVerified = snapshot.data ?? false;

        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  height: 200,
                  color: const Color(0xFF0A2942),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 50, left: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isBusinessAccount
                                      ? const Color(0xFFFFD700)
                                      : Theme.of(context).colorScheme.secondary,
                                  width: 3,
                                ),
                                boxShadow: isBusinessAccount
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFFD700)
                                              .withAlpha(128),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[300],
                                child: _getUserProfileImage(user, null),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _getUserDisplayName(user, null),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isVerified)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: Icon(Icons.verified,
                                              color: Colors.blue, size: 20),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '@${_getUserUsername(user, null)}',
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
                ListTile(
                  leading: Icon(Icons.account_circle,
                      color: Theme.of(context).iconTheme.color),
                  title: Text('Profile',
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                StreamBuilder<int>(
                  stream:
                      ref.read(notificationServiceProvider).getUnreadCount(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.notifications,
                              color: Theme.of(context).iconTheme.color),
                          if (unreadCount > 0)
                            Positioned(
                              right: 5,
                              top: 5,
                              child: NotificationBadge(
                                count: unreadCount,
                                size: 8.0,
                              ),
                            ),
                        ],
                      ),
                      title: Text('Notifications',
                          style: Theme.of(context).textTheme.titleMedium),
                      onTap: () {
                        Navigator.pop(context);
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
                ListTile(
                  leading: Icon(Icons.settings,
                      color: Theme.of(context).iconTheme.color),
                  title: Text('Settings',
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeSettingsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout,
                      color: Theme.of(context).iconTheme.color),
                  title: Text('Sign Out',
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () {
                    Navigator.pop(context);
                    _handleSignOut(context);
                  },
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                HomeHeader(
                  onMenuPressed: _handleMenuPressed,
                  onScanPressed: _handleScanPressed,
                  onFilterChanged: _handleFilterChanged,
                  currentFilter: _currentFilter,
                ),
                const VersionNagBanner(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _filters.length,
                    onPageChanged: (index) {
                      if (!_isChangingPage) {
                        _handleFilterChanged(_getFilterName(index));
                      }
                    },
                    itemBuilder: (context, index) {
                      return KeyedSubtree(
                        key: ValueKey('page_${_filters[index]}'),
                        child: _buildFilteredContent(_filters[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton(
                  heroTag: 'search_fab',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    );
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  mini: true,
                  child: Icon(
                    Icons.search,
                    color: Theme.of(context).iconTheme.color,
                    size: 30,
                  ),
                ),
                FloatingActionButton(
                  heroTag: 'add_fab',
                  onPressed: () {
                    _showCreateEventSheet(context);
                  },
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
      },
    );
  }

  // State variables for pagination
  final Map<String, dynamic> _lastDocuments = {};
  final Map<String, List<EventModel>> _eventsCache = {};
  final Map<String, bool> _hasMoreEvents = {};
  final int _eventsPerPage = 10;
  bool _isLoadingMore = false; // Flag to prevent duplicate loading calls

  Widget _buildFilteredContent(String filter) {
    // Wrap in a try-catch to handle any unexpected errors
    try {
      // Ensure filter is valid
      if (filter.isEmpty || !_filters.contains(filter)) {
        Logger.e('HomeScreen',
            'Invalid filter provided: $filter, defaulting to NEW');
        filter = 'NEW';
      }

      final eventService = ref.watch(eventServiceProvider);
      final user = ref.watch(currentUserProvider);

      // Log authentication status
      Logger.d('HomeScreen',
          'Building filtered content for filter: $filter, user authenticated: ${user != null}');
      if (user != null) {
        Logger.d('HomeScreen', 'User ID: ${user.uid}');
      }

      // Initialize cache for this filter if not already done
      if (!_eventsCache.containsKey(filter)) {
        _eventsCache[filter] = [];
        _hasMoreEvents[filter] = true;
        Logger.d('HomeScreen', 'Initialized cache for filter: $filter');
      }

      // Use a key to ensure the StreamBuilder is recreated when the filter changes
      // This prevents issues with stale streams
      // Include a timestamp to force recreation on each build
      final streamBuilderKey =
          ValueKey('stream_${filter}_${DateTime.now().millisecondsSinceEpoch}');

      return StreamBuilder<List<EventModel>>(
        key: streamBuilderKey,
        // Only check authentication for JOINED filter, allow other filters to work without auth
        stream: (filter == 'JOINED' && !_isUserAuthenticated())
            ? Stream.value([])
            : _getFilteredEventsStream(filter, eventService),
        builder: (context, snapshot) {
          // Log the snapshot state
          Logger.d('HomeScreen',
              'StreamBuilder for filter: $filter, state: ${snapshot.connectionState}');
          if (snapshot.hasData) {
            Logger.d('HomeScreen',
                'StreamBuilder has data: ${snapshot.data!.length} events');
          }
          if (snapshot.hasError) {
            Logger.e('HomeScreen', 'StreamBuilder error for filter: $filter',
                snapshot.error);
            if (snapshot.error is Error) {
              Logger.e('HomeScreen', 'Stack trace:',
                  (snapshot.error as Error).stackTrace);
            }
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              _eventsCache[filter]!.isEmpty) {
            Logger.d(
                'HomeScreen', 'Showing loading indicator for filter: $filter');
            return const Center(child: CircularProgressIndicator());
          }

          // If we have a done state with no data and empty cache, try to refresh
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasData &&
              _eventsCache[filter]!.isEmpty) {
            Logger.d('HomeScreen',
                'Stream completed with no data, triggering refresh for: $filter');
            // Schedule a refresh after the build completes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _refreshEvents(filter, eventService);
            });
          }

          if (snapshot.hasError && _eventsCache[filter]!.isEmpty) {
            Logger.e('HomeScreen', 'Showing error UI for filter: $filter');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Theme.of(context).colorScheme.error),
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
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshEvents(filter, eventService),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          // Update cache with new data
          if (snapshot.hasData) {
            final newEvents = snapshot.data ?? [];
            Logger.d('HomeScreen',
                'Received ${newEvents.length} events for filter: $filter');

            if (newEvents.isNotEmpty) {
              // Store the last event ID for pagination
              final lastEvent = newEvents.last;
              // Store the last document ID for pagination
              _updateLastDocument(filter, lastEvent.id);
              Logger.d('HomeScreen',
                  'Updated last document for filter: $filter, ID: ${lastEvent.id}');

              // If we got fewer events than requested, there are no more to load
              if (newEvents.length < _eventsPerPage) {
                _hasMoreEvents[filter] = false;
                Logger.d('HomeScreen', 'No more events for filter: $filter');
              } else {
                _hasMoreEvents[filter] = true;
                Logger.d(
                    'HomeScreen', 'More events available for filter: $filter');
              }

              // Update the cache with improved duplicate detection
              if (_eventsCache[filter]!.isEmpty) {
                // If cache is empty, just use the new events but ensure no duplicates
                final uniqueEvents = _removeDuplicateEvents(newEvents);
                _eventsCache[filter] = List.from(uniqueEvents);
                Logger.d('HomeScreen',
                    'Cache was empty, added ${uniqueEvents.length} events for filter: $filter');
              } else {
                // Merge new events with existing ones, avoiding duplicates
                final existingIds =
                    _eventsCache[filter]!.map((e) => e.id).toSet();
                final uniqueNewEvents = newEvents
                    .where((e) => !existingIds.contains(e.id))
                    .toList();

                // Additional check to remove any potential duplicates
                final deduplicatedEvents =
                    _removeDuplicateEvents(uniqueNewEvents);

                if (deduplicatedEvents.isNotEmpty) {
                  _eventsCache[filter]!.addAll(deduplicatedEvents);
                  // Sort the cache by creation date
                  _eventsCache[filter]!
                      .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  Logger.d('HomeScreen',
                      'Added ${deduplicatedEvents.length} new events to cache for filter: $filter');
                }
              }
            } else if (_eventsCache[filter]!.isEmpty) {
              // If we got no events and the cache is empty, there are no events to show
              _hasMoreEvents[filter] = false;
              Logger.d('HomeScreen', 'No events available for filter: $filter');
            }
          }

          // Get events from cache and ensure they're deduplicated
          var events = _eventsCache[filter] ?? [];

          // Special check for duplicate events on initial load
          if (events.length > 1) {
            final deduplicated = _removeDuplicateEvents(events);
            if (deduplicated.length < events.length) {
              Logger.d('HomeScreen',
                  'Found and removed ${events.length - deduplicated.length} duplicate events in UI layer for $filter');
              events = deduplicated;
              // Update the cache with deduplicated events
              _eventsCache[filter] = deduplicated;
            }
          }

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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshEvents(filter, eventService),
                    child: const Text('Refresh'),
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
                  scrollController.position.pixels >=
                      scrollController.position.maxScrollExtent * 0.8) {
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
            onRefresh: () async {
              Logger.d(
                  'HomeScreen', 'Pull-to-refresh triggered from EventFeed');
              await _refreshCurrentFilter();
              return;
            },
          );
        },
      );
    } catch (e) {
      // If anything goes wrong, show a simple error message
      Logger.e('HomeScreen',
          'Error building filtered content for filter: $filter', e);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              e.toString(),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Force rebuild
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  // Helper method to update the last document for pagination
  void _updateLastDocument(String filter, String eventId) {
    // We'll fetch the document when we need it for pagination
    // This avoids using await in the StreamBuilder
    _lastDocuments[filter] = eventId;
  }

  // Load more events for pagination
  Future<void> _loadMoreEvents(String filter, EventService eventService) async {
    // Check if we already know there are no more events
    if (_hasMoreEvents[filter] == false) {
      Logger.d('HomeScreen', 'No more events to load for filter: $filter');
      return;
    }

    // Check if user is authenticated
    if (!_isUserAuthenticated() && filter == 'JOINED') {
      Logger.d('HomeScreen',
          'Cannot load more events for JOINED filter when user is not authenticated');
      return;
    }

    // Get the last document ID for this filter
    final lastEventId = _lastDocuments[filter];
    if (lastEventId == null) {
      Logger.d('HomeScreen', 'No last document ID for filter: $filter');
      return;
    }

    Logger.d('HomeScreen',
        'Loading more events for filter: $filter, last ID: $lastEventId');

    // Prevent duplicate loading calls
    if (_isLoadingMore) {
      Logger.d('HomeScreen', 'Already loading more events, ignoring request');
      return;
    }
    _isLoadingMore = true;

    try {
      // Get the event cache service
      final eventCacheService = ref.read(eventCacheServiceProvider);

      // Get the document snapshot for pagination
      final eventsCollection = FirebaseFirestore.instance.collection('events');
      final docSnapshot =
          await eventsCollection.doc(lastEventId as String).get();

      if (!docSnapshot.exists) {
        Logger.e('HomeScreen', 'Last event document not found: $lastEventId');
        _hasMoreEvents[filter] = false; // No more events to load
        _isLoadingMore = false;
        return;
      }

      // Get more events
      Logger.d(
          'HomeScreen', 'Fetching more events after document: $lastEventId');
      final moreEvents = await _getFilteredEventsStream(filter, eventService,
              startAfter: docSnapshot)
          .first;
      Logger.d('HomeScreen',
          'Received ${moreEvents.length} more events for filter: $filter');

      // Update the cache with the new events using improved duplicate detection
      if (moreEvents.isNotEmpty) {
        // Merge new events with existing ones, avoiding duplicates
        final existingIds = _eventsCache[filter]!.map((e) => e.id).toSet();
        final uniqueNewEvents =
            moreEvents.where((e) => !existingIds.contains(e.id)).toList();

        // Additional check to remove any potential duplicates
        final deduplicatedEvents = _removeDuplicateEvents(uniqueNewEvents);

        if (deduplicatedEvents.isNotEmpty) {
          _eventsCache[filter]!.addAll(deduplicatedEvents);
          // Sort the cache by creation date
          _eventsCache[filter]!
              .sort((a, b) => b.createdAt.compareTo(a.createdAt));
          Logger.d('HomeScreen',
              'Added ${deduplicatedEvents.length} new events to cache for filter: $filter');

          // Update the last document
          _updateLastDocument(filter, moreEvents.last.id);
          Logger.d(
              'HomeScreen', 'Updated last document to: ${moreEvents.last.id}');

          // Cache the events
          for (final event in deduplicatedEvents) {
            eventCacheService.updateEvent(event);
          }
        } else {
          Logger.d(
              'HomeScreen', 'No unique new events found for filter: $filter');
        }

        // If we got fewer events than requested, there are no more to load
        if (moreEvents.length < _eventsPerPage) {
          _hasMoreEvents[filter] = false;
          Logger.d(
              'HomeScreen', 'No more events available for filter: $filter');
        } else {
          _hasMoreEvents[filter] = true;
          Logger.d(
              'HomeScreen', 'More events may be available for filter: $filter');
        }

        // Force a rebuild
        if (mounted) {
          setState(() {});
        }
      } else {
        // No more events
        _hasMoreEvents[filter] = false;
        Logger.d('HomeScreen', 'No more events returned for filter: $filter');
      }
    } catch (e) {
      Logger.e(
          'HomeScreen', 'Error loading more events for filter: $filter', e);
      _hasMoreEvents[filter] = true; // Allow retry on error
    } finally {
      _isLoadingMore = false;
    }
  }

  Stream<List<EventModel>> _getFilteredEventsStream(
      String filter, EventService eventService,
      {DocumentSnapshot? startAfter}) {
    try {
      Logger.d('HomeScreen',
          'Getting events for filter: $filter, pagination: ${startAfter != null}, timestamp: ${DateTime.now().toIso8601String()}');

      // Ensure filter is valid
      if (filter.isEmpty || !_filters.contains(filter)) {
        Logger.e('HomeScreen',
            'Invalid filter in _getFilteredEventsStream: $filter, defaulting to NEW');
        filter = 'NEW';
      }

      // Get the appropriate stream based on the filter
      switch (filter) {
        case 'JOINED':
          // Get events that the current user has joined
          Logger.d('HomeScreen', 'Getting joined events for JOINED filter');
          return eventService
              .getJoinedEvents(limit: _eventsPerPage, startAfter: startAfter)
              .handleError((error) {
            Logger.e('HomeScreen', 'Error getting JOINED events', error);
            return <EventModel>[];
          });

        case 'NEW':
          // Get public events with pagination
          Logger.d('HomeScreen', 'Getting public events for NEW filter');
          return eventService
              .getPublicEvents(limit: _eventsPerPage, startAfter: startAfter)
              .handleError((error) {
            Logger.e('HomeScreen', 'Error getting NEW events', error);
            return <EventModel>[];
          });

        case 'SHOW ALL':
        default:
          // Get all events with pagination
          Logger.d('HomeScreen', 'Getting all events for SHOW ALL filter');
          return eventService
              .getEvents(limit: _eventsPerPage, startAfter: startAfter)
              .handleError((error) {
            Logger.e('HomeScreen', 'Error getting SHOW ALL events', error);
            return <EventModel>[];
          });
      }
    } catch (e) {
      // If anything goes wrong, log the error and return an empty stream
      Logger.e('HomeScreen', 'Error in _getFilteredEventsStream', e);
      return Stream.value(<EventModel>[]);
    }
  }

  void _handleJoinEvent(EventModel event) {
    // Get the event cache service
    final eventCacheService = ref.read(eventCacheServiceProvider);

    // Update the event in the cache service
    eventCacheService.updateEvent(event);

    // Update the event in the local cache
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
    // We don't need to update any cache service for ignored events
    // since we're just removing it from the local cache

    // Remove the event from the local cache
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

  // Helper method to get filter name by index
  String _getFilterName(int index) {
    if (index >= 0 && index < _filters.length) {
      return _filters[index];
    }
    return "NEW"; // Default to NEW if index is out of bounds
  }

  // Helper method to check if user has a business account
  bool _isBusinessAccount(User? user, OnboardingData? onboardingData) {
    if (user != null && onboardingData != null) {
      try {
        final dynamic data = onboardingData;
        // Check if the 'accountType' property exists and is 'business'
        if (data.accountType != null) {
          return data.accountType == 'business';
        }
      } catch (e) {
        Logger.d('HomeScreen',
            'Could not access "accountType" property on onboardingData: $e');
      }
    }
    return false;
  }

  bool _isBusinessVerified(User? user, OnboardingData? onboardingData) {
    if (user != null && onboardingData != null) {
      // This pattern is more robust if the provider doesn't return the specific subtype.
      // It tries to access the 'verified' property dynamically.
      try {
        final dynamic data = onboardingData;
        // Check if the 'verified' property exists and is true.
        if (data.verified != null) {
          return data.verified == true;
        }
      } catch (e) {
        // This catch block will handle cases where 'onboardingData' doesn't have a 'verified' property.
        Logger.d('HomeScreen',
            'Could not access "verified" property on onboardingData: $e');
      }
    }
    // If any of the conditions are not met, they are not a verified business.
    return false;
  }

  // Helper method to get user profile image widget
  Widget _getUserProfileImage(User? user, OnboardingData? onboardingData) {
    if (user == null) {
      return const Icon(Icons.person, size: 40, color: Colors.white70);
    }

    // Use the UserCacheService to get the profile image URL
    final cacheService = ref.read(userCacheServiceProvider);
    final imageUrl =
        cacheService.getProfileImageUrl(user.uid, onboardingData, user);

    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person, size: 40, color: Colors.white70);
    }

    // Generate a unique key that includes both the user ID and a timestamp
    // This forces the widget to rebuild when the user changes
    final cacheKey = '${user.uid}_profile_image';

    // Add a timestamp to the URL as a query parameter to bypass cache
    final timestampedUrl =
        '$imageUrl${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}';

    Logger.d('HomeScreen',
        'Loading profile image for user: ${user.uid}, URL: $timestampedUrl');

    return ClipOval(
      // Use a unique key to force rebuild when user changes
      key: ValueKey(
          'profile_image_${user.uid}_${DateTime.now().millisecondsSinceEpoch}'),
      child: CachedNetworkImage(
        imageUrl: timestampedUrl,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) {
          Logger.e('HomeScreen', 'Error loading profile image: $error');
          return const Icon(Icons.error);
        },
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        cacheKey: cacheKey,
        // Disable caching in memory to ensure fresh image is loaded
        memCacheWidth: null,
        memCacheHeight: null,
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

  // Helper method to check if the user is authenticated
  bool _isUserAuthenticated() {
    final user = ref.read(currentUserProvider);
    final isAuthenticated = user != null;
    Logger.d('HomeScreen', 'User authentication check: $isAuthenticated');
    return isAuthenticated;
  }

  // Refresh events for the current filter
  Future<void> _refreshEvents(String filter, EventService eventService) async {
    Logger.d('HomeScreen', 'Refreshing events for filter: $filter');

    try {
      // Prevent refresh while loading more events
      if (_isLoadingMore) {
        Logger.d('HomeScreen', 'Cannot refresh while loading more events');
        return;
      }

      // Check if user is authenticated for JOINED filter only
      if (!_isUserAuthenticated() && filter == 'JOINED') {
        Logger.d('HomeScreen',
            'Cannot refresh JOINED filter when user is not authenticated');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please sign in to view joined events')),
          );
        }
        return;
      }

      // For other filters, we can proceed even if the user is not authenticated

      // Use the handlePullToRefresh method to ensure proper refresh
      final refreshSuccess = await eventService.handlePullToRefresh();
      if (!refreshSuccess) {
        Logger.e('HomeScreen', 'Event cache refresh failed');
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
                content: Text('Failed to refresh events. Please try again.')),
          );
        }
        return;
      }
      Logger.d('HomeScreen', 'Event cache refreshed successfully');

      // Clear the cache for this filter
      _eventsCache[filter]?.clear();
      Logger.d('HomeScreen', 'Cleared cache for filter: $filter');

      // Reset pagination state
      _lastDocuments.remove(filter);
      _hasMoreEvents[filter] = true;

      // Get fresh events with a small delay to ensure Firestore has updated
      Logger.d('HomeScreen', 'Fetching fresh events for filter: $filter');
      await Future.delayed(const Duration(
          milliseconds: 500)); // Longer delay to ensure Firestore has updated

      // Create a new stream each time to ensure we get fresh data
      final freshEvents =
          await _getFilteredEventsStream(filter, eventService).first;
      Logger.d('HomeScreen',
          'Received ${freshEvents.length} fresh events for filter: $filter');

      // Update the cache with a new list (not the same reference), ensuring no duplicates
      final deduplicatedEvents = _removeDuplicateEvents(freshEvents);
      _eventsCache[filter] = List.from(deduplicatedEvents);
      Logger.d('HomeScreen',
          'Updated cache with ${deduplicatedEvents.length} deduplicated events for filter: $filter');

      // Check if we got any events
      if (freshEvents.isEmpty) {
        Logger.d('HomeScreen', 'No more events available for filter: $filter');
        _hasMoreEvents[filter] = false;
      } else {
        Logger.d('HomeScreen',
            'Got ${freshEvents.length} events for filter: $filter');
        _hasMoreEvents[filter] = true;

        // Update the last document if we got any events
        _updateLastDocument(filter, freshEvents.last.id);
        Logger.d(
            'HomeScreen', 'Updated last document to: ${freshEvents.last.id}');

        // If we got fewer events than requested, there are no more to load
        if (freshEvents.length < _eventsPerPage) {
          _hasMoreEvents[filter] = false;
          Logger.d(
              'HomeScreen', 'No more events available for filter: $filter');
        }
      }

      // Force a rebuild to ensure the UI updates
      if (mounted) {
        setState(() {
          // This will trigger a rebuild with the new events
        });
      }

      Logger.d('HomeScreen',
          'Refresh completed for filter: $filter, got ${freshEvents.length} events');
    } catch (e) {
      Logger.e('HomeScreen', 'Error refreshing events', e);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error refreshing events: $e')),
        );
      }
      // Don't rethrow, just log the error
    }
  }

  // Show the create event bottom sheet
  void _showCreateEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the bottom sheet expandable
      backgroundColor: Colors
          .transparent, // Transparent background to use the sheet's own decoration
      builder: (context) => const CreateEventSheet(),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height,
        maxWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  // Subscribe to real-time updates for events
  void _subscribeToEventUpdates() {
    Logger.d('HomeScreen', 'Setting up real-time event subscriptions');

    // Cancel any existing subscriptions
    for (var subscription in _eventSubscriptions) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();

    // Subscribe to all events collection for real-time updates
    final eventsSubscription = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen((snapshot) {
      Logger.d(
          'HomeScreen', 'Received real-time update from events collection');

      // Check for added, modified, or removed events
      bool hasChanges = false;

      // Process added or modified events
      for (var change in snapshot.docChanges) {
        final eventId = change.doc.id;

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          Logger.d('HomeScreen', 'Event ${change.type}: $eventId');

          // Create event model from document
          final event = EventModel.fromFirestore(change.doc);

          // Update the event in the cache service
          ref.read(eventCacheServiceProvider).updateEvent(event);

          // Update the event in our local cache for each filter
          for (final filter in _filters) {
            if (_eventsCache.containsKey(filter)) {
              final events = _eventsCache[filter]!;
              final index = events.indexWhere((e) => e.id == eventId);

              if (index != -1) {
                // Update existing event
                events[index] = event;
                hasChanges = true;
              } else if (_shouldShowEventInFilter(event, filter)) {
                // Add new event if it should be shown in this filter
                // First check if this is truly a new event (not a duplicate with different ID)
                if (!events.any((e) => e == event)) {
                  events.add(event);
                  hasChanges = true;
                  Logger.d('HomeScreen',
                      'Added new event to filter $filter: ${event.id} with content key: ${event.contentKey}');

                  // After adding, deduplicate the entire list to be safe
                  final deduplicated = _removeDuplicateEvents(events);
                  if (deduplicated.length < events.length) {
                    events.clear();
                    events.addAll(deduplicated);
                    Logger.d('HomeScreen',
                        'Removed duplicates after adding event, new count: ${events.length}');
                  }

                  // Sort the events based on filter
                  _sortEventsByFilter(events, filter);
                } else {
                  Logger.d('HomeScreen',
                      'Prevented duplicate event from being added to filter $filter: ${event.id} with content key: ${event.contentKey}');
                }
              }
            }
          }
        } else if (change.type == DocumentChangeType.removed) {
          Logger.d('HomeScreen', 'Event removed: $eventId');

          // Remove the event from our local cache for each filter
          for (final filter in _filters) {
            if (_eventsCache.containsKey(filter)) {
              final events = _eventsCache[filter]!;
              final index = events.indexWhere((e) => e.id == eventId);

              if (index != -1) {
                events.removeAt(index);
                hasChanges = true;
              }
            }
          }
        }
      }

      // Update the UI if there were changes
      if (hasChanges && mounted) {
        setState(() {});
      }
    }, onError: (error) {
      Logger.e('HomeScreen', 'Error in events subscription', error);
    });

    _eventSubscriptions.add(eventsSubscription);

    // Also subscribe to RSVPs for invitation updates
    if (_isUserAuthenticated()) {
      final rsvpSubscription = FirebaseFirestore.instance
          .collection('rsvp')
          .where('inviteeId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots()
          .listen((snapshot) {
        Logger.d(
            'HomeScreen', 'Received real-time update from RSVPs collection');

        // If there are changes to RSVPs, update the UI but don't trigger a full refresh
        if (snapshot.docChanges.isNotEmpty) {
          Logger.d('HomeScreen', 'RSVP changes detected, updating UI');

          // Instead of calling _refreshCurrentFilter which could cause a loop,
          // just update the state to refresh the UI
          if (mounted) {
            setState(() {});
          }
        }
      }, onError: (error) {
        Logger.e('HomeScreen', 'Error in RSVPs subscription', error);
      });

      _eventSubscriptions.add(rsvpSubscription);
    }

    Logger.d('HomeScreen', 'Real-time event subscriptions set up successfully');
  }

  // Helper method to determine if an event should be shown in a specific filter
  bool _shouldShowEventInFilter(EventModel event, String filter) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    switch (filter) {
      case 'JOINED':
        // Show events created by the user or joined by the user
        return currentUserId != null &&
            (event.userId == currentUserId ||
                event.joinedBy.contains(currentUserId));

      case 'NEW':
        // Show public events, events created by the user, and private events the user is invited to or has joined
        return !event.isPrivate ||
            (currentUserId != null &&
                (event.userId == currentUserId ||
                    event.joinedBy.contains(currentUserId) ||
                    event.isInvited));

      case 'SHOW ALL':
      default:
        // Show all public events and, if authenticated, private events the user has access to
        if (!event.isPrivate) return true;
        if (currentUserId == null) return false;

        return event.userId == currentUserId ||
            event.joinedBy.contains(currentUserId) ||
            event.isInvited;
    }
  }

  // Helper method to sort events based on filter
  void _sortEventsByFilter(List<EventModel> events, String filter) {
    final now = DateTime.now();

    switch (filter) {
      case 'JOINED':
      case 'NEW':
        // Sort by creation date (newest first)
        events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;

      case 'SHOW ALL':
      default:
        // Separate future and past events
        final futureEvents = <EventModel>[];
        final pastEvents = <EventModel>[];

        for (final event in events) {
          final eventDateTime = _combineDateAndTime(event.date, event.time);

          if (eventDateTime.isAfter(now)) {
            futureEvents.add(event);
          } else {
            pastEvents.add(event);
          }
        }

        // Sort future events by date (soonest first)
        futureEvents.sort((a, b) {
          final aDateTime = _combineDateAndTime(a.date, a.time);
          final bDateTime = _combineDateAndTime(b.date, b.time);
          return aDateTime.compareTo(bDateTime);
        });

        // Sort past events by date (most recent first)
        pastEvents.sort((a, b) {
          final aDateTime = _combineDateAndTime(a.date, a.time);
          final bDateTime = _combineDateAndTime(b.date, b.time);
          return bDateTime.compareTo(aDateTime);
        });

        // Replace the events list with the sorted events
        events.clear();
        events.addAll([...futureEvents, ...pastEvents]);
        break;
    }
  }

  // Helper method to combine date and time into a single DateTime
  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Helper method to remove duplicate events from a list
  List<EventModel> _removeDuplicateEvents(List<EventModel> events) {
    try {
      // Validate input list - return empty list if null
      if (events.isEmpty) {
        return [];
      }

      // Use a map to track unique events by content key
      final uniqueEvents = <String, EventModel>{};

      // Add each event to the map, using the content key to identify duplicates
      for (final event in events) {
        try {
          final contentKey = event.contentKey;

          // Skip events with empty content keys
          if (contentKey.isEmpty) {
            Logger.e('HomeScreen',
                'Skipping event with empty content key: ${event.id}');
            continue;
          }

          // If we already have an event with this content, keep the one with the non-empty ID
          if (uniqueEvents.containsKey(contentKey)) {
            final existingEvent = uniqueEvents[contentKey];

            // Skip if existing event is null (shouldn't happen, but being safe)
            if (existingEvent == null) {
              uniqueEvents[contentKey] = event;
              continue;
            }

            // If the existing event has an empty ID but the new one doesn't, replace it
            if (existingEvent.id.isEmpty && event.id.isNotEmpty) {
              uniqueEvents[contentKey] = event;
              Logger.d('HomeScreen',
                  'Replaced event with empty ID with event with ID: ${event.id}');
            }
          } else {
            // This is a new unique event
            uniqueEvents[contentKey] = event;
          }
        } catch (e) {
          // If there's an error processing this event, log it and skip
          Logger.e('HomeScreen',
              'Error processing event during deduplication: ${event.id}', e);
          continue;
        }
      }

      // Log if we found any duplicates
      if (uniqueEvents.length < events.length) {
        Logger.d('HomeScreen',
            'Removed ${events.length - uniqueEvents.length} duplicate events based on content');
      }

      // Return the values from the map as a list
      return uniqueEvents.values.toList();
    } catch (e) {
      // If anything goes wrong, log the error and return an empty list
      Logger.e('HomeScreen', 'Error in _removeDuplicateEvents', e);
      return [];
    }
  }

  // Helper method to clean up duplicate events in all filters
  void _cleanupDuplicateEvents() {
    try {
      Logger.d(
          'HomeScreen', '🧹 STARTING DUPLICATE EVENT CLEANUP ON APP STARTUP');

      // Initialize cache for each filter if not already done
      for (final filter in _filters) {
        if (!_eventsCache.containsKey(filter)) {
          _eventsCache[filter] = [];
          _hasMoreEvents[filter] = true;
          Logger.d('HomeScreen',
              'Initialized cache for filter: $filter during cleanup');
        }
      }

      // Process each filter
      for (final filter in _filters) {
        try {
          if (_eventsCache.containsKey(filter) &&
              _eventsCache[filter]!.isNotEmpty) {
            // Get the current events for this filter
            final events = _eventsCache[filter]!;

            // Get the count before deduplication
            final countBefore = events.length;

            // Apply deduplication
            final deduplicatedEvents = _removeDuplicateEvents(events);

            // Update the cache with deduplicated events
            _eventsCache[filter] = deduplicatedEvents;

            // Log the results
            final countAfter = deduplicatedEvents.length;
            if (countBefore != countAfter) {
              Logger.d('HomeScreen',
                  'Removed ${countBefore - countAfter} duplicate events from $filter filter');

              // Log details about the events for debugging
              Logger.d('HomeScreen', 'Events in $filter after deduplication:');
              for (final event in deduplicatedEvents) {
                Logger.d('HomeScreen',
                    '  Event ID: ${event.id}, Content Key: ${event.contentKey}, Inquiry: ${event.inquiry}');
              }
            } else {
              Logger.d(
                  'HomeScreen', 'No duplicate events found in $filter filter');
            }
          } else {
            Logger.d('HomeScreen', 'No events to clean up for filter: $filter');
          }
        } catch (e) {
          // If there's an error processing a specific filter, log it and continue with the next one
          Logger.e(
              'HomeScreen', 'Error cleaning up events for filter: $filter', e);
          // Ensure the filter has a valid cache entry
          _eventsCache[filter] = [];
        }
      }

      // Force a rebuild to ensure the UI updates with deduplicated events
      if (mounted) {
        setState(() {
          // This will trigger a rebuild with the deduplicated events
          Logger.d('HomeScreen', 'Forcing UI update after deduplication');
        });
      }
    } catch (e) {
      // If anything goes wrong, log the error
      Logger.e('HomeScreen', 'Error in _cleanupDuplicateEvents', e);

      // Initialize all caches to empty lists to prevent further errors
      for (final filter in _filters) {
        _eventsCache[filter] = [];
        _hasMoreEvents[filter] = true;
      }

      // Force a rebuild with empty caches
      if (mounted) {
        setState(() {
          Logger.d(
              'HomeScreen', 'Forcing UI update after error in deduplication');
        });
      }
    }
  }
}
