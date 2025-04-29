import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rsvp_model.dart';
import '../models/notification_model.dart';
import '../utils/logger.dart';
import 'push_notification_service.dart';

// Provider for the RSVPService
final rsvpServiceProvider = Provider<RSVPService>((ref) {
  final pushNotificationService = ref.read(pushNotificationServiceProvider);
  return RSVPService(pushNotificationService);
});

class RSVPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PushNotificationService _pushNotificationService;

  RSVPService(this._pushNotificationService);

  // Collection references
  CollectionReference get _rsvpCollection => _firestore.collection('rsvp');
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');
  CollectionReference get _eventsCollection => _firestore.collection('events');

  // Get current user ID
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Send an invitation to a user
  Future<String> sendInvitation(String eventId, String inviteeId) async {
    try {
      Logger.d('RSVPService', 'Sending invitation for event: $eventId to user: $inviteeId');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('RSVPService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Get event details to check if it exists
      final eventDoc = await _eventsCollection.doc(eventId).get();
      if (!eventDoc.exists) {
        Logger.e('RSVPService', 'Event not found: $eventId');
        throw Exception('Event not found');
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final isPrivate = eventData['isPrivate'] as bool? ?? false;
      Logger.d('RSVPService', 'Event is private: $isPrivate');

      // Create the RSVP
      final rsvp = RSVPModel(
        eventId: eventId,
        inviterId: _currentUserId,
        inviteeId: inviteeId,
        status: 'pending', // Explicitly set status to pending
      );

      // Log the RSVP data for debugging
      Logger.d('RSVPService', 'Creating RSVP with data: ${rsvp.toMap()}');

      // Add to Firestore
      final docRef = await _rsvpCollection.add(rsvp.toMap());
      Logger.d('RSVPService', 'RSVP created with ID: ${docRef.id}');

      // Verify the RSVP was created
      final verifyDoc = await _rsvpCollection.doc(docRef.id).get();
      if (verifyDoc.exists) {
        Logger.d('RSVPService', 'Verified RSVP exists in Firestore: ${verifyDoc.data()}');
      } else {
        Logger.e('RSVPService', 'Failed to verify RSVP in Firestore after creation');
      }

      // Get event details for notification
      final eventInquiry = eventData['inquiry'] as String? ?? 'an event';

      // Get inviter's display name
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final displayName = userData?['displayName'] as String? ?? 'Someone';

      // Create a notification for the invitee
      final notification = NotificationModel(
        userId: inviteeId, // Send to invitee
        senderId: _currentUserId, // From current user
        eventId: eventId,
        type: NotificationType.eventInvitation, // Using the invitation type
        status: NotificationStatus.pending,
        message: '$displayName invited you to join "$eventInquiry"',
      );

      // Log the notification data for debugging
      Logger.d('RSVPService', 'Creating notification with data: ${notification.toMap()}');

      // Add notification to Firestore
      final notificationRef = await _notificationsCollection.add(notification.toMap());
      Logger.d('RSVPService', 'Notification created with ID: ${notificationRef.id}');

      // Double-check that the notification was created
      final notificationDoc = await _notificationsCollection.doc(notificationRef.id).get();
      if (notificationDoc.exists) {
        Logger.d('RSVPService', 'Notification verified in Firestore: ${notificationDoc.data()}');
      } else {
        Logger.e('RSVPService', 'Notification not found in Firestore after creation');
      }

      // Send push notification to invitee
      try {
        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: inviteeId,
          title: 'New Event Invitation',
          body: '$displayName invited you to join: $eventInquiry',
          data: {
            'type': 'event_invitation',
            'eventId': eventId,
            'rsvpId': docRef.id,
            'notificationId': notificationRef.id,
            'senderId': _currentUserId,
          },
        );

        Logger.d('RSVPService', 'Push notification sent to invitee');
      } catch (e) {
        Logger.e('RSVPService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }

      return docRef.id;
    } catch (e) {
      Logger.e('RSVPService', 'Error sending invitation', e);
      rethrow;
    }
  }

  // Accept an invitation
  Future<void> acceptInvitation(String rsvpId) async {
    try {
      Logger.d('RSVPService', 'Accepting invitation: $rsvpId');

      // Get the RSVP
      final docSnapshot = await _rsvpCollection.doc(rsvpId).get();
      if (!docSnapshot.exists) {
        Logger.e('RSVPService', 'RSVP not found: $rsvpId');
        throw Exception('RSVP not found');
      }

      final rsvp = RSVPModel.fromFirestore(docSnapshot);

      // Update the RSVP status
      await _rsvpCollection.doc(rsvpId).update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add user to event's joinedBy array
      await _eventsCollection.doc(rsvp.eventId).update({
        'joinedBy': FieldValue.arrayUnion([_currentUserId])
      });

      Logger.d('RSVPService', 'Invitation accepted and user added to event');

      // Create a notification for the inviter
      final acceptedNotification = NotificationModel(
        userId: rsvp.inviterId, // Send to inviter
        senderId: _currentUserId, // From current user
        eventId: rsvp.eventId,
        type: NotificationType.invitationAccepted,
        status: NotificationStatus.read,
        message: 'accepted your invitation to join the event',
      );

      final acceptedNotificationRef = await _notificationsCollection.add(acceptedNotification.toMap());
      Logger.d('RSVPService', 'Acceptance notification created with ID: ${acceptedNotificationRef.id}');

      // Send push notification to inviter
      try {
        // Get the current user's display name
        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] as String? ?? 'Someone';

        // Get event details
        final eventDoc = await _eventsCollection.doc(rsvp.eventId).get();
        final eventData = eventDoc.data() as Map<String, dynamic>?;
        final eventInquiry = eventData?['inquiry'] as String? ?? 'your event';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: rsvp.inviterId,
          title: 'Invitation Accepted',
          body: '$displayName accepted your invitation to join: $eventInquiry',
          data: {
            'type': 'invitation_accepted',
            'eventId': rsvp.eventId,
            'rsvpId': rsvpId,
            'notificationId': acceptedNotificationRef.id,
            'senderId': _currentUserId,
          },
        );

        Logger.d('RSVPService', 'Push notification sent to inviter');
      } catch (e) {
        Logger.e('RSVPService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }
    } catch (e) {
      Logger.e('RSVPService', 'Error accepting invitation', e);
      rethrow;
    }
  }

  // Decline an invitation
  Future<void> declineInvitation(String rsvpId) async {
    try {
      Logger.d('RSVPService', 'Declining invitation: $rsvpId');

      // Get the RSVP
      final docSnapshot = await _rsvpCollection.doc(rsvpId).get();
      if (!docSnapshot.exists) {
        Logger.e('RSVPService', 'RSVP not found: $rsvpId');
        throw Exception('RSVP not found');
      }

      final rsvp = RSVPModel.fromFirestore(docSnapshot);

      // Update the RSVP status
      await _rsvpCollection.doc(rsvpId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      Logger.d('RSVPService', 'Invitation declined');

      // Create a notification for the inviter
      final declinedNotification = NotificationModel(
        userId: rsvp.inviterId, // Send to inviter
        senderId: _currentUserId, // From current user
        eventId: rsvp.eventId,
        type: NotificationType.invitationRejected,
        status: NotificationStatus.read,
        message: 'declined your invitation to join the event',
      );

      final declinedNotificationRef = await _notificationsCollection.add(declinedNotification.toMap());
      Logger.d('RSVPService', 'Decline notification created with ID: ${declinedNotificationRef.id}');

      // Send push notification to inviter
      try {
        // Get the current user's display name
        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] as String? ?? 'Someone';

        // Get event details
        final eventDoc = await _eventsCollection.doc(rsvp.eventId).get();
        final eventData = eventDoc.data() as Map<String, dynamic>?;
        final eventInquiry = eventData?['inquiry'] as String? ?? 'your event';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: rsvp.inviterId,
          title: 'Invitation Declined',
          body: '$displayName declined your invitation to join: $eventInquiry',
          data: {
            'type': 'invitation_declined',
            'eventId': rsvp.eventId,
            'rsvpId': rsvpId,
            'notificationId': declinedNotificationRef.id,
            'senderId': _currentUserId,
          },
        );

        Logger.d('RSVPService', 'Push notification sent to inviter');
      } catch (e) {
        Logger.e('RSVPService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }
    } catch (e) {
      Logger.e('RSVPService', 'Error declining invitation', e);
      rethrow;
    }
  }

  // Check if a user is invited to an event
  Future<bool> isUserInvited(String eventId, String userId) async {
    try {
      Logger.d('RSVPService', 'Checking if user $userId is invited to event $eventId');

      // Query for RSVPs for this event and user
      final querySnapshot = await _rsvpCollection
          .where('eventId', isEqualTo: eventId)
          .where('inviteeId', isEqualTo: userId)
          .get();

      final isInvited = querySnapshot.docs.isNotEmpty;
      Logger.d('RSVPService', 'User $userId is invited to event $eventId: $isInvited');
      return isInvited;
    } catch (e) {
      Logger.e('RSVPService', 'Error checking if user is invited', e);
      return false;
    }
  }

  // Get all RSVPs for an event
  Future<List<RSVPModel>> getRSVPsForEvent(String eventId) async {
    try {
      Logger.d('RSVPService', 'Getting RSVPs for event: $eventId');

      // Query for RSVPs for this event
      final querySnapshot = await _rsvpCollection
          .where('eventId', isEqualTo: eventId)
          .get();

      final rsvps = querySnapshot.docs
          .map((doc) => RSVPModel.fromFirestore(doc))
          .toList();

      Logger.d('RSVPService', 'Found ${rsvps.length} RSVPs for event: $eventId');
      return rsvps;
    } catch (e) {
      Logger.e('RSVPService', 'Error getting RSVPs for event', e);
      return [];
    }
  }

  // Get all RSVPs for a user (as invitee)
  Stream<List<RSVPModel>> getRSVPs() {
    if (_currentUserId.isEmpty) {
      Logger.d('RSVPService', 'Current user ID is empty, returning empty list');
      return Stream.value([]);
    }

    Logger.d('RSVPService', 'Getting RSVPs for user: $_currentUserId');

    Logger.d('RSVPService', 'Creating query for RSVPs where inviteeId = $_currentUserId');
    final query = _rsvpCollection.where('inviteeId', isEqualTo: _currentUserId);
    Logger.d('RSVPService', 'Query: ${query.toString()}');

    return query.snapshots().map((snapshot) {
      Logger.d('RSVPService', 'Got snapshot with ${snapshot.docs.length} documents');

      for (final doc in snapshot.docs) {
        Logger.d('RSVPService', 'RSVP document: id=${doc.id}, data=${doc.data()}');
      }

      final rsvps = snapshot.docs
          .map((doc) => RSVPModel.fromFirestore(doc))
          .toList();

      Logger.d('RSVPService', 'Found ${rsvps.length} RSVPs for user: $_currentUserId');
      return rsvps;
    });
  }

  // Get all pending RSVPs for a user (as invitee)
  Stream<List<RSVPModel>> getPendingRSVPs() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    Logger.d('RSVPService', 'Getting pending RSVPs for user: $_currentUserId');

    return _rsvpCollection
        .where('inviteeId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final rsvps = snapshot.docs
              .map((doc) => RSVPModel.fromFirestore(doc))
              .toList();

          Logger.d('RSVPService', 'Found ${rsvps.length} pending RSVPs for user: $_currentUserId');
          return rsvps;
        });
  }

  // Get all RSVPs sent by a user (as inviter)
  Stream<List<RSVPModel>> getSentRSVPs() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    Logger.d('RSVPService', 'Getting sent RSVPs for user: $_currentUserId');

    return _rsvpCollection
        .where('inviterId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
          final rsvps = snapshot.docs
              .map((doc) => RSVPModel.fromFirestore(doc))
              .toList();

          Logger.d('RSVPService', 'Found ${rsvps.length} sent RSVPs for user: $_currentUserId');
          return rsvps;
        });
  }
}
