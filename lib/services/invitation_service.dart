import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_invitation_model.dart';
import '../models/event_model.dart';
import '../models/notification_model.dart';
import '../services/push_notification_service.dart';
import '../utils/logger.dart';

// Provider for the InvitationService
final invitationServiceProvider = Provider<InvitationService>((ref) {
  final pushNotificationService = ref.read(pushNotificationServiceProvider);
  return InvitationService(pushNotificationService);
});

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PushNotificationService _pushNotificationService;

  InvitationService(this._pushNotificationService);

  // Collection reference
  CollectionReference get _invitationsCollection => _firestore.collection('event_invitations');
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  // Get current user ID
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Check if a user has been invited to an event
  Future<bool> isUserInvited(String eventId, String userId) async {
    try {
      Logger.d('InvitationService', 'Checking if user $userId is invited to event $eventId');

      // Query for invitations for this user and event
      final querySnapshot = await _invitationsCollection
          .where('eventId', isEqualTo: eventId)
          .where('inviteeId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      Logger.e('InvitationService', 'Error checking invitation status', e);
      return false;
    }
  }

  // Send an invitation to a user for an event
  Future<String> sendInvitation(String eventId, String inviteeId) async {
    try {
      Logger.d('InvitationService', 'Sending invitation for event: $eventId to user: $inviteeId');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('InvitationService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Check if invitation already exists
      final existingQuery = await _invitationsCollection
          .where('eventId', isEqualTo: eventId)
          .where('inviteeId', isEqualTo: inviteeId)
          .where('inviterId', isEqualTo: _currentUserId)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        Logger.d('InvitationService', 'Invitation already exists');
        return existingQuery.docs.first.id;
      }

      // Create the invitation
      final invitation = EventInvitationModel(
        eventId: eventId,
        inviterId: _currentUserId,
        inviteeId: inviteeId,
      );

      // Add to Firestore
      final docRef = await _invitationsCollection.add(invitation.toMap());
      Logger.d('InvitationService', 'Invitation created with ID: ${docRef.id}');

      // Get event details
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      final eventData = eventDoc.data() as Map<String, dynamic>?;
      final eventInquiry = eventData?['inquiry'] ?? 'an event';
      final eventModel = EventModel.fromFirestore(eventDoc);

      // Create a notification for the invitee
      final notification = NotificationModel(
        userId: inviteeId, // Send to invitee
        senderId: _currentUserId, // From current user
        eventId: eventId,
        type: NotificationType.joinRequest, // Reusing join request type for now
        status: NotificationStatus.pending,
        message: 'invited you to join their event',
      );

      // Add notification to Firestore
      final notificationRef = await _notificationsCollection.add(notification.toMap());
      Logger.d('InvitationService', 'Notification created with ID: ${notificationRef.id}');

      // Send push notification to invitee
      try {
        // Get the inviter's display name
        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] ?? 'Someone';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: inviteeId,
          title: 'New Event Invitation',
          body: '$displayName invited you to join: $eventInquiry',
          data: {
            'type': 'event_invitation',
            'eventId': eventId,
            'invitationId': docRef.id,
            'notificationId': notificationRef.id,
            'senderId': _currentUserId,
          },
        );

        Logger.d('InvitationService', 'Push notification sent to invitee');
      } catch (e) {
        Logger.e('InvitationService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }

      return docRef.id;
    } catch (e) {
      Logger.e('InvitationService', 'Error sending invitation', e);
      rethrow;
    }
  }

  // Accept an invitation
  Future<void> acceptInvitation(String invitationId) async {
    try {
      Logger.d('InvitationService', 'Accepting invitation: $invitationId');

      // Get the invitation
      final docSnapshot = await _invitationsCollection.doc(invitationId).get();
      if (!docSnapshot.exists) {
        Logger.e('InvitationService', 'Invitation not found: $invitationId');
        throw Exception('Invitation not found');
      }

      final invitation = EventInvitationModel.fromFirestore(docSnapshot);

      // Update the invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add user to event's joinedBy array
      await _firestore.collection('events').doc(invitation.eventId).update({
        'joinedBy': FieldValue.arrayUnion([_currentUserId])
      });

      Logger.d('InvitationService', 'Invitation accepted and user added to event');

      // Create a notification for the inviter
      final acceptedNotification = NotificationModel(
        userId: invitation.inviterId, // Send to inviter
        senderId: _currentUserId, // From current user
        eventId: invitation.eventId,
        type: NotificationType.joinAccepted,
        status: NotificationStatus.read,
        message: 'accepted your invitation to join the event',
      );

      final acceptedNotificationRef = await _notificationsCollection.add(acceptedNotification.toMap());

      // Send push notification to inviter
      try {
        // Get the invitee's display name
        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] ?? 'Someone';

        // Get event details
        final eventDoc = await _firestore.collection('events').doc(invitation.eventId).get();
        final eventData = eventDoc.data() as Map<String, dynamic>?;
        final eventInquiry = eventData?['inquiry'] ?? 'your event';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: invitation.inviterId,
          title: 'Invitation Accepted',
          body: '$displayName accepted your invitation to join "$eventInquiry"',
          data: {
            'type': 'invitation_accepted',
            'eventId': invitation.eventId,
            'notificationId': acceptedNotificationRef.id,
          },
        );

        Logger.d('InvitationService', 'Push notification sent to inviter');
      } catch (e) {
        Logger.e('InvitationService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }
    } catch (e) {
      Logger.e('InvitationService', 'Error accepting invitation', e);
      rethrow;
    }
  }

  // Decline an invitation
  Future<void> declineInvitation(String invitationId) async {
    try {
      Logger.d('InvitationService', 'Declining invitation: $invitationId');

      // Get the invitation
      final docSnapshot = await _invitationsCollection.doc(invitationId).get();
      if (!docSnapshot.exists) {
        Logger.e('InvitationService', 'Invitation not found: $invitationId');
        throw Exception('Invitation not found');
      }

      final invitation = EventInvitationModel.fromFirestore(docSnapshot);

      // Update the invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      Logger.d('InvitationService', 'Invitation declined');

      // Create a notification for the inviter
      final declinedNotification = NotificationModel(
        userId: invitation.inviterId, // Send to inviter
        senderId: _currentUserId, // From current user
        eventId: invitation.eventId,
        type: NotificationType.joinRejected,
        status: NotificationStatus.read,
        message: 'declined your invitation to join the event',
      );

      final declinedNotificationRef = await _notificationsCollection.add(declinedNotification.toMap());

      // Send push notification to inviter
      try {
        // Get the invitee's display name
        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] ?? 'Someone';

        // Get event details
        final eventDoc = await _firestore.collection('events').doc(invitation.eventId).get();
        final eventData = eventDoc.data() as Map<String, dynamic>?;
        final eventInquiry = eventData?['inquiry'] ?? 'your event';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: invitation.inviterId,
          title: 'Invitation Declined',
          body: '$displayName declined your invitation to join "$eventInquiry"',
          data: {
            'type': 'invitation_declined',
            'eventId': invitation.eventId,
            'notificationId': declinedNotificationRef.id,
          },
        );

        Logger.d('InvitationService', 'Push notification sent to inviter');
      } catch (e) {
        Logger.e('InvitationService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }
    } catch (e) {
      Logger.e('InvitationService', 'Error declining invitation', e);
      rethrow;
    }
  }

  // Get invitations for the current user
  Stream<List<EventInvitationModel>> getInvitations() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    return _invitationsCollection
        .where('inviteeId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventInvitationModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get invitations sent by the current user
  Stream<List<EventInvitationModel>> getSentInvitations() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    return _invitationsCollection
        .where('inviterId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventInvitationModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get invitations for a specific event
  Stream<List<EventInvitationModel>> getEventInvitations(String eventId) {
    return _invitationsCollection
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventInvitationModel.fromFirestore(doc))
          .toList();
    });
  }
}
