# RSVP System Implementation Guide

## Overview

The RSVP system in Yetu'ga provides a robust way to manage event invitations and responses. This guide explains how the system works, the recent improvements made, and best practices for using it.

## Key Components

The RSVP system consists of the following key components:

1. **RSVPModel**: Data model for event invitations and responses
2. **RSVPService**: Service for managing RSVPs
3. **NotificationService**: Integration for sending notifications
4. **BatchService**: For efficient batch operations with RSVPs
5. **Firestore Rules**: Security rules for RSVP operations

## Recent Improvements

The RSVP system has been enhanced with the following improvements:

1. **Replaced EventInvitationModel**: The older EventInvitationModel has been replaced with the more robust RSVPModel
2. **Improved Notification Integration**: Better integration with the notification system
3. **Enhanced Security Rules**: Updated Firestore rules to properly handle RSVP operations
4. **Fixed Permission Issues**: Resolved permission denied errors for invited users joining events
5. **Streamlined API**: Cleaner and more consistent API for working with RSVPs

## Firestore Collections

The RSVP system uses the following Firestore collections:

1. **rsvp**: Stores RSVP documents with invitation and response data
2. **notifications**: Stores notifications related to RSVPs
3. **events**: Updated to work with the RSVP system for joining events

## Firestore Rules

The RSVP system uses the following Firestore security rules:

### RSVP Collection Rules

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

### Notification Rules for RSVPs

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

### Declining an Invitation

```dart
final rsvpService = ref.read(rsvpServiceProvider);
await rsvpService.declineInvitation(rsvpId);
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

### Inviting Multiple Users

```dart
final batchService = ref.read(batchServiceProvider);
await batchService.createInvitationsInBatch(eventId, inviteeIds, currentUserId);
```

## Workflow for Private Events

1. **Create Private Event**: Set `isPrivate` to true when creating an event
2. **Select Invitees**: Use the InviteFollowersDialog to select users to invite
3. **Send Invitations**: Create RSVPs for all selected users
4. **Notification**: Invitees receive notifications about the invitation
5. **Accept/Decline**: Invitees can accept or decline the invitation
6. **Auto-Join**: When an invited user accepts, they are automatically added to the event

## Workflow for Public Events with Invitations

1. **Create Public Event**: Set `isPrivate` to false when creating an event
2. **Optional Invitations**: Optionally invite specific users
3. **Join Requests**: Non-invited users can request to join
4. **Approval Process**: Event creator approves or rejects join requests
5. **Invited Users**: Invited users can join without requiring approval

## Best Practices

1. **Use RSVPService**: Always use the RSVPService for managing invitations
2. **Batch Operations**: Use BatchService for inviting multiple users
3. **Check Invitation Status**: Always check if a user is invited before auto-joining
4. **Handle Notifications**: Properly handle notifications for all RSVP actions
5. **Error Handling**: Implement proper error handling for RSVP operations

## Troubleshooting

### Permission Denied Errors

If you encounter permission denied errors when joining events as an invited user:

1. **Check Firestore Rules**: Ensure the rules allow creating notifications for invited users
2. **Verify Notification Creation**: Make sure notifications are being created correctly
3. **Check User Authentication**: Ensure the user is properly authenticated
4. **Verify RSVP Status**: Check if the RSVP exists and has the correct status

### Missing Invitations

If invitations are not appearing for users:

1. **Check RSVP Creation**: Verify RSVPs are being created correctly
2. **Check Notification Creation**: Ensure notifications are being created
3. **Verify Query Filters**: Make sure the queries for retrieving RSVPs are correct
4. **Check Security Rules**: Ensure the security rules allow reading RSVPs

## Migration from EventInvitationService

The RSVPService replaces the older EventInvitationService. If you're migrating from the old system:

1. **Replace Model References**: Use RSVPModel instead of EventInvitationModel
2. **Update Service References**: Use RSVPService instead of InvitationService
3. **Update Collection References**: Use 'rsvp' collection instead of 'event_invitations'
4. **Update Method Calls**: Use the equivalent methods in RSVPService
5. **Update Security Rules**: Use the new security rules for the RSVP collection
