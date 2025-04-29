import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/notifications/join_requests_screen.dart';
import '../utils/logger.dart';
import 'global_navigation_service.dart';

// Provider for the PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService());

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalNavigationService _navigationService = GlobalNavigationService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      Logger.d('PushNotificationService', 'User granted permission: ${settings.authorizationStatus}');

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.d('PushNotificationService', 'Got a message whilst in the foreground!');
        Logger.d('PushNotificationService', 'Message data: ${message.data}');

        if (message.notification != null) {
          Logger.d('PushNotificationService', 'Message also contained a notification: ${message.notification}');
          // We're not showing local notifications anymore, just log it
        }
      });

      // Handle notification click when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        Logger.d('PushNotificationService', 'A notification was clicked when the app was in the background!');
        Logger.d('PushNotificationService', 'Message data: ${message.data}');

        // Navigate to the appropriate screen based on the notification
        _handleNotificationNavigation(message.data);
      });

      // Also handle initial notification when app is launched from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          Logger.d('PushNotificationService', 'App launched from notification!');
          Logger.d('PushNotificationService', 'Initial message data: ${message.data}');

          // Add a delay to ensure the app is fully initialized
          Future.delayed(const Duration(seconds: 1), () {
            _handleNotificationNavigation(message.data);
          });
        }
      });

      // Save the FCM token to Firestore
      await _saveFcmToken();

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _saveFcmToken(token: token);
      });
    } catch (e) {
      Logger.e('PushNotificationService', 'Error initializing push notifications', e);
    }
  }

  // Handle navigation based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      Logger.d('PushNotificationService', 'Handling notification navigation with data: $data');

      // Extract notification type
      final notificationType = data['type'];
      if (notificationType == null) {
        Logger.e('PushNotificationService', 'Notification type is missing');
        return;
      }

      // Navigate based on notification type
      switch (notificationType) {
        case 'join_request':
          // Navigate to join requests screen
          final eventId = data['eventId'];
          if (eventId != null) {
            _navigationService.navigateToRoute(JoinRequestsScreen(eventId: eventId));
          }
          break;

        case 'join_accepted':
        case 'join_rejected':
        case 'event_invitation':
        case 'event_updated':
        case 'event_cancelled':
          // Get the event and navigate to chat room instead of event details
          final eventId = data['eventId'];
          if (eventId != null) {
            // We need to get the event first
            _firestore.collection('events').doc(eventId).get().then((doc) {
              if (doc.exists) {
                final event = EventModel.fromFirestore(doc);
                _navigationService.navigateToRoute(ChatRoomScreen(event: event));
              }
            });
          }
          break;

        case 'new_message':
          // Navigate to chat room
          final eventId = data['eventId'];
          if (eventId != null) {
            // We need to get the event first
            _firestore.collection('events').doc(eventId).get().then((doc) {
              if (doc.exists) {
                final event = EventModel.fromFirestore(doc);
                _navigationService.navigateToRoute(ChatRoomScreen(event: event));
              }
            });
          }
          break;

        default:
          Logger.d('PushNotificationService', 'Unknown notification type: $notificationType');
          break;
      }
    } catch (e) {
      Logger.e('PushNotificationService', 'Error handling notification navigation', e);
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFcmToken({String? token}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      token ??= await _firebaseMessaging.getToken();
      if (token == null) return;

      Logger.d('PushNotificationService', 'FCM Token: $token');

      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      Logger.d('PushNotificationService', 'FCM token saved to Firestore');
    } catch (e) {
      Logger.e('PushNotificationService', 'Error saving FCM token', e);
    }
  }

  // Send a notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      Logger.d('PushNotificationService', 'Sending notification to user: $userId');
      Logger.d('PushNotificationService', 'Title: $title');
      Logger.d('PushNotificationService', 'Body: $body');
      Logger.d('PushNotificationService', 'Data: $data');

      // Get the user's FCM tokens
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        Logger.e('PushNotificationService', 'User not found: $userId');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
        Logger.e('PushNotificationService', 'User data is null for user: $userId');
        return;
      }

      final fcmTokens = List<String>.from(userData['fcmTokens'] ?? []);
      Logger.d('PushNotificationService', 'Found ${fcmTokens.length} FCM tokens for user: $userId');

      if (fcmTokens.isEmpty) {
        Logger.e('PushNotificationService', 'No FCM tokens found for user: $userId');
        return;
      }

      // Create a notification document in Firestore
      // This is for record-keeping and to ensure the notification appears in the app
      final notificationData = {
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'tokens': fcmTokens,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': true, // Mark as sent immediately
      };

      Logger.d('PushNotificationService', 'Creating notification record');

      final docRef = await _firestore.collection('notifications_queue').add(notificationData);
      Logger.d('PushNotificationService', 'Notification record created with ID: ${docRef.id}');

      // IMPORTANT: Since we don't have a Cloud Function to process the queue,
      // we need to ensure that the notification is also created in the notifications collection
      // so it appears in the app's notification screen
      if (data != null && data['notificationId'] == null) {
        // Only create a notification if one doesn't already exist
        // (i.e., if we're not sending a push for an existing notification)
        try {
          final notificationRef = await _firestore.collection('notifications').add({
            'userId': userId,
            'senderId': _auth.currentUser?.uid ?? '',
            'eventId': data['eventId'] ?? '',
            'type': data['type'] ?? 'general',
            'status': 'pending',
            'message': body,
            'createdAt': FieldValue.serverTimestamp(),
          });

          Logger.d('PushNotificationService', 'Created notification record: ${notificationRef.id}');
        } catch (e) {
          Logger.e('PushNotificationService', 'Error creating notification record', e);
        }
      }
    } catch (e) {
      Logger.e('PushNotificationService', 'Error sending notification', e);
    }
  }
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to ensure Firebase is initialized here as well
  Logger.d('PushNotificationService', 'Handling a background message: ${message.messageId}');

  // You can't show UI (like notifications) in the background handler
  // But you can process the data
}
