import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';

// Provider for the BatchService
final batchServiceProvider = Provider<BatchService>((ref) => BatchService());

class BatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Maximum batch size (Firestore limit is 500)
  static const int _maxBatchSize = 500;

  // Perform multiple updates on events in a batch
  Future<void> updateEvents(List<EventModel> events) async {
    if (events.isEmpty) return;

    try {
      Logger.d('BatchService', 'Updating ${events.length} events in batch');

      // Split into smaller batches if needed (Firestore limit is 500 operations per batch)
      final batches = <List<EventModel>>[];
      for (var i = 0; i < events.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < events.length) ? i + _maxBatchSize : events.length;
        batches.add(events.sublist(i, end));
      }

      // Process each batch
      for (final batchEvents in batches) {
        final batch = _firestore.batch();

        for (final event in batchEvents) {
          final docRef = _firestore.collection('events').doc(event.id);
          batch.update(docRef, event.toMap());
        }

        await batch.commit();
        Logger.d('BatchService', 'Committed batch of ${batchEvents.length} events');
      }
    } catch (e) {
      Logger.e('BatchService', 'Error updating events in batch', e);
      rethrow;
    }
  }

  // Toggle like for multiple events in a batch
  Future<void> toggleLikesInBatch(Map<String, bool> eventLikes, String userId) async {
    if (eventLikes.isEmpty) return;

    try {
      Logger.d('BatchService', 'Toggling likes for ${eventLikes.length} events in batch');

      // Split into smaller batches if needed
      final entries = eventLikes.entries.toList();
      final batches = <List<MapEntry<String, bool>>>[];
      for (var i = 0; i < entries.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < entries.length) ? i + _maxBatchSize : entries.length;
        batches.add(entries.sublist(i, end));
      }

      // Process each batch
      for (final batchEntries in batches) {
        final batch = _firestore.batch();

        for (final entry in batchEntries) {
          final eventId = entry.key;
          final shouldLike = entry.value;
          final docRef = _firestore.collection('events').doc(eventId);

          if (shouldLike) {
            // Add like
            batch.update(docRef, {
              'likedBy': FieldValue.arrayUnion([userId])
            });
          } else {
            // Remove like
            batch.update(docRef, {
              'likedBy': FieldValue.arrayRemove([userId])
            });
          }
        }

        await batch.commit();
        Logger.d('BatchService', 'Committed batch of ${batchEntries.length} like operations');
      }
    } catch (e) {
      Logger.e('BatchService', 'Error toggling likes in batch', e);
      rethrow;
    }
  }

  // Delete multiple events in a batch
  Future<void> deleteEventsInBatch(List<String> eventIds) async {
    if (eventIds.isEmpty) return;

    try {
      Logger.d('BatchService', 'Deleting ${eventIds.length} events in batch');

      // Split into smaller batches if needed
      final batches = <List<String>>[];
      for (var i = 0; i < eventIds.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < eventIds.length) ? i + _maxBatchSize : eventIds.length;
        batches.add(eventIds.sublist(i, end));
      }

      // Process each batch
      for (final batchIds in batches) {
        final batch = _firestore.batch();

        for (final eventId in batchIds) {
          final docRef = _firestore.collection('events').doc(eventId);
          batch.delete(docRef);
        }

        await batch.commit();
        Logger.d('BatchService', 'Committed batch of ${batchIds.length} event deletions');
      }
    } catch (e) {
      Logger.e('BatchService', 'Error deleting events in batch', e);
      rethrow;
    }
  }

  // Create multiple invitations in a batch
  Future<void> createInvitationsInBatch(String eventId, List<String> inviteeIds, String inviterId) async {
    Logger.d('BatchService', 'createInvitationsInBatch called with eventId: $eventId, inviteeIds: $inviteeIds, inviterId: $inviterId');
    Logger.d('BatchService', 'inviteeIds type: ${inviteeIds.runtimeType}');
    if (inviteeIds.isEmpty) {
      Logger.d('BatchService', 'No invitees provided, skipping batch creation');
      return;
    }

    try {
      Logger.d('BatchService', 'Creating ${inviteeIds.length} invitations in batch for event: $eventId');
      Logger.d('BatchService', 'Inviter ID: $inviterId');
      Logger.d('BatchService', 'Invitee IDs: $inviteeIds');

      // Get event details for better notifications
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        Logger.e('BatchService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      final eventData = eventDoc.data();
      final eventInquiry = eventData?['inquiry'] ?? 'an event';
      final isPrivate = eventData?['isPrivate'] ?? false;
      Logger.d('BatchService', 'Event inquiry: $eventInquiry, isPrivate: $isPrivate');

      // Get inviter's display name
      final userDoc = await _firestore.collection('users').doc(inviterId).get();
      final userData = userDoc.data();
      final displayName = userData?['displayName'] ?? 'Someone';
      Logger.d('BatchService', 'Inviter display name: $displayName');

      // Split into smaller batches if needed
      final batches = <List<String>>[];
      for (var i = 0; i < inviteeIds.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < inviteeIds.length) ? i + _maxBatchSize : inviteeIds.length;
        batches.add(inviteeIds.sublist(i, end));
      }

      Logger.d('BatchService', 'Split into ${batches.length} batches');

      // Process each batch
      for (final batchInvitees in batches) {
        final batch = _firestore.batch();
        final createdRSVPIds = <String>[];
        final createdNotificationIds = <String>[];

        for (final inviteeId in batchInvitees) {
          // Create RSVP document
          final rsvpRef = _firestore.collection('rsvp').doc();
          final rsvpData = {
            'eventId': eventId,
            'inviterId': inviterId,
            'inviteeId': inviteeId,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          };

          Logger.d('BatchService', 'Creating RSVP document with ID: ${rsvpRef.id} and data: $rsvpData');
          batch.set(rsvpRef, rsvpData);
          createdRSVPIds.add(rsvpRef.id);
          Logger.d('BatchService', 'Adding RSVP to batch: ${rsvpRef.id} for invitee: $inviteeId');

          // Create notification document
          final notificationRef = _firestore.collection('notifications').doc();
          final notificationData = {
            'userId': inviteeId,
            'senderId': inviterId,
            'eventId': eventId,
            'type': 'eventInvitation',
            'status': 'pending',
            'message': '$displayName invited you to join "$eventInquiry"',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          };

          batch.set(notificationRef, notificationData);
          createdNotificationIds.add(notificationRef.id);
          Logger.d('BatchService', 'Adding notification to batch: ${notificationRef.id} for invitee: $inviteeId');
        }

        try {
          Logger.d('BatchService', 'Committing batch with ${batchInvitees.length} RSVPs...');
          Logger.d('BatchService', 'RSVP IDs to be created: $createdRSVPIds');
          Logger.d('BatchService', 'Notification IDs to be created: $createdNotificationIds');
          await batch.commit();
          Logger.d('BatchService', 'Batch committed successfully');

          // Verify the RSVPs were created
          for (final rsvpId in createdRSVPIds) {
            try {
              final verifyDoc = await _firestore.collection('rsvp').doc(rsvpId).get();
              if (verifyDoc.exists) {
                Logger.d('BatchService', 'Verified RSVP exists: $rsvpId');
              } else {
                Logger.e('BatchService', 'Failed to verify RSVP: $rsvpId');
              }
            } catch (e) {
              Logger.e('BatchService', 'Error verifying RSVP: $rsvpId', e);
            }
          }
        } catch (e) {
          Logger.e('BatchService', 'Error committing batch', e);
          rethrow; // Re-throw to be caught by the outer try-catch
        }
        Logger.d('BatchService', 'Committed batch of ${batchInvitees.length} RSVPs');
        Logger.d('BatchService', 'Created RSVP IDs: $createdRSVPIds');
        Logger.d('BatchService', 'Created notification IDs: $createdNotificationIds');

        // Verify a few of the created documents
        if (createdRSVPIds.isNotEmpty) {
          final verifyRSVPId = createdRSVPIds.first;
          final verifyRSVPDoc = await _firestore.collection('rsvp').doc(verifyRSVPId).get();
          if (verifyRSVPDoc.exists) {
            Logger.d('BatchService', 'Verified RSVP: ${verifyRSVPDoc.data()}');
          } else {
            Logger.e('BatchService', 'Failed to verify RSVP: $verifyRSVPId');
          }
        }

        if (createdNotificationIds.isNotEmpty) {
          final verifyNotificationId = createdNotificationIds.first;
          final verifyNotificationDoc = await _firestore.collection('notifications').doc(verifyNotificationId).get();
          if (verifyNotificationDoc.exists) {
            Logger.d('BatchService', 'Verified notification: ${verifyNotificationDoc.data()}');
          } else {
            Logger.e('BatchService', 'Failed to verify notification: $verifyNotificationId');
          }
        }
      }
    } catch (e) {
      Logger.e('BatchService', 'Error creating RSVPs in batch', e);
      rethrow;
    }
  }
}
