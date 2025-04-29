# RSVPModel Documentation

## Overview

The `RSVPModel` represents an invitation to an event and the recipient's response. It is used to track event invitations and their status throughout the application. This model replaces the older `EventInvitationModel` with a more robust implementation.

## Structure

```dart
class RSVPModel {
  final String id;
  final String eventId;
  final String inviterId; // User who sent the invitation
  final String inviteeId; // User who received the invitation
  final String status;    // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? respondedAt;
  
  // Constructor and methods...
}
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier for the RSVP |
| `eventId` | String | ID of the event this RSVP is for |
| `inviterId` | String | User ID of the person who sent the invitation |
| `inviteeId` | String | User ID of the person who received the invitation |
| `status` | String | Current status: 'pending', 'accepted', or 'declined' |
| `createdAt` | DateTime | When the invitation was created |
| `respondedAt` | DateTime? | When the invitation was responded to (null if pending) |

## Constructor

```dart
RSVPModel({
  this.id = '',
  required this.eventId,
  required this.inviterId,
  required this.inviteeId,
  this.status = 'pending',
  DateTime? createdAt,
  this.respondedAt,
}) : createdAt = createdAt ?? DateTime.now();
```

## Methods

### toMap

Converts the model to a map for Firestore storage:

```dart
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
```

### fromFirestore

Creates an RSVPModel from a Firestore document:

```dart
factory RSVPModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final Timestamp createdTimestamp = data['createdAt'] as Timestamp;
  
  DateTime? respondedAt;
  if (data['respondedAt'] != null) {
    respondedAt = (data['respondedAt'] as Timestamp).toDate();
  }

  return RSVPModel(
    id: doc.id,
    eventId: data['eventId'] as String,
    inviterId: data['inviterId'] as String,
    inviteeId: data['inviteeId'] as String,
    status: data['status'] as String,
    createdAt: createdTimestamp.toDate(),
    respondedAt: respondedAt,
  );
}
```

### copyWith

Creates a copy of the RSVP with updated fields:

```dart
RSVPModel copyWith({
  String? id,
  String? eventId,
  String? inviterId,
  String? inviteeId,
  String? status,
  DateTime? createdAt,
  DateTime? respondedAt,
}) {
  return RSVPModel(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    inviterId: inviterId ?? this.inviterId,
    inviteeId: inviteeId ?? this.inviteeId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    respondedAt: respondedAt ?? this.respondedAt,
  );
}
```

## Usage

### Creating a New RSVP

```dart
final rsvp = RSVPModel(
  eventId: 'event123',
  inviterId: currentUserId,
  inviteeId: friendUserId,
  status: 'pending',
);

// Convert to map for Firestore
final rsvpData = rsvp.toMap();
```

### Reading from Firestore

```dart
// Get RSVP document from Firestore
final docSnapshot = await firestore.collection('rsvp').doc(rsvpId).get();

// Convert to RSVPModel
final rsvp = RSVPModel.fromFirestore(docSnapshot);
```

### Updating Status

```dart
// Create a copy with updated status
final updatedRSVP = rsvp.copyWith(
  status: 'accepted',
  respondedAt: DateTime.now(),
);

// Convert to map for Firestore update
final updatedData = updatedRSVP.toMap();
```

## Integration with Other Models

The RSVPModel works closely with:

- **EventModel**: References the event being invited to
- **NotificationModel**: Creates notifications for invitations and responses
- **UserModel**: References the inviter and invitee

## Firestore Storage

RSVPs are stored in the `rsvp` collection in Firestore with the following structure:

```json
{
  "eventId": "event123",
  "inviterId": "user456",
  "inviteeId": "user789",
  "status": "pending",
  "createdAt": Timestamp,
  "respondedAt": Timestamp (optional)
}
```

## Security Considerations

- Only the inviter can create RSVPs
- Only the invitee can update the status (accept/decline)
- Both inviter and invitee can read the RSVP
- Only the inviter can delete the RSVP
