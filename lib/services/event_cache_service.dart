import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';

// Provider for the EventCacheService
final eventCacheServiceProvider = Provider<EventCacheService>((ref) => EventCacheService());

class EventCacheService {
  // Cache for events
  final Map<String, EventModel> _eventCache = {};

  // Cache expiration time (5 minutes)
  final Duration _cacheExpiration = const Duration(minutes: 5);

  // Cache timestamps to track when events were added
  final Map<String, DateTime> _cacheTimestamps = {};

  // Get an event from cache or Firestore
  Future<EventModel?> getEvent(String eventId) async {
    // Check if cache is expired
    if (_cacheTimestamps.containsKey(eventId)) {
      final timestamp = _cacheTimestamps[eventId]!;
      final now = DateTime.now();
      if (now.difference(timestamp) > _cacheExpiration) {
        // Cache is expired, remove it
        _eventCache.remove(eventId);
        _cacheTimestamps.remove(eventId);
      }
    }

    // Check cache first
    if (_eventCache.containsKey(eventId)) {
      Logger.d('EventCacheService', 'Cache hit for event: $eventId');
      return _eventCache[eventId];
    }

    // If not in cache, fetch from Firestore
    try {
      Logger.d('EventCacheService', 'Cache miss for event: $eventId, fetching from Firestore');
      final docSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (docSnapshot.exists) {
        final event = EventModel.fromFirestore(docSnapshot);
        // Update cache
        _eventCache[eventId] = event;
        _cacheTimestamps[eventId] = DateTime.now();
        return event;
      }
    } catch (e) {
      Logger.e('EventCacheService', 'Error fetching event', e);
    }

    return null;
  }

  // Update cache when an event changes
  void updateEvent(EventModel event) {
    Logger.d('EventCacheService', 'Updating cache for event: ${event.id}');
    _eventCache[event.id] = event;
    _cacheTimestamps[event.id] = DateTime.now();
  }

  // Get multiple events from cache or Firestore
  Future<List<EventModel>> getEvents(List<String> eventIds) async {
    final List<EventModel> events = [];
    final List<String> missingIds = [];

    // Check cache first for each event
    for (final eventId in eventIds) {
      // Check if cache is expired
      if (_cacheTimestamps.containsKey(eventId)) {
        final timestamp = _cacheTimestamps[eventId]!;
        final now = DateTime.now();
        if (now.difference(timestamp) > _cacheExpiration) {
          // Cache is expired, remove it
          _eventCache.remove(eventId);
          _cacheTimestamps.remove(eventId);
          missingIds.add(eventId);
        } else if (_eventCache.containsKey(eventId)) {
          // Cache hit
          events.add(_eventCache[eventId]!);
        } else {
          missingIds.add(eventId);
        }
      } else {
        missingIds.add(eventId);
      }
    }

    // Fetch missing events from Firestore
    if (missingIds.isNotEmpty) {
      try {
        Logger.d('EventCacheService', 'Fetching ${missingIds.length} missing events from Firestore');

        // Firestore has a limit of 10 items for 'in' queries, so we need to batch
        const batchSize = 10;
        for (var i = 0; i < missingIds.length; i += batchSize) {
          final end = (i + batchSize < missingIds.length) ? i + batchSize : missingIds.length;
          final batch = missingIds.sublist(i, end);

          final querySnapshot = await FirebaseFirestore.instance
              .collection('events')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in querySnapshot.docs) {
            final event = EventModel.fromFirestore(doc);
            events.add(event);

            // Update cache
            _eventCache[event.id] = event;
            _cacheTimestamps[event.id] = DateTime.now();
          }
        }
      } catch (e) {
        Logger.e('EventCacheService', 'Error fetching multiple events', e);
      }
    }

    return events;
  }

  // Remove an event from the cache
  void removeEvent(String eventId) {
    Logger.d('EventCacheService', 'Removing event from cache: $eventId');
    _eventCache.remove(eventId);
    _cacheTimestamps.remove(eventId);
  }

  // Clear the cache
  void clearCache() {
    Logger.d('EventCacheService', 'Clearing event cache');
    _eventCache.clear();
    _cacheTimestamps.clear();
  }

  // Get the number of cached events
  int get cacheSize => _eventCache.length;
}
