import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String? imageUrl;
  final String? replyToId; // ID of the message being replied to
  final String? replyToSenderName; // Name of the sender of the replied message
  final String? replyToMessage; // Content of the replied message
  final bool isEdited; // Whether the message has been edited
  final DateTime? editedAt; // When the message was last edited

  ChatMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.message,
    DateTime? timestamp,
    this.imageUrl,
    this.replyToId,
    this.replyToSenderName,
    this.replyToMessage,
    this.isEdited = false,
    this.editedAt,
  }) : timestamp = timestamp ?? DateTime.now();

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToMessage': replyToMessage,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }

  // Create a ChatMessage from a Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp timestamp = data['timestamp'] as Timestamp;

    // Handle editedAt timestamp if it exists
    DateTime? editedAt;
    if (data['editedAt'] != null) {
      editedAt = (data['editedAt'] as Timestamp).toDate();
    }

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] as String,
      message: data['message'] as String,
      timestamp: timestamp.toDate(),
      imageUrl: data['imageUrl'] as String?,
      replyToId: data['replyToId'] as String?,
      replyToSenderName: data['replyToSenderName'] as String?,
      replyToMessage: data['replyToMessage'] as String?,
      isEdited: data['isEdited'] as bool? ?? false,
      editedAt: editedAt,
    );
  }
}
