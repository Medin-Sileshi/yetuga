# Search Implementation Technical Documentation

## Architecture

The search functionality in the Yetu'ga app follows a layered architecture:

1. **UI Layer**: Implemented in `lib/screens/search_screen.dart`
2. **Service Layer**: 
   - User search: `lib/services/user_search_service.dart`
   - Event search: Part of `lib/services/event_service.dart`
3. **Provider Layer**: Service providers in `lib/providers/service_providers.dart`
4. **Model Layer**: Data models for users and events

## Key Components

### SearchScreen Widget

The `SearchScreen` is a `ConsumerStatefulWidget` that uses Riverpod for state management and dependency injection.

#### State Management
```dart
// Search state
String _searchQuery = '';
String _selectedActivityType = 'All';
bool _isSearching = false;
List<EventModel> _eventResults = [];
List<UserModel> _userResults = [];

// Tab state
late TabController _tabController;
int _currentPageIndex = 0;
SearchType _currentSearchType = SearchType.events;
```

#### Tab Navigation
The screen uses a combination of `TabController` and `IndexedStack` for tab navigation:

```dart
// Custom tab bar
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
        // ...
      ),
      // Users tab
      // ...
    ],
  ),
),

// Content display
IndexedStack(
  index: _currentPageIndex,
  children: [
    // Events tab content
    // Users tab content
  ],
)
```

#### Search Logic
The search functionality is implemented in the `_performSearch()` method:

```dart
Future<void> _performSearch() async {
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
    }
  } catch (e) {
    // Error handling
  }
}
```

### UserSearchService

The `UserSearchService` provides methods for searching users and managing follow relationships:

#### User Search
```dart
Future<List<UserModel>> searchUsers(String query) async {
  try {
    if (query.isEmpty) {
      return [];
    }

    // Normalize the query
    final normalizedQuery = query.toLowerCase().trim();
    
    // Search by displayName and username
    final displayNameQuery = _firestore.collection('users')
        .orderBy('displayName')
        .startAt([normalizedQuery])
        .endAt([normalizedQuery + '\uf8ff'])
        .limit(20);
        
    final usernameQuery = _firestore.collection('users')
        .orderBy('username')
        .startAt([normalizedQuery])
        .endAt([normalizedQuery + '\uf8ff'])
        .limit(20);
    
    // Execute queries and combine results
    // ...
    
    // Check following status
    // ...
    
    // Sort results by relevance
    // ...
    
    return users;
  } catch (e) {
    // Error handling
    return [];
  }
}
```

#### Follow/Unfollow
```dart
Future<bool> followUser(String userId) async {
  try {
    // Add to following collection
    await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('following')
        .doc(userId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // Add to followers collection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .doc(_currentUserId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    return true;
  } catch (e) {
    // Error handling
    return false;
  }
}

Future<bool> unfollowUser(String userId) async {
  try {
    // Remove from following collection
    await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('following')
        .doc(userId)
        .delete();
    
    // Remove from followers collection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .doc(_currentUserId)
        .delete();
    
    return true;
  } catch (e) {
    // Error handling
    return false;
  }
}
```

### Service Providers

The service providers are defined in `lib/providers/service_providers.dart`:

```dart
// User Search Service Provider
final userSearchServiceProvider = Provider<UserSearchService>((ref) {
  return UserSearchService();
});

// Event Service Provider
final eventServiceProvider = Provider<EventService>((ref) {
  final eventCacheService = ref.watch(eventCacheServiceProvider);
  final batchService = ref.watch(batchServiceProvider);
  final retryService = ref.watch(retryServiceProvider);
  return EventService(eventCacheService, batchService, retryService);
});
```

## Data Models

### UserModel
```dart
class UserModel {
  final String id;
  final String displayName;
  final String username;
  final String? profileImageUrl;
  final String accountType;
  final bool isFollowing;

  UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    this.profileImageUrl,
    required this.accountType,
    this.isFollowing = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc, {bool isFollowing = false}) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'User',
      username: data['username'] as String? ?? 'username',
      profileImageUrl: data['profileImageUrl'] as String?,
      accountType: data['accountType'] as String? ?? 'personal',
      isFollowing: isFollowing,
    );
  }
}
```

## Performance Considerations

1. **Query Optimization**:
   - Limit query results to 20 items
   - Use compound queries to search by multiple fields
   - Use startAt/endAt for prefix matching

2. **UI Optimization**:
   - Use IndexedStack to maintain tab state
   - Implement proper loading states
   - Check widget mounting state before updating

3. **Error Handling**:
   - Comprehensive try/catch blocks
   - Detailed logging for debugging
   - Graceful fallbacks for error states

## Recent Improvements

1. **Tab Navigation**:
   - Replaced PageView with IndexedStack for more reliable tab switching
   - Disabled swipe gestures for more controlled navigation
   - Added direct state updates when switching tabs

2. **Search Logic**:
   - Separated event and user search logic
   - Added specific handling for empty queries
   - Improved error handling with mounted checks

3. **UI Enhancements**:
   - Updated tab styling to use _currentPageIndex
   - Added visual feedback for selected tabs
   - Improved loading states

4. **Debugging**:
   - Added detailed logging throughout the search process
   - Included state information in log messages
   - Added post-frame callbacks for initialization
