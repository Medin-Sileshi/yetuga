import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:async/async.dart';
import '../models/event_model.dart';
import '../services/batch_service.dart';
import '../services/event_cache_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/retry_service.dart';
import '../services/rsvp_service.dart';
import '../utils/logger.dart';

// Provider for the EventService
final eventServiceProvider = Provider<EventService>((ref) {
  final eventCacheService = ref.read(eventCacheServiceProvider);
  final batchService = ref.read(batchServiceProvider);
  final retryService = ref.read(retryServiceProvider);
  final pushNotificationService = ref.read(pushNotificationServiceProvider);
  final notificationService = ref.read(notificationServiceProvider);
  return EventService(eventCacheService, batchService, retryService, pushNotificationService, notificationService);
});

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EventCacheService _eventCacheService;
  final BatchService _batchService;
  final RetryService _retryService;
  // No longer using _notificationService as a field

  // Cache for followed accounts and interests
  List<String>? cachedFollowedAccounts;
  List<String>? cachedUserInterests;
  DateTime? lastCacheTime;
  static const cacheDuration = Duration(minutes: 5);

  // Clear all cached data
  Future<void> clearCache() async {
    try {
      Logger.d('EventService', 'Clearing event cache');
      cachedFollowedAccounts = null;
      cachedUserInterests = null;
      lastCacheTime = null;

      // Clear the event cache service
      _eventCacheService.clearCache();

      Logger.d('EventService', 'Event cache cleared successfully');
    } catch (e) {
      Logger.e('EventService', 'Error clearing event cache', e);
      rethrow;
    }
  }

  EventService(
    this._eventCacheService,
    this._batchService,
    this._retryService,
    PushNotificationService pushNotificationService,
    NotificationService notificationService,
  ) {
    // No longer initializing _notificationService
  }

  // Collection reference
  CollectionReference get _eventsCollection => _firestore.collection('events');

  // Get current user ID (private)
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Get current user ID (public)
  String getCurrentUserId() {
    return _currentUserId;
  }

  // Add a new event
  Future<String> addEvent(EventModel event) async {
    try {
      Logger.d('EventService', 'Adding new event...');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('EventService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      Logger.d('EventService', 'Current user ID: $_currentUserId');

      // Add the event with the current user's ID
      final eventWithUserId = event.copyWith(userId: _currentUserId);

      // Log the event data
      Logger.d('EventService', 'Event data: ${eventWithUserId.toMap()}');

      // Add to Firestore and get the document reference
      final docRef = await _eventsCollection.add(eventWithUserId.toMap());

      Logger.d('EventService', 'Event added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Logger.e('EventService', 'Error adding event', e);
      rethrow;
    }
  }

  // Get all events with pagination
  // SHOW ALL filter: Shows every public post, all events the user posted, all events the user joined, and all events the user was invited to
  // sorted by time posted (new to old) with events happening in 24hrs given priority
  Stream<List<EventModel>> getEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    Logger.d('EventService', 'Getting all events, user ID: $_currentUserId');

    // Require authentication for all event access
    if (_currentUserId.isEmpty) {
      Logger.d('EventService', 'User not authenticated, returning empty list for SHOW ALL filter');
      return Stream.value([]);
    }

    // For authenticated users, show public events, their own events, events they've joined, and events they're invited to
    Query query;

    // Show public events for authenticated users
    query = _eventsCollection
        .where('isPrivate', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    // Log the query for debugging
    Logger.d('EventService', 'SHOW ALL filter query: ${query.toString()}');

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Apply limit
    query = query.limit(limit);

    // For authenticated users, we need to also get events they've joined but didn't create
    // Create a query for events joined by the user but not created by them
    Query joinedQuery = _eventsCollection
        .where('joinedBy', arrayContains: _currentUserId)
        .where('userId', isNotEqualTo: _currentUserId) // Exclude events created by the user
        .where('isPrivate', isEqualTo: true) // Only include private events (public ones are already in the main query)
        .orderBy('userId') // Required when using isNotEqualTo
        .orderBy('createdAt', descending: true);

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      joinedQuery = joinedQuery.startAfterDocument(startAfter);
    }

    // Apply limit
    joinedQuery = joinedQuery.limit(limit);

    // Get the public events stream
    final publicEventsStream = query.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} public events for SHOW ALL filter');
      return events;
    });

    // Get events created by the user
    Query userEventsQuery = _eventsCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true);

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      userEventsQuery = userEventsQuery.startAfterDocument(startAfter);
    }

    // Apply limit
    userEventsQuery = userEventsQuery.limit(limit);

    // Get the user events stream
    final userEventsStream = userEventsQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} user events for SHOW ALL filter');
      return events;
    });

    // Get joined private events stream
    final joinedEventsStream = joinedQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} joined private events for SHOW ALL filter');
      return events;
    });

    // Get events the user was invited to (using a workaround for security rules)
    Stream<List<EventModel>> invitedEventsStream = Stream.value([]);

    if (_currentUserId.isNotEmpty) {
      // Use a more efficient approach with the RSVPService
      invitedEventsStream = Stream.periodic(const Duration(seconds: 1), (_) => null).take(1).asyncMap((_) async {
        try {
          // Create a new PushNotificationService and RSVPService
          final pushNotificationService = PushNotificationService();
          final rsvpService = RSVPService(pushNotificationService);

          // Get all RSVPs for the current user
          Logger.d('EventService', 'Getting RSVPs for user: $_currentUserId');

          // Use getPendingRSVPs instead of filtering after the fact
          final pendingRSVPs = await rsvpService.getPendingRSVPs().first;

          // Log all pending RSVPs for debugging
          Logger.d('EventService', 'SHOW ALL filter - All pending RSVPs: ${pendingRSVPs.length}');
          for (final rsvp in pendingRSVPs) {
            Logger.d('EventService', 'SHOW ALL filter - Pending RSVP: id=${rsvp.id}, eventId=${rsvp.eventId}, status=${rsvp.status}, inviterId=${rsvp.inviterId}, inviteeId=${rsvp.inviteeId}');
          }

          Logger.d('EventService', 'Found ${pendingRSVPs.length} pending RSVPs for SHOW ALL filter');

          // Create a new NotificationService instead of using the class field
          try {
            final pushNotificationService = PushNotificationService();
            final notificationService = NotificationService(pushNotificationService);
            await notificationService.checkAndSendUnreadNotifications();
            Logger.d('EventService', 'Notifications refreshed successfully');
          } catch (e) {
            Logger.e('EventService', 'Error refreshing notifications, continuing anyway', e);
          }

          final invitedEvents = <EventModel>[];

          // Get the event details for each RSVP
          for (final rsvp in pendingRSVPs) {
            try {
              final eventDoc = await _eventsCollection.doc(rsvp.eventId).get();
              if (eventDoc.exists) {
                // Create the event model and mark it as invited
                final event = EventModel.fromFirestore(eventDoc).copyWith(isInvited: true);
                invitedEvents.add(event);

                // Update the cache for each event
                _eventCacheService.updateEvent(event);

                Logger.d('EventService', 'Marked event ${event.id} as invited');
              }
            } catch (e) {
              Logger.e('EventService', 'Error getting invited event: ${rsvp.eventId}', e);
            }
          }

          Logger.d('EventService', 'Found ${invitedEvents.length} invited events for SHOW ALL filter');
          return invitedEvents;
        } catch (e) {
          Logger.e('EventService', 'Error getting invited events', e);
          return <EventModel>[];
        }
      });
    }

    // Create a stream that combines all the individual streams
    // We'll use a different approach to ensure we get all events
    return Stream.fromFuture(Future(() async {
      // Get all events from each stream
      final publicEvents = await publicEventsStream.first;
      final userEvents = await userEventsStream.first;
      final joinedEvents = await joinedEventsStream.first;
      final invitedEvents = _currentUserId.isNotEmpty ? await invitedEventsStream.first : [];

      // Log the number of events from each source
      Logger.d('EventService', 'SHOW ALL filter - Found ${publicEvents.length} public events');
      Logger.d('EventService', 'SHOW ALL filter - Found ${userEvents.length} user events');
      Logger.d('EventService', 'SHOW ALL filter - Found ${joinedEvents.length} joined events');
      Logger.d('EventService', 'SHOW ALL filter - Found ${invitedEvents.length} invited events');

      // Combine all events
      final allEvents = [...publicEvents, ...userEvents, ...joinedEvents, ...invitedEvents];

      // Remove duplicates using content-based deduplication
      Logger.d('EventService', '🔍 STARTING CONTENT-BASED DEDUPLICATION - Found ${allEvents.length} events to process');
      final uniqueEvents = <EventModel>[];
      final seenIds = <String>{};
      final seenContentKeys = <String>{};

      for (final event in allEvents) {
        // Generate a content key for this event
        final contentKey = '${event.userId}-${event.inquiry}-${event.date.year}-${event.date.month}-${event.date.day}-${event.time.hour}-${event.time.minute}';

        // Check if we've already seen this event (by ID or content)
        if (!seenIds.contains(event.id) && !seenContentKeys.contains(contentKey)) {
          uniqueEvents.add(event);
          seenIds.add(event.id);
          seenContentKeys.add(contentKey);
          Logger.d('EventService', 'SHOW ALL filter - Added unique event: ${event.id}, content key: $contentKey');
        } else {
          Logger.d('EventService', 'SHOW ALL filter - Skipped duplicate event: ${event.id}, content key: $contentKey');
        }
      }

      Logger.d('EventService', 'SHOW ALL filter - Combined ${allEvents.length} events, ${uniqueEvents.length} unique');

      final now = DateTime.now();

      // Separate events into future events and past events
      final futureEvents = <EventModel>[];
      final pastEvents = <EventModel>[];

      for (final event in uniqueEvents) {
        // Convert event date and time to a single DateTime for accurate comparison
        final eventDateTime = _combineDateAndTime(event.date, event.time);

        if (eventDateTime.isAfter(now)) {
          futureEvents.add(event);
        } else {
          pastEvents.add(event);
        }
      }

      Logger.d('EventService', 'SHOW ALL filter - Separated into ${futureEvents.length} future events and ${pastEvents.length} past events');

      // Sort future events by date and time (soonest first)
      futureEvents.sort((a, b) {
        final aDateTime = _combineDateAndTime(a.date, a.time);
        final bDateTime = _combineDateAndTime(b.date, b.time);
        return aDateTime.compareTo(bDateTime);
      });

      // Sort past events by date and time (most recent first)
      pastEvents.sort((a, b) {
        final aDateTime = _combineDateAndTime(a.date, a.time);
        final bDateTime = _combineDateAndTime(b.date, b.time);
        return bDateTime.compareTo(aDateTime); // Reverse order for past events
      });

      // Combine the lists, with future events first (happening soon), then past events
      final sortedEvents = [...futureEvents, ...pastEvents];

      // Limit to requested number
      final limitedEvents = sortedEvents.take(limit).toList();
      Logger.d('EventService', 'Returning ${limitedEvents.length} events for SHOW ALL filter');
      return limitedEvents;
    }));
  }

  // Get events for the current user with pagination
  Stream<List<EventModel>> getUserEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    Query query = _eventsCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true);

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Apply limit
    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get public events (not private) with pagination
  // NEW filter: Shows all new public posts and all events the user posted (given priority based on interest)
  Stream<List<EventModel>> getPublicEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    Logger.d('EventService', 'Getting public events, user ID: $_currentUserId');

    // Require authentication for all event access
    if (_currentUserId.isEmpty) {
      Logger.d('EventService', 'User not authenticated, returning empty list for NEW filter');
      return Stream.value([]);
    }

    // Use separate queries instead of Filter.or to avoid index issues
    // First query: Get public events
    final publicEventsQuery = _eventsCollection
        .where('isPrivate', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // Log the query for debugging
    Logger.d('EventService', 'NEW filter public query (authenticated): ${publicEventsQuery.toString()}');

    // Second query: Get events created by the current user
    final userEventsQuery = _eventsCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // Log the query for debugging
    Logger.d('EventService', 'NEW filter user query (authenticated): ${userEventsQuery.toString()}');

    // Apply pagination if startAfter is provided
    Query paginatedPublicQuery = publicEventsQuery;
    Query paginatedUserQuery = userEventsQuery;
    if (startAfter != null) {
      paginatedPublicQuery = publicEventsQuery.startAfterDocument(startAfter);
      paginatedUserQuery = userEventsQuery.startAfterDocument(startAfter);
    }

    // Get the public events stream
    final publicEventsStream = paginatedPublicQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} public events for NEW filter');
      return events;
    });

    // Get the user events stream
    final userEventsStream = paginatedUserQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} user events for NEW filter');
      return events;
    });

    // Get private events that the user has joined but didn't create
    // We need a separate query for this because Firestore doesn't support
    // OR conditions with array-contains in the same query
    Query joinedPrivateQuery = _eventsCollection
        .where('isPrivate', isEqualTo: true)
        .where('joinedBy', arrayContains: _currentUserId)
        .where('userId', isNotEqualTo: _currentUserId) // Exclude events the user created (already in main query)
        .orderBy('userId') // Required when using isNotEqualTo
        .orderBy('createdAt', descending: true);

    // Apply limit
    joinedPrivateQuery = joinedPrivateQuery.limit(limit);

    // Get joined private events stream
    final joinedPrivateEventsStream = joinedPrivateQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      return events;
    });

    // Get private events that the user is invited to but hasn't joined
    // Using a workaround for security rules
    // Get invited events directly using the RSVPService
    final invitedEventsStream = Stream.fromFuture(Future(() async {
      try {
        // Create a new PushNotificationService and RSVPService
        final pushNotificationService = PushNotificationService();
        final rsvpService = RSVPService(pushNotificationService);

        // Get all RSVPs for the current user
        Logger.d('EventService', 'Getting RSVPs for user: $_currentUserId for NEW filter');

        // Use getPendingRSVPs instead of filtering after the fact
        final pendingRSVPs = await rsvpService.getPendingRSVPs().first;

        // Log all pending RSVPs for debugging
        Logger.d('EventService', 'All pending RSVPs: ${pendingRSVPs.length}');
        for (final rsvp in pendingRSVPs) {
          Logger.d('EventService', 'Pending RSVP: id=${rsvp.id}, eventId=${rsvp.eventId}, status=${rsvp.status}, inviterId=${rsvp.inviterId}, inviteeId=${rsvp.inviteeId}');
        }

        // Create a new NotificationService instead of using the class field
        try {
          final pushNotificationService = PushNotificationService();
          final notificationService = NotificationService(pushNotificationService);
          await notificationService.checkAndSendUnreadNotifications();
          Logger.d('EventService', 'Notifications refreshed successfully for NEW filter');
        } catch (e) {
          Logger.e('EventService', 'Error refreshing notifications for NEW filter, continuing anyway', e);
        }

        final invitedEvents = <EventModel>[];

        // Get the event details for each RSVP
        for (final rsvp in pendingRSVPs) {
          try {
            final eventDoc = await _eventsCollection.doc(rsvp.eventId).get();
            if (eventDoc.exists) {
              // Create the event model and mark it as invited
              final event = EventModel.fromFirestore(eventDoc).copyWith(isInvited: true);
              // Only include events the user hasn't joined yet
              if (!event.joinedBy.contains(_currentUserId)) {
                invitedEvents.add(event);
                // Update the cache
                _eventCacheService.updateEvent(event);
                Logger.d('EventService', 'Marked event ${event.id} as invited for NEW filter');
              }
            }
          } catch (e) {
            Logger.e('EventService', 'Error getting invited event: ${rsvp.eventId}', e);
          }
        }

        Logger.d('EventService', 'Found ${invitedEvents.length} invited events for NEW filter');
        return invitedEvents;
      } catch (e) {
        Logger.e('EventService', 'Error fetching invited events for NEW filter', e);
        return <EventModel>[];
      }
    }));

    // We don't need to merge streams anymore since we're using Stream.fromFuture
    // Just use the invitedEventsStream directly
    final combinedInvitedEventsStream = invitedEventsStream;

    // Use the class-level cache for followed accounts and interests

    // Function to get and cache user data
    Future<void> updateUserDataCache() async {
      final now = DateTime.now();
      // Only update cache if it's expired or doesn't exist
      if (lastCacheTime == null ||
          now.difference(lastCacheTime!) > cacheDuration ||
          cachedFollowedAccounts == null ||
          cachedUserInterests == null) {
        cachedFollowedAccounts = await _getUserFollowedAccounts();
        cachedUserInterests = await _getUserInterests();
        lastCacheTime = now;
        Logger.d('EventService', 'Updated cache for NEW filter - followed accounts: ${cachedFollowedAccounts!.length}, interests: ${cachedUserInterests!.length}');
      }
    }

    // Create a stream that combines all the individual streams
    // We'll use a different approach to ensure we get all events
    return Stream.fromFuture(Future(() async {
      // Update the cache first
      await updateUserDataCache();

      // Get all events from each stream
      final publicEvents = await publicEventsStream.first;
      final userEvents = await userEventsStream.first;
      final joinedPrivateEvents = await joinedPrivateEventsStream.first;
      final invitedEvents = await combinedInvitedEventsStream.first;

      // Log the number of events from each source
      Logger.d('EventService', 'NEW filter - Found ${publicEvents.length} public events');
      Logger.d('EventService', 'NEW filter - Found ${userEvents.length} user events');
      Logger.d('EventService', 'NEW filter - Found ${joinedPrivateEvents.length} joined private events');
      Logger.d('EventService', 'NEW filter - Found ${invitedEvents.length} invited events');

      // Combine all events
      final allEvents = [...publicEvents, ...userEvents, ...joinedPrivateEvents, ...invitedEvents];

      // Sort by createdAt (newest to oldest)
      allEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Remove duplicates using content-based deduplication
      Logger.d('EventService', '🔍 STARTING CONTENT-BASED DEDUPLICATION (NEW FILTER) - Found ${allEvents.length} events to process');
      final uniqueEvents = <EventModel>[];
      final seenIds = <String>{};
      final seenContentKeys = <String>{};

      for (final event in allEvents) {
        // Generate a content key for this event
        final contentKey = '${event.userId}-${event.inquiry}-${event.date.year}-${event.date.month}-${event.date.day}-${event.time.hour}-${event.time.minute}';

        // Check if we've already seen this event (by ID or content)
        if (!seenIds.contains(event.id) && !seenContentKeys.contains(contentKey)) {
          uniqueEvents.add(event);
          seenIds.add(event.id);
          seenContentKeys.add(contentKey);
          Logger.d('EventService', 'NEW filter - Added unique event: ${event.id}, content key: $contentKey');
        } else {
          Logger.d('EventService', 'NEW filter - Skipped duplicate event: ${event.id}, content key: $contentKey');
        }
      }

      Logger.d('EventService', 'NEW filter - Combined ${allEvents.length} events, ${uniqueEvents.length} unique');

      // Use the cached data for prioritization
      final followedAccounts = cachedFollowedAccounts ?? [];
      final userInterests = cachedUserInterests ?? [];

      // Separate events into three categories:
      // 1. Events from followed accounts
      // 2. Events matching user interests (but not from followed accounts)
      // 3. Other events
      final followedAccountEvents = <EventModel>[];
      final interestEvents = <EventModel>[];
      final otherEvents = <EventModel>[];

      for (final event in uniqueEvents) {
        if (followedAccounts.contains(event.userId)) {
          // Events from followed accounts get top priority
          followedAccountEvents.add(event);
        } else if (userInterests.contains(event.activityType)) {
          // Events matching interests get second priority
          interestEvents.add(event);
        } else {
          // All other events
          otherEvents.add(event);
        }
      }

      Logger.d('EventService', 'NEW filter - Prioritized: ${followedAccountEvents.length} followed, ${interestEvents.length} interests, ${otherEvents.length} other');

      // Combine the lists in priority order
      final sortedEvents = [...followedAccountEvents, ...interestEvents, ...otherEvents];

      // Limit to requested number
      final limitedEvents = sortedEvents.take(limit).toList();
      Logger.d('EventService', 'Returning ${limitedEvents.length} events for NEW filter');
      return limitedEvents;
    }));
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      Logger.d('EventService', 'Deleting event: $eventId');

      // Check if the current user is the event creator
      final event = await getEventWithRetry(eventId);
      if (event == null) {
        Logger.e('EventService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      if (event.userId != _currentUserId) {
        Logger.e('EventService', 'User is not the event creator');
        throw Exception('Only the event creator can delete this event');
      }

      // Delete the event from Firestore
      await _eventsCollection.doc(eventId).delete();

      // Remove from cache
      _eventCacheService.removeEvent(eventId);

      Logger.d('EventService', 'Event deleted successfully: $eventId');
    } catch (e) {
      Logger.e('EventService', 'Error deleting event', e);
      rethrow;
    }
  }

  // Update an event
  Future<void> updateEvent(EventModel event) async {
    try {
      Logger.d('EventService', 'Updating event with ID: ${event.id}');
      Logger.d('EventService', 'Updated data: ${event.toMap()}');

      // Use retry logic for the Firestore update
      final success = await _retryService.executeWithRetry<bool>(
        operation: () async {
          await _eventsCollection.doc(event.id).update(event.toMap());
          return true;
        },
        maxRetries: 3,
        shouldRetry: _retryService.isFirestoreRetryableError,
        operationName: 'updateEvent(${event.id})',
      );

      if (success) {
        // Update the cache with the new event data
        _eventCacheService.updateEvent(event);
        Logger.d('EventService', 'Event updated successfully and cache updated');
      } else {
        Logger.e('EventService', 'Failed to update event after retries');
        throw Exception('Failed to update event after retries');
      }
    } catch (e) {
      Logger.e('EventService', 'Error updating event', e);
      rethrow;
    }
  }

  // Toggle like for an event
  Future<bool> toggleLike(String eventId) async {
    try {
      Logger.d('EventService', 'Toggling like for event: $eventId');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('EventService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Get the current event data with retry logic
      final event = await getEventWithRetry(eventId);
      if (event == null) {
        Logger.e('EventService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      // Check if user already liked this event
      final isLiked = event.likedBy.contains(_currentUserId);

      // Update the event in Firestore using array operations with retry logic
      final success = await _retryService.executeWithRetry<bool>(
        operation: () async {
          final docRef = _eventsCollection.doc(eventId);
          if (isLiked) {
            // Remove like using arrayRemove
            await docRef.update({
              'likedBy': FieldValue.arrayRemove([_currentUserId])
            });
            Logger.d('EventService', 'Removing like from event: $eventId');

            // Update the cached event
            event.likedBy.remove(_currentUserId);
          } else {
            // Add like using arrayUnion
            await docRef.update({
              'likedBy': FieldValue.arrayUnion([_currentUserId])
            });
            Logger.d('EventService', 'Adding like to event: $eventId');

            // Update the cached event
            event.likedBy.add(_currentUserId);
          }
          return true;
        },
        maxRetries: 3,
        shouldRetry: _retryService.isFirestoreRetryableError,
        operationName: 'toggleLike($eventId)',
      );

      if (success) {
        // Update the cache
        _eventCacheService.updateEvent(event);
      }

      // Return the new like state
      return !isLiked;
    } catch (e) {
      Logger.e('EventService', 'Error toggling like', e);
      rethrow;
    }
  }

  // Add an attendee to an event (for accepting join requests)
  Future<void> addAttendee(String eventId, String userId) async {
    try {
      Logger.d('EventService', 'Adding attendee $userId to event: $eventId');

      // Get the current event data
      final event = await getEventWithRetry(eventId);
      if (event == null) {
        Logger.e('EventService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      // Check if the event has reached its attendee limit
      if (event.attendeeLimit != null && event.joinedBy.length >= event.attendeeLimit!) {
        Logger.e('EventService', 'Event has reached its attendee limit: $eventId');
        throw Exception('This event has reached its attendee limit');
      }

      // Check if the user is already in the event
      if (event.joinedBy.contains(userId)) {
        Logger.d('EventService', 'User $userId is already in event: $eventId');
        return; // User is already in the event, nothing to do
      }

      // Add the user to the event
      await _eventsCollection.doc(eventId).update({
        'joinedBy': FieldValue.arrayUnion([userId])
      });

      // Update the cached event
      event.joinedBy.add(userId);
      _eventCacheService.updateEvent(event);

      Logger.d('EventService', 'Successfully added attendee $userId to event: $eventId');
    } catch (e) {
      Logger.e('EventService', 'Error adding attendee to event', e);
      rethrow;
    }
  }

  // Toggle join for an event
  Future<bool> toggleJoin(String eventId) async {
    try {
      Logger.d('EventService', 'Toggling join for event: $eventId');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('EventService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Get the current event data from cache if available
      EventModel? event = await _eventCacheService.getEvent(eventId);

      // If not in cache, get from Firestore
      if (event == null) {
        final docRef = _eventsCollection.doc(eventId);
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          Logger.e('EventService', 'Event not found: $eventId');
          throw Exception('Event not found');
        }

        event = EventModel.fromFirestore(docSnapshot);
      }

      // Check if user already joined this event
      final hasJoined = event.joinedBy.contains(_currentUserId);

      // Update the event in Firestore using array operations
      final docRef = _eventsCollection.doc(eventId);
      if (hasJoined) {
        // Remove join using arrayRemove
        await docRef.update({
          'joinedBy': FieldValue.arrayRemove([_currentUserId])
        });
        Logger.d('EventService', 'Removing join from event: $eventId');

        // Update the cached event
        event.joinedBy.remove(_currentUserId);
      } else {
        // Check if the event has reached its attendee limit
        if (event.attendeeLimit != null && event.joinedBy.length >= event.attendeeLimit!) {
          Logger.e('EventService', 'Event has reached its attendee limit: $eventId');
          throw Exception('This event has reached its attendee limit');
        }

        // Add join using arrayUnion
        await docRef.update({
          'joinedBy': FieldValue.arrayUnion([_currentUserId])
        });
        Logger.d('EventService', 'Adding join to event: $eventId');

        // Update the cached event
        event.joinedBy.add(_currentUserId);
      }

      // Update the cache
      _eventCacheService.updateEvent(event);

      // Return the new join state
      return !hasJoined;
    } catch (e) {
      Logger.e('EventService', 'Error toggling join', e);
      rethrow;
    }
  }

  // Check if current user has liked an event
  bool hasLiked(EventModel event) {
    if (_currentUserId.isEmpty) return false;
    return event.likedBy.contains(_currentUserId);
  }

  // Check if current user has joined an event
  bool hasJoined(EventModel event) {
    if (_currentUserId.isEmpty) return false;
    return event.joinedBy.contains(_currentUserId);
  }

  // Toggle likes for multiple events in a batch
  Future<void> toggleLikesInBatch(Map<String, bool> eventLikes) async {
    try {
      Logger.d('EventService', 'Toggling likes for ${eventLikes.length} events in batch');

      if (_currentUserId.isEmpty) {
        Logger.e('EventService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Use the batch service to perform the operation
      await _batchService.toggleLikesInBatch(eventLikes, _currentUserId);

      // Update the cache for each event
      for (final eventId in eventLikes.keys) {
        // Get the current event from cache
        final event = await _eventCacheService.getEvent(eventId);
        if (event != null) {
          // Update the cached event
          final shouldLike = eventLikes[eventId]!;
          if (shouldLike) {
            if (!event.likedBy.contains(_currentUserId)) {
              event.likedBy.add(_currentUserId);
            }
          } else {
            event.likedBy.remove(_currentUserId);
          }

          // Update the cache
          _eventCacheService.updateEvent(event);
        }
      }

      Logger.d('EventService', 'Successfully toggled likes in batch');
    } catch (e) {
      Logger.e('EventService', 'Error toggling likes in batch', e);
      rethrow;
    }
  }

  // Create invitations for multiple users in a batch
  Future<void> createInvitationsInBatch(String eventId, List<String> inviteeIds) async {
    try {
      Logger.d('EventService', 'Creating invitations for ${inviteeIds.length} users in batch');

      if (_currentUserId.isEmpty) {
        Logger.e('EventService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Use the batch service to perform the operation
      await _batchService.createInvitationsInBatch(eventId, inviteeIds, _currentUserId);

      // Check if the event is private
      final eventDoc = await _eventsCollection.doc(eventId).get();
      if (eventDoc.exists) {
        final eventData = eventDoc.data() as Map<String, dynamic>;
        final isPrivate = eventData['isPrivate'] as bool? ?? false;

        if (isPrivate) {
          Logger.d('EventService', 'Event is private, verifying invitees are in joinedBy array');

          // Verify that all invitees are in the joinedBy array
          final joinedBy = List<String>.from(eventData['joinedBy'] ?? []);
          final missingInvitees = inviteeIds.where((id) => !joinedBy.contains(id)).toList();

          if (missingInvitees.isNotEmpty) {
            Logger.d('EventService', 'Adding ${missingInvitees.length} missing invitees to joinedBy array');

            // Add any missing invitees to the joinedBy array
            await _eventsCollection.doc(eventId).update({
              'joinedBy': FieldValue.arrayUnion(missingInvitees)
            });
          }
        }
      }

      Logger.d('EventService', 'Successfully created invitations in batch');
    } catch (e) {
      Logger.e('EventService', 'Error creating invitations in batch', e);
      rethrow;
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

  // Get an event with retry logic
  Future<EventModel?> getEventWithRetry(String eventId) async {
    try {
      Logger.d('EventService', 'Getting event with retry: $eventId');

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

  // Get an event by ID
  Future<EventModel> getEvent(String eventId) async {
    Logger.d('EventService', 'Getting event: $eventId');

    // Try to get the event with retry logic
    final event = await getEventWithRetry(eventId);

    // If the event is not found, throw an exception
    if (event == null) {
      Logger.e('EventService', 'Event not found: $eventId');
      throw Exception('Event not found');
    }

    return event;
  }

  // Get user interests from Firestore
  Future<List<String>> _getUserInterests() async {
    try {
      Logger.d('EventService', 'Getting user interests');

      // If not authenticated, return empty list
      if (_currentUserId.isEmpty) {
        Logger.d('EventService', 'User not authenticated, returning empty interests list');
        return [];
      }

      // Get the user's onboarding data from Firestore
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();

      if (!userDoc.exists) {
        Logger.d('EventService', 'User document not found, returning empty interests list');
        return [];
      }

      // Convert to OnboardingData
      final userData = userDoc.data() as Map<String, dynamic>;

      // Check if the user has interests
      if (!userData.containsKey('interests')) {
        Logger.d('EventService', 'User has no interests, returning empty list');
        return [];
      }

      // Get the interests list
      final interests = List<String>.from(userData['interests'] ?? []);
      Logger.d('EventService', 'Found user interests: $interests');
      return interests;
    } catch (e) {
      Logger.e('EventService', 'Error getting user interests', e);
      return []; // Return empty list on error
    }
  }

  // Get user followed accounts
  Future<List<String>> _getUserFollowedAccounts() async {
    try {
      Logger.d('EventService', 'Getting user followed accounts');

      // If not authenticated, return empty list
      if (_currentUserId.isEmpty) {
        Logger.d('EventService', 'User not authenticated, returning empty followed accounts list');
        return [];
      }

      // Get the user's following collection
      final followingSnapshot = await _retryService.executeWithRetry<QuerySnapshot>(
        operation: () => _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('following')
            .get(),
        maxRetries: 3,
        shouldRetry: _retryService.isFirestoreRetryableError,
        operationName: 'getUserFollowedAccounts',
      );

      // Extract user IDs from the following collection
      final followedUserIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      // Limit the number of followed accounts to process (for performance)
      const maxFollowedAccounts = 100;
      final limitedFollowedUserIds = followedUserIds.length > maxFollowedAccounts
          ? followedUserIds.sublist(0, maxFollowedAccounts)
          : followedUserIds;

      Logger.d('EventService', 'Found ${limitedFollowedUserIds.length} followed accounts (limited from ${followedUserIds.length})');
      return limitedFollowedUserIds;
    } on FirebaseException catch (e) {
      Logger.e('EventService', 'Firebase error getting followed accounts: ${e.code}', e);
      return []; // Return empty list on error
    } catch (e) {
      Logger.e('EventService', 'Error getting followed accounts', e);
      return []; // Return empty list on error
    }
  }

  // Refresh the event cache
  Future<void> refreshEventCache() async {
    try {
      Logger.d('EventService', 'Refreshing event cache');

      // Clear the event cache
      _eventCacheService.clearCache();

      // Prefetch some recent events to populate the cache
      final query = _eventsCollection
          .orderBy('createdAt', descending: true)
          .limit(20);

      final querySnapshot = await _retryService.executeWithRetry<QuerySnapshot>(
        operation: () => query.get(),
        maxRetries: 3,
        shouldRetry: _retryService.isFirestoreRetryableError,
        operationName: 'refreshEventCache',
      );

      // Update the cache with the fetched events
      for (final doc in querySnapshot.docs) {
        final event = EventModel.fromFirestore(doc);
        _eventCacheService.updateEvent(event);
      }

      // Also clear the followed accounts and interests cache to ensure fresh data
      cachedFollowedAccounts = null;
      cachedUserInterests = null;
      lastCacheTime = null;

      Logger.d('EventService', 'Event cache refreshed with ${querySnapshot.docs.length} events');
    } catch (e) {
      Logger.e('EventService', 'Error refreshing event cache', e);
      rethrow;
    }
  }

  // Handle pull-to-refresh action from UI
  Future<bool> handlePullToRefresh() async {
    try {
      Logger.d('EventService', 'Handling pull-to-refresh');

      // Refresh the event cache
      await refreshEventCache();

      // Force a Firestore refresh by making a small query
      // This helps ensure the streams get fresh data
      final query = _eventsCollection
          .orderBy('createdAt', descending: true)
          .limit(10);

      final snapshot = await query.get();
      Logger.d('EventService', 'Forced Firestore refresh, found ${snapshot.docs.length} events');

      // Update the cache with the fetched events
      for (final doc in snapshot.docs) {
        final event = EventModel.fromFirestore(doc);
        _eventCacheService.updateEvent(event);
        Logger.d('EventService', 'Updated cache for event: ${event.id}');
      }

      // Clear the cached data to force a refresh
      cachedFollowedAccounts = null;
      cachedUserInterests = null;
      lastCacheTime = null;

      // The streams will automatically update with the new data
      // since they're listening to Firestore changes
      return true;
    } catch (e) {
      Logger.e('EventService', 'Error handling pull-to-refresh', e);
      return false;
    }
  }

  // Check if there are any events in the database
  Future<bool> hasEvents() async {
    try {
      Logger.d('EventService', 'Checking if there are any events in the database');

      final query = _eventsCollection.limit(1);
      final snapshot = await query.get();

      final hasEvents = snapshot.docs.isNotEmpty;
      Logger.d('EventService', 'Database has events: $hasEvents');

      return hasEvents;
    } catch (e) {
      Logger.e('EventService', 'Error checking if there are events', e);
      return false;
    }
  }

  // Get events that the current user has joined or created
  // JOINED filter: Shows all events the user has been accepted to and all events the user has created
  // If there are no joined events, it will display "You haven't joined any events yet"
  Stream<List<EventModel>> getJoinedEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    Logger.d('EventService', 'Getting joined events, user ID: $_currentUserId, pagination: ${startAfter != null}');

    // For the JOINED filter, we need authentication
    if (_currentUserId.isEmpty) {
      Logger.d('EventService', 'User not authenticated, returning empty list for JOINED filter');
      return Stream.value([]);
    }

    // Create two separate queries and merge the results
    // 1. Events created by the user (all events, both private and public)
    Query createdQuery = _eventsCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true);

    // 2. Events joined by the user (but not created by them)
    // This includes events where the user is in the joinedBy array
    Query joinedQuery = _eventsCollection
        .where('joinedBy', arrayContains: _currentUserId)
        .where('userId', isNotEqualTo: _currentUserId) // Exclude events created by the user
        .orderBy('userId') // Required when using isNotEqualTo
        .orderBy('createdAt', descending: true);

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      createdQuery = createdQuery.startAfterDocument(startAfter);
      joinedQuery = joinedQuery.startAfterDocument(startAfter);
    }

    // Apply limit to both queries
    // We'll get more events than needed and then take only the requested number
    createdQuery = createdQuery.limit(limit);
    joinedQuery = joinedQuery.limit(limit);

    // Get events created by the user
    final createdEventsStream = createdQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} created events');
      return events;
    });

    // Get events joined by the user
    final joinedEventsStream = joinedQuery.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Update the cache for each event
      for (final event in events) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('EventService', 'Found ${events.length} joined events');
      return events;
    });

    // Combine both streams
    return StreamGroup.merge([createdEventsStream, joinedEventsStream])
        .map((events) {
          // Sort by createdAt
          events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Remove duplicates using content-based deduplication
          Logger.d('EventService', '🔍 STARTING CONTENT-BASED DEDUPLICATION (JOINED FILTER) - Found ${events.length} events to process');
          final uniqueEvents = <EventModel>[];
          final seenIds = <String>{};
          final seenContentKeys = <String>{};

          for (final event in events) {
            // Generate a content key for this event
            final contentKey = '${event.userId}-${event.inquiry}-${event.date.year}-${event.date.month}-${event.date.day}-${event.time.hour}-${event.time.minute}';

            // Check if we've already seen this event (by ID or content)
            if (!seenIds.contains(event.id) && !seenContentKeys.contains(contentKey)) {
              uniqueEvents.add(event);
              seenIds.add(event.id);
              seenContentKeys.add(contentKey);
              Logger.d('EventService', 'JOINED filter - Added unique event: ${event.id}, content key: $contentKey');
            } else {
              Logger.d('EventService', 'JOINED filter - Skipped duplicate event: ${event.id}, content key: $contentKey');
            }
          }
          // Limit to requested number
          final limitedEvents = uniqueEvents.take(limit).toList();
          Logger.d('EventService', 'Returning ${limitedEvents.length} joined/created events');
          return limitedEvents;
          // Note: The UI will handle showing "You haven't joined any events yet" when the list is empty
          // This is typically done in the widget that displays the events, not in the service
        });
  }

  // Get user display name from user ID
  Future<String> getUserDisplayName(String userId) async {
    try {
      Logger.d('EventService', 'Getting display name for user: $userId');

      if (userId.isEmpty) {
        return 'Unknown User';
      }

      // Fetch from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        Logger.e('EventService', 'User document not found: $userId');
        return 'Unknown User';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final displayName = userData['displayName'] as String? ?? 'Unknown User';

      return displayName;
    } catch (e) {
      Logger.e('EventService', 'Error getting user display name', e);
      return 'Unknown User';
    }
  }

  // Search events based on query and activity type
  Future<List<EventModel>> searchEvents({
    required String query,
    String? activityType,
  }) async {
    try {
      Logger.d('EventService', 'Searching events with query: "$query", activityType: $activityType');

      // Start with a base query
      Query baseQuery = _eventsCollection;

      // If user is not authenticated, only show public events
      if (_currentUserId.isEmpty) {
        baseQuery = baseQuery.where('isPrivate', isEqualTo: false);
      }

      // Filter by activity type if specified
      if (activityType != null && activityType.isNotEmpty) {
        baseQuery = baseQuery.where('activityType', isEqualTo: activityType);
      }

      // Get all matching events (limited to 100 for performance)
      // We'll filter by the search query in memory since Firestore doesn't support
      // full-text search or contains queries
      final querySnapshot = await baseQuery.limit(100).get();

      // Convert to EventModel objects
      final allEvents = querySnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      // Filter events based on the search query
      final normalizedQuery = query.toLowerCase().trim();
      final filteredEvents = allEvents.where((event) {
        // Check if the event matches the search query
        final matchesInquiry = event.inquiry.toLowerCase().contains(normalizedQuery);
        final matchesActivityType = event.activityType.toLowerCase().contains(normalizedQuery);

        // Check privacy settings
        final isPublic = !event.isPrivate;
        final isCreatedByUser = event.userId == _currentUserId;
        final isJoinedByUser = event.joinedBy.contains(_currentUserId);

        // Include the event if:
        // 1. It matches the search query (in inquiry or activity type)
        // 2. It's either public, created by the user, or the user has joined it
        return (matchesInquiry || matchesActivityType) &&
               (isPublic || isCreatedByUser || isJoinedByUser);
      }).toList();

      // Sort results by relevance and recency
      filteredEvents.sort((a, b) {
        // First, prioritize exact matches
        final aExactMatch = a.inquiry.toLowerCase() == normalizedQuery ||
                           a.activityType.toLowerCase() == normalizedQuery;
        final bExactMatch = b.inquiry.toLowerCase() == normalizedQuery ||
                           b.activityType.toLowerCase() == normalizedQuery;

        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;

        // Then, prioritize events happening soon
        final now = DateTime.now();
        final aIsUpcoming = a.date.isAfter(now) && a.date.isBefore(now.add(const Duration(days: 7)));
        final bIsUpcoming = b.date.isAfter(now) && b.date.isBefore(now.add(const Duration(days: 7)));

        if (aIsUpcoming && !bIsUpcoming) return -1;
        if (!aIsUpcoming && bIsUpcoming) return 1;

        // Finally, sort by recency
        return b.createdAt.compareTo(a.createdAt);
      });

      Logger.d('EventService', 'Search returned ${filteredEvents.length} results');
      return filteredEvents;
    } catch (e) {
      Logger.e('EventService', 'Error searching events', e);
      return [];
    }
  }

  // Advanced search with more filters
  Future<List<EventModel>> advancedSearch({
    String? query,
    String? activityType,
    DateTime? startDate,
    DateTime? endDate,
    bool? onlyJoined,
  }) async {
    try {
      Logger.d('EventService', 'Advanced search with filters: query=$query, activityType=$activityType, dateRange=$startDate-$endDate, onlyJoined=$onlyJoined');

      // Get base results from the simple search
      List<EventModel> results = await searchEvents(
        query: query ?? '',
        activityType: activityType,
      );

      // Apply additional filters
      if (startDate != null || endDate != null) {
        results = results.where((event) {
          if (startDate != null && event.date.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && event.date.isAfter(endDate)) {
            return false;
          }
          return true;
        }).toList();
      }

      if (onlyJoined == true && _currentUserId.isNotEmpty) {
        results = results.where((event) {
          return event.userId == _currentUserId || event.joinedBy.contains(_currentUserId);
        }).toList();
      }

      Logger.d('EventService', 'Advanced search returned ${results.length} results');
      return results;
    } catch (e) {
      Logger.e('EventService', 'Error in advanced search', e);
      return [];
    }
  }
}
