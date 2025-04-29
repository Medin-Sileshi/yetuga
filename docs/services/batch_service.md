# BatchService Documentation

## Overview

The `BatchService` provides efficient batch operations for Firestore in the Yetu'ga application. It handles the complexities of batching multiple database operations, respecting Firestore's limitations, and ensuring atomic updates where possible.

## Features

- **Efficient Batch Operations**: Perform multiple Firestore operations in a single transaction
- **Automatic Batch Splitting**: Handles Firestore's 500-operation limit by splitting into multiple batches
- **Specialized Batch Methods**: Purpose-built methods for common batch operations
- **Error Handling**: Comprehensive error handling and logging
- **Atomic Updates**: Ensures operations within a batch are atomic (all succeed or all fail)

## Usage

### Updating Multiple Events

```dart
final events = [event1, event2, event3]; // List of EventModel objects
await batchService.updateEvents(events);
```

### Toggling Likes for Multiple Events

```dart
final eventLikes = {
  'event1': true,   // Add like
  'event2': false,  // Remove like
  'event3': true    // Add like
};
await batchService.toggleLikesInBatch(eventLikes, currentUserId);
```

### Deleting Multiple Events

```dart
final eventIds = ['event1', 'event2', 'event3'];
await batchService.deleteEventsInBatch(eventIds);
```

### Creating Multiple RSVPs

```dart
final inviteeIds = ['user1', 'user2', 'user3'];
await batchService.createInvitationsInBatch(eventId, inviteeIds, currentUserId);
```

## Implementation Details

### Batch Size Limitation

Firestore has a limit of 500 operations per batch. The BatchService handles this by automatically splitting operations into multiple batches:

```dart
static const int _maxBatchSize = 500;

// Split into smaller batches if needed
final batches = <List<EventModel>>[];
for (var i = 0; i < events.length; i += _maxBatchSize) {
  final end = (i + _maxBatchSize < events.length) ? i + _maxBatchSize : events.length;
  batches.add(events.sublist(i, end));
}
```

### Batch Commit Process

Each batch is processed and committed separately:

```dart
// Process each batch
for (final batchEvents in batches) {
  final batch = _firestore.batch();

  for (final event in batchEvents) {
    final docRef = _firestore.collection('events').doc(event.id);
    batch.update(docRef, event.toMap());
  }

  await batch.commit();
  Logger.d('BatchService', 'Committed batch of ${batchEvents.length} events');
}
```

### RSVP Creation with Notifications

The service creates both RSVPs and notifications in a single batch operation:

```dart
// Create RSVP document
final rsvpRef = _firestore.collection('rsvp').doc();
final rsvpData = {
  'eventId': eventId,
  'inviterId': inviterId,
  'inviteeId': inviteeId,
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
};
batch.set(rsvpRef, rsvpData);

// Create notification document
final notificationRef = _firestore.collection('notifications').doc();
final notificationData = {
  'userId': inviteeId,
  'senderId': inviterId,
  'eventId': eventId,
  'type': 'eventInvitation',
  'status': 'pending',
  'message': '$displayName invited you to join "$eventInquiry"',
  'createdAt': FieldValue.serverTimestamp(),
};
batch.set(notificationRef, notificationData);
```

## Integration with RetryService

For improved reliability, the BatchService can be combined with the RetryService:

```dart
Future<void> updateEventsWithRetry(List<EventModel> events) async {
  await retryService.executeWithRetry<void>(
    operation: () async {
      await updateEvents(events);
    },
    maxRetries: 3,
    shouldRetry: retryService.isFirestoreRetryableError,
    operationName: 'batchUpdateEvents',
  );
}
```

## Best Practices

1. **Group Related Operations**: Batch operations that are logically related
2. **Consider Transaction Size**: Be mindful of the number of operations in a batch
3. **Handle Errors Appropriately**: Implement proper error handling for batch operations
4. **Use with RetryService**: Combine with RetryService for improved reliability
5. **Monitor Performance**: Large batches may impact performance

## Performance Considerations

- **Reduced Network Requests**: Batch operations reduce the number of network requests
- **Atomic Updates**: Operations within a batch are atomic (all succeed or all fail)
- **Firestore Quotas**: Batch operations count as individual operations for Firestore quotas
- **Client Memory**: Large batches may consume significant client memory

## Limitations

- **Maximum 500 Operations**: Firestore limits batches to 500 operations
- **Cross-Collection Consistency**: No cross-database or cross-collection transactions
- **Operation Types**: Some operations cannot be combined in a single batch
- **Document Size**: Individual document size limits still apply

## Example: Comprehensive Batch Operation

```dart
Future<void> processEventClosure(EventModel event) async {
  try {
    Logger.d('EventService', 'Processing event closure for ${event.id}');

    // Get all RSVPs for this event
    final rsvps = await _firestore
        .collection('rsvp')
        .where('eventId', isEqualTo: event.id)
        .get();

    // Get all notifications for this event
    final notifications = await _firestore
        .collection('notifications')
        .where('eventId', isEqualTo: event.id)
        .get();

    // Create a batch
    final batch = _firestore.batch();

    // Update event status
    final eventRef = _firestore.collection('events').doc(event.id);
    batch.update(eventRef, {'status': 'closed'});

    // Update all RSVPs
    for (final rsvp in rsvps.docs) {
      batch.update(rsvp.reference, {'status': 'closed'});
    }

    // Update all notifications
    for (final notification in notifications.docs) {
      batch.update(notification.reference, {'status': 'closed'});
    }

    // Create a summary document
    final summaryRef = _firestore.collection('event_summaries').doc();
    batch.set(summaryRef, {
      'eventId': event.id,
      'title': event.title,
      'attendeeCount': event.attendees.length,
      'likeCount': event.likedBy.length,
      'closedAt': FieldValue.serverTimestamp(),
    });

    // Commit the batch
    await batch.commit();
    Logger.d('EventService', 'Successfully closed event ${event.id}');
  } catch (e) {
    Logger.e('EventService', 'Error closing event ${event.id}', e);
    rethrow;
  }
}
```
