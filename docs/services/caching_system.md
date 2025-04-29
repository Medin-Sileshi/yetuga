# Caching System Documentation

## Overview

The Yetu'ga application implements a sophisticated multi-level caching system to improve performance, reduce network requests, and provide offline functionality. The caching system uses Hive for persistent storage of complex data structures and combines it with in-memory caching for frequently accessed data.

## Architecture

The caching system consists of several components:

1. **Hive Storage**: Persistent NoSQL database for complex data structures
2. **CacheManager**: General-purpose caching utility with memory and disk layers
3. **EventCacheService**: Specialized cache for event data
4. **UserCacheService**: Specialized cache for user profile data
5. **PrefetchService**: Proactive data loading based on user behavior

## Hive Implementation

### Setup and Initialization

Hive is initialized in the application's main entry point:

```dart
// Initialize Hive
await Hive.initFlutter();

// Register adapters
Hive.registerAdapter(OnboardingDataAdapter());
Hive.registerAdapter(OnboardingCacheAdapter());

// Open the boxes
await Hive.openBox<OnboardingData>('onboarding');
await Hive.openBox<OnboardingCache>('onboarding_cache');
await Hive.openBox('user_cache');
```

### Data Models

The application uses Hive to store several types of complex data:

#### OnboardingData

```dart
@HiveType(typeId: 0)
class OnboardingData extends HiveObject {
  @HiveField(0)
  String? accountType;

  @HiveField(1)
  String? displayName;

  @HiveField(2)
  DateTime? birthday;

  @HiveField(3)
  String? phoneNumber;

  @HiveField(4)
  String? profileImageUrl;

  @HiveField(5)
  List<String>? interests;

  @HiveField(6)
  String? username;

  @HiveField(7)
  bool onboardingCompleted = false;
}
```

#### BusinessOnboardingData

```dart
@HiveType(typeId: 1)
class BusinessOnboardingData extends HiveObject {
  @HiveField(0)
  String? accountType;

  @HiveField(1)
  String? businessName;

  @HiveField(2)
  DateTime? establishedDate;

  @HiveField(3)
  String? phoneNumber;

  @HiveField(4)
  String? profileImageUrl;

  @HiveField(5)
  List<String>? businessTypes;

  @HiveField(6)
  String? username;

  @HiveField(7)
  bool onboardingCompleted = false;
}
```

#### OnboardingCache

```dart
@HiveType(typeId: 2)
class OnboardingCache extends HiveObject {
  @HiveField(0)
  final String? accountType;

  @HiveField(1)
  final String? displayName;

  @HiveField(2)
  final String? username;

  @HiveField(3)
  final DateTime? birthday;

  @HiveField(4)
  final String? phoneNumber;

  @HiveField(5)
  final String? profileImageUrl;

  @HiveField(6)
  final List<String>? interests;

  @HiveField(7)
  final bool isComplete;
}
```

## CacheManager

The `CacheManager` provides a general-purpose caching mechanism with both in-memory and disk storage layers.

### Features

- **Priority-based caching**: Different expiration times based on data importance
- **LRU (Least Recently Used) eviction policy**: Automatically removes least used items when cache is full
- **Size limits**: Configurable limits for both memory and disk cache
- **Expiration handling**: Automatic removal of expired cache entries
- **Type-safe retrieval**: Generic methods for type-safe data access

### Usage

```dart
// Store data in cache
await cacheManager.put(
  'user_profile_123',
  userProfileData,
  priority: CacheManager.PRIORITY_HIGH,
);

// Retrieve data from cache
final profile = await cacheManager.get<UserProfile>('user_profile_123');

// Remove data from cache
await cacheManager.remove('user_profile_123');

// Clear all cache
await cacheManager.clearAll();
```

### Implementation Details

The `CacheManager` uses a two-tier approach:

1. **Memory Cache**: Fast access using a Map with `_CacheEntry` objects
2. **Disk Cache**: Persistent storage using Hive for metadata and SharedPreferences for data

```dart
// Memory cache entry
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final DateTime expirationTime;
  final int priority;
  DateTime lastAccessed;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expirationTime,
    required this.priority,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? DateTime.now();
}
```

## EventCacheService

The `EventCacheService` provides specialized caching for event data, optimizing for the specific access patterns of events.

### Features

- **In-memory event cache**: Fast access to recently used events
- **Automatic expiration**: Events expire after 5 minutes by default
- **Batch retrieval**: Efficient loading of multiple events
- **Firestore integration**: Automatic fallback to Firestore for cache misses

### Usage

```dart
// Get an event (from cache or Firestore)
final event = await eventCacheService.getEvent('event_123');

// Update an event in the cache
eventCacheService.updateEvent(updatedEvent);

// Get multiple events
final events = await eventCacheService.getEvents(['event_1', 'event_2', 'event_3']);

// Clear the cache
eventCacheService.clearCache();
```

### Implementation Details

The `EventCacheService` uses a Map-based in-memory cache with timestamp tracking:

```dart
// Cache for events
final Map<String, EventModel> _eventCache = {};

// Cache expiration time (5 minutes)
final Duration _cacheExpiration = const Duration(minutes: 5);

// Cache timestamps to track when events were added
final Map<String, DateTime> _cacheTimestamps = {};
```

## UserCacheService

The `UserCacheService` provides specialized caching for user profile data, optimizing for frequent access to user information.

### Features

- **Profile image caching**: Stores URLs for profile images
- **User data caching**: Stores display names, usernames, and account types
- **Per-user cache keys**: Organizes cache by user ID
- **Hive persistence**: Uses Hive for persistent storage

### Usage

```dart
// Get a user's profile image URL
final imageUrl = await userCacheService.getProfileImageUrl('user_123');

// Get a user's display name
final displayName = await userCacheService.getDisplayName('user_123');

// Update a user's profile data
await userCacheService.updateUserProfile('user_123', 'John Doe', 'johndoe', 'https://example.com/profile.jpg', false);

// Clear cache for a specific user
await userCacheService.clearCache('user_123');
```

### Implementation Details

The `UserCacheService` uses a Hive box with compound keys:

```dart
// Cache key format: '{userId}_{dataType}'
// Example: 'user_123_profileImageUrl'

void _cacheProfileImageUrl(String userId, String url) {
  try {
    final box = Hive.box(_cacheBoxName);
    box.put('${userId}_profileImageUrl', url);
  } catch (e) {
    Logger.d('UserCacheService', 'Error caching profile image URL: $e');
  }
}
```

## Integration with RetryService

The caching system integrates with the `RetryService` to provide robust data access:

```dart
// Get an event with retry logic and cache
Future<EventModel?> getEventWithRetry(String eventId) async {
  try {
    // First check the cache
    EventModel? event = await _eventCacheService.getEvent(eventId);
    if (event != null) {
      return event;
    }

    // If not in cache, get from Firestore with retry logic
    return await _retryService.executeWithRetryAndFallback<EventModel?>(
      operation: () async {
        final docSnapshot = await _eventsCollection.doc(eventId).get();
        if (!docSnapshot.exists) {
          return null;
        }

        final event = EventModel.fromFirestore(docSnapshot);

        // Update the cache
        _eventCacheService.updateEvent(event);

        return event;
      },
      fallbackValue: null,
      maxRetries: 3,
      shouldRetry: _retryService.isFirestoreRetryableError,
      operationName: 'getEvent($eventId)',
    );
  } catch (e) {
    Logger.e('EventService', 'Error getting event with retry', e);
    return null;
  }
}
```

## PrefetchService

The `PrefetchService` proactively loads data that the user is likely to need, based on usage patterns.

### Features

- **Event view tracking**: Records which events users view
- **User interaction tracking**: Records user interactions
- **Popularity-based prefetching**: Loads popular content proactively
- **Background prefetching**: Loads data in the background during idle time

### Usage

```dart
// Track when a user views an event
await prefetchService.trackEventView('event_123');

// Track user interaction
await prefetchService.trackUserInteraction('user_456');

// Force prefetch of popular content
await prefetchService.prefetchPopularContent();

// Prefetch events for a specific user
await prefetchService.prefetchUserEvents('user_123');
```

### Implementation Details

The `PrefetchService` uses the `CacheManager` for storing prefetched data and updates the `EventCacheService`:

```dart
// Prefetch each event
for (final eventId in topEventIds) {
  try {
    // Check if already in cache and not expired
    final cachedEvent = await _cacheManager.get<EventModel>('event_$eventId');
    if (cachedEvent != null) {
      continue; // Skip if already cached
    }

    // Fetch from Firestore
    final docSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();

    if (docSnapshot.exists) {
      final event = EventModel.fromFirestore(docSnapshot);

      // Cache with high priority
      await _cacheManager.put(
        'event_$eventId',
        event,
        priority: CacheManager.PRIORITY_HIGH,
      );

      // Also update the event cache service
      _eventCacheService.updateEvent(event);
    }
  } catch (e) {
    Logger.e('PrefetchService', 'Error prefetching event: $eventId', e);
    // Continue with next event
  }
}
```

## Testing

The application includes dedicated test screens for the caching system:

### CacheTestScreen

Allows testing of the `CacheManager` with UI controls for:
- Storing data in the cache
- Retrieving data from the cache
- Removing data from the cache
- Clearing the entire cache

### PrefetchTestScreen

Allows testing of the `PrefetchService` with UI controls for:
- Forcing prefetch operations
- Checking the number of cached events
- Tracking event views
- Tracking user interactions

## Best Practices

### Efficient Caching

1. **Use appropriate priority levels**:
   - `PRIORITY_HIGH`: Critical data (user profiles, current event)
   - `PRIORITY_MEDIUM`: Important but replaceable data (event lists)
   - `PRIORITY_LOW`: Nice-to-have data (historical events)

2. **Cache invalidation strategies**:
   - Time-based expiration for most data
   - Explicit invalidation when data changes
   - Version-based invalidation for schema changes

3. **Optimize cache size**:
   - Store only necessary fields
   - Use appropriate data structures
   - Implement size limits and eviction policies

### Offline Support

1. **Prioritize critical data**:
   - Ensure user profile and current events are always cached
   - Implement fallbacks for unavailable data

2. **Sync strategy**:
   - Queue changes made offline
   - Sync when connection is restored
   - Handle conflict resolution

3. **User experience**:
   - Indicate offline status to users
   - Show cached data with timestamp
   - Provide retry options for failed operations

## Conclusion

The Yetu'ga caching system provides a robust foundation for efficient data access, offline support, and performance optimization. By combining Hive for persistent storage with in-memory caching and specialized services, the application delivers a responsive user experience even in challenging network conditions.
