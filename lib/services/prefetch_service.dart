import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';
import 'cache_manager.dart';
import 'event_cache_service.dart';
import 'firestore_config_service.dart';

// Provider for the PrefetchService
final prefetchServiceProvider = Provider<PrefetchService>((ref) {
  final cacheManager = ref.read(cacheManagerProvider);
  final eventCacheService = ref.read(eventCacheServiceProvider);
  final firestoreConfigService = ref.read(firestoreConfigServiceProvider);
  return PrefetchService(cacheManager, eventCacheService, firestoreConfigService);
});

class PrefetchService {
  final CacheManager _cacheManager;
  final EventCacheService _eventCacheService;
  final FirestoreConfigService _firestoreConfigService;

  // Prefetch status
  bool _isPrefetching = false;
  DateTime? _lastPrefetchTime;

  // User interaction tracking
  final Map<String, int> _eventViewCounts = {};
  final Map<String, int> _userInteractionCounts = {};

  // Prefetch configuration
  int _maxPrefetchEvents = 20;
  int _maxPrefetchUsers = 10;
  Duration _prefetchInterval = const Duration(hours: 3);

  // Background prefetch timer
  Timer? _prefetchTimer;

  PrefetchService(this._cacheManager, this._eventCacheService, this._firestoreConfigService);

  // Initialize the prefetch service
  Future<void> initialize() async {
    try {
      Logger.d('PrefetchService', 'Initializing prefetch service');

      // Load interaction data from persistent storage
      await _loadInteractionData();

      // Start periodic prefetch
      _startPeriodicPrefetch();

      Logger.d('PrefetchService', 'Prefetch service initialized');
    } catch (e) {
      Logger.e('PrefetchService', 'Error initializing prefetch service', e);
    }
  }

  // Start periodic prefetch
  void _startPeriodicPrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer.periodic(_prefetchInterval, (timer) async {
      await prefetchFrequentlyAccessedContent();
    });
    Logger.d('PrefetchService', 'Periodic prefetch started with interval: $_prefetchInterval');
  }

  // Set prefetch configuration
  void setPrefetchConfig({int? maxEvents, int? maxUsers, Duration? interval}) {
    if (maxEvents != null) _maxPrefetchEvents = maxEvents;
    if (maxUsers != null) _maxPrefetchUsers = maxUsers;
    if (interval != null) {
      _prefetchInterval = interval;
      _startPeriodicPrefetch();
    }
  }

  // Track event view
  Future<void> trackEventView(String eventId) async {
    _eventViewCounts[eventId] = (_eventViewCounts[eventId] ?? 0) + 1;
    await _saveInteractionData();
  }

  // Track user interaction
  Future<void> trackUserInteraction(String userId) async {
    _userInteractionCounts[userId] = (_userInteractionCounts[userId] ?? 0) + 1;
    await _saveInteractionData();
  }

  // Load interaction data from persistent storage
  Future<void> _loadInteractionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load event view counts
      final eventViewsJson = prefs.getString('prefetch_event_views');
      if (eventViewsJson != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          Map<String, dynamic>.from(jsonDecode(eventViewsJson))
        );

        data.forEach((key, value) {
          _eventViewCounts[key] = value as int;
        });
      }

      // Load user interaction counts
      final userInteractionsJson = prefs.getString('prefetch_user_interactions');
      if (userInteractionsJson != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          Map<String, dynamic>.from(jsonDecode(userInteractionsJson))
        );

        data.forEach((key, value) {
          _userInteractionCounts[key] = value as int;
        });
      }

      Logger.d('PrefetchService', 'Loaded interaction data: ${_eventViewCounts.length} events, ${_userInteractionCounts.length} users');
    } catch (e) {
      Logger.e('PrefetchService', 'Error loading interaction data', e);
    }
  }

  // Save interaction data to persistent storage
  Future<void> _saveInteractionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save event view counts
      await prefs.setString('prefetch_event_views', jsonEncode(_eventViewCounts));

      // Save user interaction counts
      await prefs.setString('prefetch_user_interactions', jsonEncode(_userInteractionCounts));
    } catch (e) {
      Logger.e('PrefetchService', 'Error saving interaction data', e);
    }
  }

  // Prefetch frequently accessed content
  Future<void> prefetchFrequentlyAccessedContent() async {
    if (_isPrefetching) {
      Logger.d('PrefetchService', 'Prefetch already in progress, skipping');
      return;
    }

    _isPrefetching = true;

    try {
      Logger.d('PrefetchService', 'Starting content prefetch');

      // Check if we're online
      final isOnline = await _firestoreConfigService.isOnline();
      if (!isOnline) {
        Logger.d('PrefetchService', 'Device is offline, skipping prefetch');
        _isPrefetching = false;
        return;
      }

      // Prefetch popular events
      await _prefetchPopularEvents();

      // Prefetch frequently interacted users
      await _prefetchFrequentUsers();

      // Prefetch current user's joined events
      await _prefetchUserJoinedEvents();

      _lastPrefetchTime = DateTime.now();
      Logger.d('PrefetchService', 'Content prefetch completed');
    } catch (e) {
      Logger.e('PrefetchService', 'Error prefetching content', e);
    } finally {
      _isPrefetching = false;
    }
  }

  // Prefetch popular events
  Future<void> _prefetchPopularEvents() async {
    try {
      // Sort events by view count
      final sortedEvents = _eventViewCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Take top events
      final topEventIds = sortedEvents
          .take(_maxPrefetchEvents)
          .map((e) => e.key)
          .toList();

      Logger.d('PrefetchService', 'Prefetching ${topEventIds.length} popular events');

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
    } catch (e) {
      Logger.e('PrefetchService', 'Error prefetching popular events', e);
    }
  }

  // Prefetch frequently interacted users
  Future<void> _prefetchFrequentUsers() async {
    try {
      // Sort users by interaction count
      final sortedUsers = _userInteractionCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Take top users
      final topUserIds = sortedUsers
          .take(_maxPrefetchUsers)
          .map((e) => e.key)
          .toList();

      Logger.d('PrefetchService', 'Prefetching ${topUserIds.length} frequent users');

      // Prefetch each user
      for (final userId in topUserIds) {
        try {
          // Check if already in cache and not expired
          final cachedUser = await _cacheManager.get<Map<String, dynamic>>('user_$userId');
          if (cachedUser != null) {
            continue; // Skip if already cached
          }

          // Fetch from Firestore
          final docSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (docSnapshot.exists) {
            final userData = docSnapshot.data();

            if (userData != null) {
              // Cache with medium priority
              await _cacheManager.put(
                'user_$userId',
                userData,
                priority: CacheManager.PRIORITY_MEDIUM,
              );
            }
          }
        } catch (e) {
          Logger.e('PrefetchService', 'Error prefetching user: $userId', e);
          // Continue with next user
        }
      }
    } catch (e) {
      Logger.e('PrefetchService', 'Error prefetching frequent users', e);
    }
  }

  // Prefetch current user's joined events
  Future<void> _prefetchUserJoinedEvents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      Logger.d('PrefetchService', 'Prefetching joined events for user: ${user.uid}');

      // Fetch events joined by the user
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('joinedBy', arrayContains: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      for (final doc in querySnapshot.docs) {
        try {
          final event = EventModel.fromFirestore(doc);

          // Cache with high priority
          await _cacheManager.put(
            'event_${event.id}',
            event,
            priority: CacheManager.PRIORITY_HIGH,
          );

          // Also update the event cache service
          _eventCacheService.updateEvent(event);
        } catch (e) {
          Logger.e('PrefetchService', 'Error processing joined event', e);
          // Continue with next event
        }
      }

      Logger.d('PrefetchService', 'Prefetched ${querySnapshot.docs.length} joined events');
    } catch (e) {
      Logger.e('PrefetchService', 'Error prefetching joined events', e);
    }
  }

  // Get prefetch status
  Map<String, dynamic> getPrefetchStatus() {
    return {
      'isPrefetching': _isPrefetching,
      'lastPrefetchTime': _lastPrefetchTime?.toIso8601String(),
      'trackedEvents': _eventViewCounts.length,
      'trackedUsers': _userInteractionCounts.length,
      'prefetchInterval': _prefetchInterval.inMinutes,
    };
  }

  // Force prefetch
  Future<void> forcePrefetch() async {
    await prefetchFrequentlyAccessedContent();
  }

  // Dispose
  void dispose() {
    _prefetchTimer?.cancel();
    Logger.d('PrefetchService', 'Prefetch service disposed');
  }
}
