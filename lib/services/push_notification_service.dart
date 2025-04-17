import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

// Provider for the PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService());

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        // TODO: Navigate to the appropriate screen based on the notification
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
      // Get the user's FCM tokens
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        Logger.e('PushNotificationService', 'User not found: $userId');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) return;

      final fcmTokens = List<String>.from(userData['fcmTokens'] ?? []);
      if (fcmTokens.isEmpty) {
        Logger.e('PushNotificationService', 'No FCM tokens found for user: $userId');
        return;
      }

      // Create a notification document in Firestore
      // This will trigger a Cloud Function to send the actual notification
      await _firestore.collection('notifications_queue').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'tokens': fcmTokens,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      Logger.d('PushNotificationService', 'Notification queued for user: $userId');
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
