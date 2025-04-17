import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';
import 'event_feed_card.dart';

class EventFeed extends StatelessWidget {
  final List<EventModel> events;
  final Function(EventModel) onJoin;
  final Function(EventModel) onIgnore;
  final ScrollController? scrollController;
  final String? filterType;

  const EventFeed({
    Key? key,
    required this.events,
    required this.onJoin,
    required this.onIgnore,
    this.scrollController,
    this.filterType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No events available',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filterType == 'JOINED'
                  ? 'You haven\'t joined or created any events yet'
                  : 'Check back later or create a new event',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // This would be replaced with actual refresh logic
        Logger.d('EventFeed', 'Refreshing feed');
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventFeedCard(
            event: event,
            onJoin: () => onJoin(event),
            onIgnore: () => onIgnore(event),
          );
        },
      ),
    );
  }
}
