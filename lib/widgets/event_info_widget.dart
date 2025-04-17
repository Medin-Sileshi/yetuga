import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';
import '../utils/date_formatter.dart';

class EventInfoWidget extends StatelessWidget {
  final String eventId;

  const EventInfoWidget({Key? key, required this.eventId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // Handle error state
        if (snapshot.hasError) {
          Logger.e('EventInfoWidget', 'Error fetching event', snapshot.error);
          return const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('Could not load event details'),
          );
        }

        // Handle no data
        if (!snapshot.hasData || snapshot.data == null) {
          return const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('Event not found'),
          );
        }

        // Try to parse the event
        try {
          final event = EventModel.fromFirestore(snapshot.data!);
          final theme = Theme.of(context);
          
          return Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event: ${event.inquiry}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.activityType} on ${DateFormatter.formatMonthShort(event.date)} ${event.date.day} @ ${event.time.format(context)}',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          );
        } catch (e) {
          Logger.e('EventInfoWidget', 'Error parsing event data', e);
          return const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('Event details not available'),
          );
        }
      },
    );
  }
}
