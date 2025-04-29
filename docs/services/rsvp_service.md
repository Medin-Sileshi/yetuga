# RSVP Service Documentation

## Overview

The RSVPService is responsible for managing event invitations and responses in the Yetu'ga app. It replaces the older EventInvitationService with a more robust implementation that handles the full lifecycle of event invitations, from sending invites to accepting or declining them.

## Key Features

- **Send Invitations**: Invite users to events with automatic notification creation
- **Accept/Decline Invitations**: Allow invitees to respond to invitations
- **Auto-Join for Invited Users**: Automatically add invited users to events when they accept
- **Notification Integration**: Create and send notifications for all RSVP actions
- **Permission Handling**: Proper Firestore security rules for RSVP operations

## Data Model

The RSVP system uses the `RSVPModel` class with the following structure:

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

## Core Methods

### Send Invitation

```dart
Future<String> sendInvitation(String eventId, String inviteeId)
```

Sends an invitation to a user for a specific event:
- Creates an RSVP document in Firestore
- Creates a notification for the invitee
- Sends a push notification to the invitee
- Returns the RSVP document ID

### Accept Invitation

```dart
Future<void> acceptInvitation(String rsvpId)
```

Accepts an invitation:
- Updates the RSVP status to 'accepted'
- Adds the invitee to the event's joinedBy array
- Creates a notification for the inviter
- Sends a push notification to the inviter

### Decline Invitation

```dart
Future<void> declineInvitation(String rsvpId)
```

Declines an invitation:
- Updates the RSVP status to 'declined'
- Creates a notification for the inviter
- Sends a push notification to the inviter

### Check Invitation Status

```dart
Future<bool> isUserInvited(String eventId, String userId)
```

Checks if a user is invited to an event:
- Queries the RSVP collection for matching records
- Returns true if the user has been invited to the event

### Get RSVPs

```dart
Stream<List<RSVPModel>> getRSVPs()
```

Gets all RSVPs for the current user (as invitee):
- Returns a stream of RSVPModel objects
- Updates in real-time when new invitations are received

### Get Pending RSVPs

```dart
Stream<List<RSVPModel>> getPendingRSVPs()
```

Gets all pending RSVPs for the current user:
- Returns a stream of RSVPModel objects with 'pending' status
- Updates in real-time when new invitations are received

### Get Sent RSVPs

```dart
Stream<List<RSVPModel>> getSentRSVPs()
```

Gets all RSVPs sent by the current user (as inviter):
- Returns a stream of RSVPModel objects
- Updates in real-time when invitations are accepted or declined

## Integration with NotificationService

The RSVPService works closely with the NotificationService to:
- Create notifications for invitations
- Send push notifications to users
- Update notification status based on RSVP responses

## Firestore Rules

The RSVP system uses the following Firestore security rules:

```
match /rsvp/{rsvpId} {
  // Allow reading RSVPs where the user is the invitee or inviter
  allow read: if isAuthenticated() &&
    (resource.data.inviteeId == request.auth.uid || resource.data.inviterId == request.auth.uid);

  // Allow listing RSVPs for the current user
  allow list: if isAuthenticated() &&
    request.query.limit <= 100 &&
    ((request.query.filters[0].fieldPath == 'inviteeId' &&
      request.query.filters[0].op == '==' &&
      request.query.filters[0].value == request.auth.uid) ||
     (request.query.filters[0].fieldPath == 'inviterId' &&
      request.query.filters[0].op == '==' &&
      request.query.filters[0].value == request.auth.uid));

  // Allow creating RSVPs if the user is the inviter
  allow create: if isAuthenticated() &&
    request.resource.data.inviterId == request.auth.uid;

  // Allow updating RSVPs if the user is the invitee (to accept/decline)
  // or the inviter (to cancel)
  allow update: if isAuthenticated() &&
    (resource.data.inviteeId == request.auth.uid ||
     resource.data.inviterId == request.auth.uid);

  // Allow deleting RSVPs if the user is the inviter
  allow delete: if isAuthenticated() &&
    resource.data.inviterId == request.auth.uid;
}
```

## Notification Rules

For notifications related to RSVPs, the following rules apply:

```
// Allow creating notifications
// Modified to allow all notification types for authenticated users
allow create: if isAuthenticated() &&
  (
    // Either the sender is the current user
    request.resource.data.senderId == request.auth.uid ||
    // Or it's a notification for joining an event (for invited users)
    request.resource.data.type == 'joinAccepted' ||
    // Or it's an event invitation
    request.resource.data.type == 'eventInvitation'
  );
```

## Usage Examples

### Sending an Invitation

```dart
final rsvpService = ref.read(rsvpServiceProvider);
final rsvpId = await rsvpService.sendInvitation(eventId, inviteeId);
```

### Accepting an Invitation

```dart
final rsvpService = ref.read(rsvpServiceProvider);
await rsvpService.acceptInvitation(rsvpId);
```

### Checking if a User is Invited

```dart
final rsvpService = ref.read(rsvpServiceProvider);
final isInvited = await rsvpService.isUserInvited(eventId, userId);

if (isInvited) {
  // User is invited, allow auto-join
} else {
  // User is not invited, require approval
}
```

## Batch Operations

For inviting multiple users at once, the BatchService provides an efficient way to create RSVPs in batch:

```dart
final batchService = ref.read(batchServiceProvider);
await batchService.createInvitationsInBatch(eventId, inviteeIds, currentUserId);
```

## Migration from EventInvitationService

The RSVPService replaces the older EventInvitationService with a more robust implementation. The key differences are:

- More consistent naming (RSVP vs Invitation)
- Better integration with notifications
- Improved error handling and logging
- Support for batch operations
- Cleaner Firestore security rules

All references to the old EventInvitationService have been removed from the codebase.
