import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String? imageUrl;

  ChatMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.message,
    DateTime? timestamp,
    this.imageUrl,
  }) : timestamp = timestamp ?? DateTime.now();

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
    };
  }

  // Create a ChatMessage from a Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp timestamp = data['timestamp'] as Timestamp;

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] as String,
      message: data['message'] as String,
      timestamp: timestamp.toDate(),
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
