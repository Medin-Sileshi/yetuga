import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../models/event_model.dart';
import '../services/push_notification_service.dart';
import '../utils/logger.dart';

// Provider for the NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final pushNotificationService = ref.read(pushNotificationServiceProvider);
  return NotificationService(pushNotificationService);
});

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PushNotificationService _pushNotificationService;

  NotificationService(this._pushNotificationService);

  // Collection reference
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  // Get current user ID
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Create a join request notification
  Future<String> createJoinRequest(EventModel event) async {
    try {
      Logger.d('NotificationService', 'Creating join request for event: ${event.id}');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('NotificationService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Create the notification
      final notification = NotificationModel(
        userId: event.userId, // Send to event creator
        senderId: _currentUserId, // From current user
        eventId: event.id,
        type: NotificationType.joinRequest,
        status: NotificationStatus.pending,
        message: 'wants to join your event',
      );

      // Add to Firestore
      final docRef = await _notificationsCollection.add(notification.toMap());
      Logger.d('NotificationService', 'Join request created with ID: ${docRef.id}');

      // Send push notification to event creator
      try {
        // Get the event creator's display name
        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] ?? 'Someone';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: event.userId,
          title: 'New Join Request',
          body: '$displayName wants to join your event: ${event.inquiry}',
          data: {
            'type': 'join_request',
            'eventId': event.id,
            'notificationId': docRef.id,
            'senderId': _currentUserId,
          },
        );

        Logger.d('NotificationService', 'Push notification sent to event creator');
      } catch (e) {
        Logger.e('NotificationService', 'Error sending push notification', e);
        // Continue even if push notification fails
      }

      return docRef.id;
    } catch (e) {
      Logger.e('NotificationService', 'Error creating join request', e);
      rethrow;
    }
  }

  // Get notifications for the current user
  Stream<List<NotificationModel>> getNotifications() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    // Query with index on userId + createdAt
    return _notificationsCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get pending join requests for an event
  Stream<List<NotificationModel>> getPendingJoinRequests(String eventId) {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    // Simplified query to avoid complex index requirements
    return _notificationsCollection
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
      // Filter in memory
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['type'] == NotificationType.joinRequest.toString().split('.').last &&
               data['status'] == NotificationStatus.pending.toString().split('.').last;
      });

      // Convert to models and sort by createdAt
      final models = filteredDocs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();

      // Sort by createdAt descending
      models.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return models;
    });
  }

  // Check if user has a pending join request for an event
  Future<bool> hasPendingJoinRequest(String eventId) async {
    if (_currentUserId.isEmpty) {
      return false;
    }

    // Simplified query to avoid complex index requirements
    final querySnapshot = await _notificationsCollection
        .where('eventId', isEqualTo: eventId)
        .where('senderId', isEqualTo: _currentUserId)
        .get();

    // Filter in memory
    return querySnapshot.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['type'] == NotificationType.joinRequest.toString().split('.').last &&
             data['status'] == NotificationStatus.pending.toString().split('.').last;
    });
  }

  // Check if user has a rejected join request for an event
  Future<bool> hasRejectedJoinRequest(String eventId) async {
    if (_currentUserId.isEmpty) {
      return false;
    }

    // Simplified query to avoid complex index requirements
    final querySnapshot = await _notificationsCollection
        .where('eventId', isEqualTo: eventId)
        .where('senderId', isEqualTo: _currentUserId)
        .get();

    // Filter in memory
    return querySnapshot.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['type'] == NotificationType.joinRequest.toString().split('.').last &&
             data['status'] == NotificationStatus.rejected.toString().split('.').last;
    });
  }

  // Accept a join request
  Future<void> acceptJoinRequest(String notificationId, String eventId) async {
    try {
      Logger.d('NotificationService', 'Accepting join request: $notificationId');

      // Get the notification
      final docSnapshot = await _notificationsCollection.doc(notificationId).get();
      if (!docSnapshot.exists) {
        Logger.e('NotificationService', 'Notification not found: $notificationId');
        throw Exception('Notification not found');
      }

      final notification = NotificationModel.fromFirestore(docSnapshot);

      // Update the notification status
      await _notificationsCollection.doc(notificationId).update({
        'status': NotificationStatus.accepted.toString().split('.').last,
      });

      // Create a notification for the requester
      final acceptedNotification = NotificationModel(
        userId: notification.senderId, // Send to the requester
        senderId: _currentUserId, // From current user (event creator)
        eventId: eventId,
        type: NotificationType.joinAccepted,
        status: NotificationStatus.read,
        message: 'Your request to join the event has been accepted',
      );

      final acceptedNotificationRef = await _notificationsCollection.add(acceptedNotification.toMap());

      // Send push notification to the requester
      try {
        // Get the event details
        final eventDoc = await _firestore.collection('events').doc(eventId).get();
        final eventData = eventDoc.data() as Map<String, dynamic>?;
        final eventInquiry = eventData?['inquiry'] ?? 'an event';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: notification.senderId,
          title: 'Join Request Accepted',
          body: 'Your request to join "$eventInquiry" has been accepted!',
          data: {
            'type': 'join_accepted',
            'eventId': eventId,
            'notificationId': acceptedNotificationRef.id,
          },
        );

        Logger.d('NotificationService', 'Push notification sent to requester for accepted join request');
      } catch (e) {
        Logger.e('NotificationService', 'Error sending push notification for accepted join request', e);
        // Continue even if push notification fails
      }

      // Add the user to the event's joinedBy list
      final eventRef = _firestore.collection('events').doc(eventId);
      await eventRef.update({
        'joinedBy': FieldValue.arrayUnion([notification.senderId])
      });

      Logger.d('NotificationService', 'Join request accepted successfully');
    } catch (e) {
      Logger.e('NotificationService', 'Error accepting join request', e);
      rethrow;
    }
  }

  // Reject a join request
  Future<void> rejectJoinRequest(String notificationId, String eventId) async {
    try {
      Logger.d('NotificationService', 'Rejecting join request: $notificationId');

      // Get the notification
      final docSnapshot = await _notificationsCollection.doc(notificationId).get();
      if (!docSnapshot.exists) {
        Logger.e('NotificationService', 'Notification not found: $notificationId');
        throw Exception('Notification not found');
      }

      final notification = NotificationModel.fromFirestore(docSnapshot);

      // Update the notification status
      await _notificationsCollection.doc(notificationId).update({
        'status': NotificationStatus.rejected.toString().split('.').last,
      });

      // Create a notification for the requester
      final rejectedNotification = NotificationModel(
        userId: notification.senderId, // Send to the requester
        senderId: _currentUserId, // From current user (event creator)
        eventId: eventId,
        type: NotificationType.joinRejected,
        status: NotificationStatus.read,
        message: 'Your request to join the event has been rejected',
      );

      final rejectedNotificationRef = await _notificationsCollection.add(rejectedNotification.toMap());

      // Send push notification to the requester
      try {
        // Get the event details
        final eventDoc = await _firestore.collection('events').doc(eventId).get();
        final eventData = eventDoc.data() as Map<String, dynamic>?;
        final eventInquiry = eventData?['inquiry'] ?? 'an event';

        // Send push notification
        await _pushNotificationService.sendNotification(
          userId: notification.senderId,
          title: 'Join Request Rejected',
          body: 'Your request to join "$eventInquiry" has been rejected.',
          data: {
            'type': 'join_rejected',
            'eventId': eventId,
            'notificationId': rejectedNotificationRef.id,
          },
        );

        Logger.d('NotificationService', 'Push notification sent to requester for rejected join request');
      } catch (e) {
        Logger.e('NotificationService', 'Error sending push notification for rejected join request', e);
        // Continue even if push notification fails
      }

      Logger.d('NotificationService', 'Join request rejected successfully');
    } catch (e) {
      Logger.e('NotificationService', 'Error rejecting join request', e);
      rethrow;
    }
  }

  // Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      Logger.d('NotificationService', 'Marking notification as read: $notificationId');

      await _notificationsCollection.doc(notificationId).update({
        'status': NotificationStatus.read.toString().split('.').last,
      });

      Logger.d('NotificationService', 'Notification marked as read successfully');
    } catch (e) {
      Logger.e('NotificationService', 'Error marking notification as read', e);
      rethrow;
    }
  }

  // Mark multiple notifications as read in a batch operation
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    try {
      Logger.d('NotificationService', 'Marking ${notificationIds.length} notifications as read');

      // Use a batch operation for better performance
      final batch = _firestore.batch();
      final readStatus = NotificationStatus.read.toString().split('.').last;

      // Add each notification update to the batch
      for (final id in notificationIds) {
        final docRef = _notificationsCollection.doc(id);
        batch.update(docRef, {'status': readStatus});
      }

      // Commit the batch
      await batch.commit();

      Logger.d('NotificationService', 'Successfully marked ${notificationIds.length} notifications as read');
    } catch (e) {
      Logger.e('NotificationService', 'Error marking multiple notifications as read', e);
      rethrow;
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      Logger.d('NotificationService', 'Deleting notification: $notificationId');

      // Get the notification before deleting it
      final docSnapshot = await _notificationsCollection.doc(notificationId).get();
      if (!docSnapshot.exists) {
        Logger.e('NotificationService', 'Notification not found: $notificationId');
        throw Exception('Notification not found');
      }

      // Delete the notification
      await _notificationsCollection.doc(notificationId).delete();

      Logger.d('NotificationService', 'Notification deleted successfully');
    } catch (e) {
      Logger.e('NotificationService', 'Error deleting notification', e);
      rethrow;
    }
  }

  // Get unread notification count
  Stream<int> getUnreadCount() {
    if (_currentUserId.isEmpty) {
      return Stream.value(0);
    }

    // Simplified query to avoid complex index requirements
    return _notificationsCollection
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final status = data != null ? data['status'] as String? : null;

              // Only count notifications that are NOT in the 'read' status
              return status != null &&
                     status != NotificationStatus.read.toString().split('.').last;
            })
            .length);
  }

  // Check for unread notifications and send push notifications for them
  Future<void> checkAndSendUnreadNotifications() async {
    try {
      Logger.d('NotificationService', 'Checking for unread notifications');

      if (_currentUserId.isEmpty) {
        Logger.e('NotificationService', 'User not authenticated');
        return;
      }

      // Get unread notifications
      final querySnapshot = await _notificationsCollection
          .where('userId', isEqualTo: _currentUserId)
          .get();

      // Filter unread notifications
      final unreadNotifications = querySnapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final status = data != null ? data['status'] as String? : null;

            // Only include notifications that are NOT in the 'read' status
            return status != null &&
                   status != NotificationStatus.read.toString().split('.').last;
          })
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();

      Logger.d('NotificationService', 'Found ${unreadNotifications.length} unread notifications');

      // Send push notifications for each unread notification
      for (final notification in unreadNotifications) {
        String title = 'New Notification';
        String body = 'You have a new notification';

        // Customize notification based on type
        switch (notification.type) {
          case NotificationType.joinRequest:
            title = 'New Join Request';
            body = 'Someone wants to join your event';
            break;
          case NotificationType.joinAccepted:
            title = 'Join Request Accepted';
            body = 'Your request to join an event has been accepted';
            break;
          case NotificationType.joinRejected:
            title = 'Join Request Rejected';
            body = 'Your request to join an event has been rejected';
            break;
          case NotificationType.eventCancelled:
            title = 'Event Cancelled';
            body = 'An event you joined has been cancelled';
            break;
          case NotificationType.eventUpdated:
            title = 'Event Updated';
            body = 'An event you joined has been updated';
            break;
        }

        // Get more details if available
        try {
          if (notification.eventId.isNotEmpty) {
            final eventDoc = await _firestore.collection('events').doc(notification.eventId).get();
            if (eventDoc.exists) {
              final eventData = eventDoc.data();
              if (eventData != null && eventData['inquiry'] != null) {
                final eventInquiry = eventData['inquiry'] as String;
                body = body.replaceAll('an event', '"$eventInquiry"');
              }
            }
          }

          if (notification.senderId.isNotEmpty && notification.type == NotificationType.joinRequest) {
            final userDoc = await _firestore.collection('users').doc(notification.senderId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              if (userData != null && userData['displayName'] != null) {
                final displayName = userData['displayName'] as String;
                body = '$displayName $body';
              }
            }
          }
        } catch (e) {
          Logger.e('NotificationService', 'Error getting additional notification details', e);
          // Continue with basic notification if there's an error
        }

        // Send the push notification
        await _pushNotificationService.sendNotification(
          userId: _currentUserId,
          title: title,
          body: body,
          data: {
            'notificationId': notification.id,
            'eventId': notification.eventId,
            'type': notification.type.toString().split('.').last,
          },
        );

        Logger.d('NotificationService', 'Sent push notification for notification: ${notification.id}');
      }

      Logger.d('NotificationService', 'Finished sending push notifications for unread notifications');
    } catch (e) {
      Logger.e('NotificationService', 'Error checking and sending unread notifications', e);
    }
  }
}
