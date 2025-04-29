import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';
import 'event_feed_card.dart';

class EventFeed extends StatefulWidget {
  final List<EventModel> events;
  final Function(EventModel) onJoin;
  final Function(EventModel) onIgnore;
  final ScrollController? scrollController;
  final String? filterType;
  final Future<void> Function()? onRefresh;

  const EventFeed({
    Key? key,
    required this.events,
    required this.onJoin,
    required this.onIgnore,
    this.scrollController,
    this.filterType,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<EventFeed> createState() => _EventFeedState();
}

class _EventFeedState extends State<EventFeed> {
  // Debounce mechanism for refresh
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  @override
  Widget build(BuildContext context) {
    // Check if events list is empty
    if (widget.events.isEmpty) {
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
              widget.filterType == 'JOINED'
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
        // Debounce mechanism to prevent multiple rapid refreshes
        final now = DateTime.now();
        if (_isRefreshing) {
          Logger.d('EventFeed', 'Already refreshing, ignoring duplicate request');
          return;
        }

        if (_lastRefreshTime != null) {
          final timeSinceLastRefresh = now.difference(_lastRefreshTime!);
          if (timeSinceLastRefresh.inSeconds < 3) {
            Logger.d('EventFeed', 'Refresh requested too soon (${timeSinceLastRefresh.inMilliseconds}ms since last refresh), ignoring');
            return;
          }
        }

        // Set refreshing state
        setState(() {
          _isRefreshing = true;
        });

        try {
          Logger.d('EventFeed', 'Pull-to-refresh triggered');
          if (widget.onRefresh != null) {
            await widget.onRefresh!();
            Logger.d('EventFeed', 'Refresh completed successfully');
          } else {
            // Default refresh logic if no callback provided
            Logger.d('EventFeed', 'No refresh callback provided');
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          Logger.e('EventFeed', 'Error during refresh', e);
          // Let the error propagate to show the refresh indicator failure
          rethrow;
        } finally {
          // Reset refreshing state
          if (mounted) {
            setState(() {
              _isRefreshing = false;
              _lastRefreshTime = now;
            });
          }
        }
      },
      displacement: 40, // More space for the indicator
      edgeOffset: 0, // Start from the very top
      strokeWidth: 3, // Thicker indicator line
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Use a ListView with physics that always allow scrolling
      // This ensures pull-to-refresh works even with a single item
      child: widget.events.length <= 1
          ? ListView.builder(
              // Always allow scrolling even with few items and ensure bounce effect for pull-to-refresh
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              // Add an extra empty item to ensure scrollability
              itemCount: widget.events.length + 1,
              itemBuilder: (context, index) {
                if (index < widget.events.length) {
                  try {
                    final event = widget.events[index];
                    // Validate event data before creating the card
                    if (event.id.isEmpty) {
                      Logger.e('EventFeed', 'Event at index $index has an empty ID');
                      return const SizedBox.shrink(); // Skip invalid events
                    }
                    return EventFeedCard(
                      event: event,
                      onJoin: () => widget.onJoin(event),
                      onIgnore: () => widget.onIgnore(event),
                    );
                  } catch (e) {
                    // Handle any errors that occur when building the card
                    Logger.e('EventFeed', 'Error building event card at index $index: $e');
                    return const SizedBox.shrink(); // Skip problematic events
                  }
                } else {
                  // Add an empty space at the end to ensure scrollability
                  return const SizedBox(height: 100);
                }
              },
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.events.length,
              itemBuilder: (context, index) {
                try {
                  final event = widget.events[index];
                  // Validate event data before creating the card
                  if (event.id.isEmpty) {
                    Logger.e('EventFeed', 'Event at index $index has an empty ID');
                    return const SizedBox.shrink(); // Skip invalid events
                  }
                  return EventFeedCard(
                    event: event,
                    onJoin: () => widget.onJoin(event),
                    onIgnore: () => widget.onIgnore(event),
                  );
                } catch (e) {
                  // Handle any errors that occur when building the card
                  Logger.e('EventFeed', 'Error building event card at index $index: $e');
                  return const SizedBox.shrink(); // Skip problematic events
                }
              },
            ),
    );
  }
}
