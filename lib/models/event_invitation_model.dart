import 'package:cloud_firestore/cloud_firestore.dart';

class EventInvitationModel {
  final String id;
  final String eventId;
  final String inviterId; // User who sent the invitation
  final String inviteeId; // User who received the invitation
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? respondedAt;

  EventInvitationModel({
    this.id = '',
    required this.eventId,
    required this.inviterId,
    required this.inviteeId,
    this.status = 'pending',
    DateTime? createdAt,
    this.respondedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    final map = {
      'eventId': eventId,
      'inviterId': inviterId,
      'inviteeId': inviteeId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (respondedAt != null) {
      map['respondedAt'] = Timestamp.fromDate(respondedAt!);
    }

    return map;
  }

  // Create an EventInvitationModel from a Firestore document
  factory EventInvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp createdTimestamp = data['createdAt'] as Timestamp;
    
    DateTime? respondedAt;
    if (data['respondedAt'] != null) {
      respondedAt = (data['respondedAt'] as Timestamp).toDate();
    }

    return EventInvitationModel(
      id: doc.id,
      eventId: data['eventId'] as String,
      inviterId: data['inviterId'] as String,
      inviteeId: data['inviteeId'] as String,
      status: data['status'] as String,
      createdAt: createdTimestamp.toDate(),
      respondedAt: respondedAt,
    );
  }

  // Create a copy of the invitation with updated fields
  EventInvitationModel copyWith({
    String? id,
    String? eventId,
    String? inviterId,
    String? inviteeId,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return EventInvitationModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      inviterId: inviterId ?? this.inviterId,
      inviteeId: inviteeId ?? this.inviteeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}
