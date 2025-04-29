import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  joinRequest,
  joinAccepted,
  joinRejected,
  eventCancelled,
  eventUpdated,
  eventInvitation,
  invitationAccepted,
  invitationRejected,
}

enum NotificationStatus {
  pending,
  accepted,
  rejected,
  read,
}

class NotificationModel {
  final String id;
  final String userId; // User who will receive the notification
  final String senderId; // User who triggered the notification
  final String eventId; // Related event
  final NotificationType type;
  final NotificationStatus status;
  final DateTime createdAt;
  final String? message;

  NotificationModel({
    this.id = '',
    required this.userId,
    required this.senderId,
    required this.eventId,
    required this.type,
    required this.status,
    DateTime? createdAt,
    this.message,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'senderId': senderId,
      'eventId': eventId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'message': message,
    };
  }

  // Create a NotificationModel from a Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp timestamp = data['createdAt'] as Timestamp;

    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String,
      senderId: data['senderId'] as String,
      eventId: data['eventId'] as String,
      type: _stringToNotificationType(data['type'] as String),
      status: _stringToNotificationStatus(data['status'] as String),
      createdAt: timestamp.toDate(),
      message: data['message'] as String?,
    );
  }

  // Helper method to convert string to NotificationType
  static NotificationType _stringToNotificationType(String typeStr) {
    return NotificationType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => NotificationType.joinRequest,
    );
  }

  // Helper method to convert string to NotificationStatus
  static NotificationStatus _stringToNotificationStatus(String statusStr) {
    return NotificationStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => NotificationStatus.pending,
    );
  }

  // Create a copy of the notification with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? eventId,
    NotificationType? type,
    NotificationStatus? status,
    DateTime? createdAt,
    String? message,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      message: message ?? this.message,
    );
  }
}
