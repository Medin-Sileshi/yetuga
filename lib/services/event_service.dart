import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';

// Provider for the EventService
final eventServiceProvider = Provider<EventService>((ref) => EventService());

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  Stream<List<EventModel>> getEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    Query query = _eventsCollection.orderBy('createdAt', descending: true);

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
  Stream<List<EventModel>> getPublicEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    Query query = _eventsCollection
        .where('isPrivate', isEqualTo: false) // Use a proper query instead of filtering in memory
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

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      Logger.d('EventService', 'Deleting event with ID: $eventId');
      await _eventsCollection.doc(eventId).delete();
      Logger.d('EventService', 'Event deleted successfully');
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
      await _eventsCollection.doc(event.id).update(event.toMap());
      Logger.d('EventService', 'Event updated successfully');
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

      // Get the current event data
      final docRef = _eventsCollection.doc(eventId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        Logger.e('EventService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      final event = EventModel.fromFirestore(docSnapshot);

      // Check if user already liked this event
      final isLiked = event.likedBy.contains(_currentUserId);

      // Update the event in Firestore using array operations
      if (isLiked) {
        // Remove like using arrayRemove
        await docRef.update({
          'likedBy': FieldValue.arrayRemove([_currentUserId])
        });
        Logger.d('EventService', 'Removing like from event: $eventId');
      } else {
        // Add like using arrayUnion
        await docRef.update({
          'likedBy': FieldValue.arrayUnion([_currentUserId])
        });
        Logger.d('EventService', 'Adding like to event: $eventId');
      }

      // Return the new like state
      return !isLiked;
    } catch (e) {
      Logger.e('EventService', 'Error toggling like', e);
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

      // Get the current event data
      final docRef = _eventsCollection.doc(eventId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        Logger.e('EventService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      final event = EventModel.fromFirestore(docSnapshot);

      // Check if user already joined this event
      final hasJoined = event.joinedBy.contains(_currentUserId);

      // Update the event in Firestore using array operations
      if (hasJoined) {
        // Remove join using arrayRemove
        await docRef.update({
          'joinedBy': FieldValue.arrayRemove([_currentUserId])
        });
        Logger.d('EventService', 'Removing join from event: $eventId');
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
      }

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

  // Get events that the current user has joined or created
  Stream<List<EventModel>> getJoinedEvents({int limit = 10, DocumentSnapshot? startAfter}) {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    // We can't directly query for array membership with pagination in Firestore
    // So we'll get all events and filter in memory
    Query query = _eventsCollection
        .orderBy('createdAt', descending: true);

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Apply a larger limit since we'll be filtering in memory
    // This is a workaround for the limitation of array-contains with pagination
    query = query.limit(limit * 3);

    return query.snapshots().map((snapshot) {
      // Filter events where the current user is in the joinedBy array OR is the creator
      final joinedEvents = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .where((event) =>
              event.joinedBy.contains(_currentUserId) || // User has joined the event
              event.userId == _currentUserId              // User created the event
          )
          .take(limit) // Only take the requested number of events
          .toList();

      Logger.d('EventService', 'Found ${joinedEvents.length} joined/created events');
      return joinedEvents;
    });
  }
}
