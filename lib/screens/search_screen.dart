import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../providers/service_providers.dart';
import '../services/user_search_service.dart' hide userSearchServiceProvider;
import '../utils/logger.dart';
import '../utils/confirmation_dialog.dart';
import '../widgets/event_feed_card.dart';
import 'profile/profile_screen.dart';

// Define search type enum at the top level
enum SearchType { events, users }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedActivityType = 'All';
  bool _isSearching = false;
  List<EventModel> _eventResults = [];
  List<UserModel> _userResults = [];

  // Page controller for switching between tabs
  late PageController _pageController;

  // Current page index
  int _currentPageIndex = 0;

  // Tab controller for switching between events and users
  late TabController _tabController;

  // Current search type
  SearchType _currentSearchType = SearchType.events;

  // List of activity types for filtering
  final List<String> _activityTypes = [
    'All',
    'Walk',
    'Run',
    'Visit',
    'Eat',
    'Celebrate',
    'Watch',
    'Play',
    'Drink',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _pageController = PageController(initialPage: 0);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Add a listener to update the UI when the search type changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        // Ensure the UI is in sync with the current search type
        _currentPageIndex = _currentSearchType == SearchType.events ? 0 : 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      Logger.d('SearchScreen', 'Tab changed to ${_tabController.index}');

      setState(() {
        _currentPageIndex = _tabController.index;
        _currentSearchType = _tabController.index == 0 ? SearchType.events : SearchType.users;
      });

      // Always perform search when switching to Users tab
      if (_tabController.index == 1) {
        _performSearch();
      } else if (_searchQuery.isNotEmpty || _selectedActivityType != 'All') {
        _performSearch();
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });

    // Debounce search to avoid too many queries
    if (_searchQuery.isNotEmpty) {
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    Logger.d('SearchScreen', 'Performing search: type=$_currentSearchType, query="$_searchQuery", activityType=$_selectedActivityType');

    // For events tab: If search is empty and no activity type filter, clear results
    if (_currentSearchType == SearchType.events && _searchQuery.isEmpty && _selectedActivityType == 'All') {
      setState(() {
        _eventResults = [];
        _isSearching = false;
      });
      return;
    }

    // For users tab: If search is empty, clear results
    if (_currentSearchType == SearchType.users && _searchQuery.isEmpty) {
      setState(() {
        _userResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      if (_currentSearchType == SearchType.events) {
        // Search for events
        final eventService = ref.read(eventServiceProvider);
        final results = await eventService.searchEvents(
          query: _searchQuery,
          activityType: _selectedActivityType == 'All' ? null : _selectedActivityType,
        );

        if (mounted) {
          setState(() {
            _eventResults = results;
            _isSearching = false;
          });
        }
        Logger.d('SearchScreen', 'Event search completed: ${results.length} results');
      } else {
        // Search for users
        final userSearchService = ref.read(userSearchServiceProvider);
        final results = await userSearchService.searchUsers(_searchQuery);

        if (mounted) {
          setState(() {
            _userResults = results;
            _isSearching = false;
          });
        }
        Logger.d('SearchScreen', 'User search completed: ${results.length} results, currentTab=${_tabController.index}, currentSearchType=$_currentSearchType');
      }
    } catch (e) {
      Logger.e('SearchScreen', 'Error performing search', e);
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // Build a user list item
  Widget _buildUserListItem(UserModel user) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final borderColor = user.accountType == 'business'
        ? Colors.amber
        : primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: user.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Profile image with border
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                      ? Text(
                          user.displayName[0].toUpperCase(),
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(179), // 0.7 opacity
                      ),
                    ),
                  ],
                ),
              ),
              // Follow/Unfollow button
              ElevatedButton(
                onPressed: () async {
                  final userSearchService = ref.read(userSearchServiceProvider);
                  if (user.isFollowing) {
                    // Show confirmation dialog before unfollowing
                    final confirmed = await ConfirmationDialog.show(
                      context: context,
                      title: 'Unfollow User',
                      message: 'Are you sure you want to unfollow ${user.displayName}?',
                      confirmText: 'Unfollow',
                      isDestructive: true,
                    );

                    if (!confirmed) {
                      return;
                    }

                    final success = await userSearchService.unfollowUser(user.id);
                    if (success) {
                      setState(() {
                        final index = _userResults.indexWhere((u) => u.id == user.id);
                        if (index != -1) {
                          _userResults[index] = UserModel(
                            id: user.id,
                            displayName: user.displayName,
                            username: user.username,
                            profileImageUrl: user.profileImageUrl,
                            accountType: user.accountType,
                            isFollowing: false,
                          );
                        }
                      });

                      // Show a snackbar
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Unfollowed ${user.displayName}'))
                        );
                      }
                    }
                  } else {
                    final success = await userSearchService.followUser(user.id);
                    if (success) {
                      setState(() {
                        final index = _userResults.indexWhere((u) => u.id == user.id);
                        if (index != -1) {
                          _userResults[index] = UserModel(
                            id: user.id,
                            displayName: user.displayName,
                            username: user.username,
                            profileImageUrl: user.profileImageUrl,
                            accountType: user.accountType,
                            isFollowing: true,
                          );
                        }
                      });

                      // Show a snackbar
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Following ${user.displayName}'))
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.isFollowing ? Colors.grey.withAlpha(51) : primaryColor, // 0.2 opacity
                  foregroundColor: user.isFollowing ? theme.textTheme.bodyMedium?.color : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(user.isFollowing ? 'Unfollow' : 'Follow'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final hintColor = textColor.withAlpha(153); // 0.6 opacity
    final borderColor = theme.dividerColor;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.search,
              color: hintColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: hintColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  border: InputBorder.none,
                ),
                autofocus: true,
              ),
            ),
          ],
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _eventResults = [];
                  _userResults = [];
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Custom tab bar for switching between events and users
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Events tab
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPageIndex = 0;
                      _currentSearchType = SearchType.events;
                    });
                    _tabController.animateTo(0);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'EVENTS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _currentPageIndex == 0 ? FontWeight.bold : FontWeight.w300,
                        color: _currentPageIndex == 0 ? primaryColor : hintColor,
                      ),
                    ),
                  ),
                ),

                // Users tab
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPageIndex = 1;
                      _currentSearchType = SearchType.users;
                    });
                    _tabController.animateTo(1);
                    _performSearch(); // Perform search when switching to Users tab
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'USERS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _currentPageIndex == 1 ? FontWeight.bold : FontWeight.w300,
                        color: _currentPageIndex == 1 ? primaryColor : hintColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Activity type filter (only show for events tab)
          if (_currentPageIndex == 0)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _activityTypes.map((type) {
                          final isSelected = type == _selectedActivityType;

                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedActivityType = type;
                                });
                                _performSearch();
                              },
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected ? primaryColor : hintColor,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w300,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _currentPageIndex,
                    children: [
                      // Events tab
                      _eventResults.isEmpty
                          ? Center(
                              child: _searchQuery.isEmpty && _selectedActivityType == 'All'
                                  ? const Text('Enter a search term or select an activity type')
                                  : const Text('No events found'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _eventResults.length,
                              itemBuilder: (context, index) {
                                final event = _eventResults[index];
                                return EventFeedCard(
                                  event: event,
                                  onJoin: () {
                                    // Refresh search results after joining
                                    _performSearch();
                                  },
                                  onIgnore: () {
                                    // Remove the event from search results
                                    setState(() {
                                      _eventResults.removeWhere((e) => e.id == event.id);
                                    });
                                  },
                                );
                              },
                            ),

                      // Users tab
                      _userResults.isEmpty
                          ? Center(
                              child: _searchQuery.isEmpty
                                  ? const Text('Enter a search term to find users')
                                  : const Text('No users found'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _userResults.length,
                              itemBuilder: (context, index) {
                                final user = _userResults[index];
                                return _buildUserListItem(user);
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
