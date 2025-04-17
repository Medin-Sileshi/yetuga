import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  String _currentUserId = '';

  ChatService(this._firestore, this._auth) {
    _currentUserId = _auth.currentUser?.uid ?? '';
    _auth.authStateChanges().listen((User? user) {
      _currentUserId = user?.uid ?? '';
    });
  }

  // Get the current user ID
  String getCurrentUserId() {
    return _currentUserId;
  }

  // Get a reference to the chat collection for a specific event
  CollectionReference _getChatCollection(String eventId) {
    return _firestore.collection('events').doc(eventId).collection('chat');
  }

  // Send a message to the chat
  Future<void> sendMessage(String eventId, String message) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Get the current user's display name
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final displayName = userData?['displayName'] ?? 'Anonymous';

      // First check if the user can access this event
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final List<dynamic> joinedBy = eventData['joinedBy'] ?? [];

      // Check if user is the creator or has joined
      final bool isCreator = eventData['userId'] == _currentUserId;
      final bool hasJoined = joinedBy.contains(_currentUserId);

      if (!isCreator && !hasJoined) {
        Logger.d('ChatService', 'User $displayName ($_currentUserId) is not authorized to send messages to event $eventId');
        // We'll still try to send the message and let Firestore rules handle it
      }

      final chatMessage = ChatMessage(
        senderId: _currentUserId,
        senderName: displayName,
        message: message,
      );

      await _getChatCollection(eventId).add(chatMessage.toMap());
      Logger.d('ChatService', 'Message sent to event $eventId');
    } catch (e) {
      Logger.e('ChatService', 'Error sending message', e);
      rethrow;
    }
  }

  // Get all messages for a specific event
  Stream<List<ChatMessage>> getMessages(String eventId) {
    try {
      // First check if the user can access this chat
      return _getChatCollection(eventId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .handleError((error) {
            Logger.e('ChatService', 'Error getting messages: $error');
            // Return an empty list on error instead of propagating the error
            return [];
          })
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ChatMessage.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      Logger.e('ChatService', 'Error setting up message stream', e);
      return Stream.value([]);
    }
  }

  // Check if the current user can access the chat (is creator or has joined)
  Future<bool> canAccessChat(EventModel event) async {
    if (_currentUserId.isEmpty) {
      return false;
    }

    // User is the event creator
    if (event.userId == _currentUserId) {
      return true;
    }

    // User has joined the event
    if (event.joinedBy.contains(_currentUserId)) {
      return true;
    }

    return false;
  }
}

// Provider for the ChatService
final chatServiceProvider = Provider<ChatService>((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  return ChatService(firestore, auth);
});
