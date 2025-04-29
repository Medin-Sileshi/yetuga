import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../models/notification_model.dart';
import '../../services/event_service.dart';
import '../../services/notification_service.dart';
import '../../utils/logger.dart';

class JoinRequestsScreen extends ConsumerStatefulWidget {
  final String eventId;

  const JoinRequestsScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends ConsumerState<JoinRequestsScreen> {
  bool _isLoading = true;
  EventModel? _event;
  List<NotificationModel> _joinRequests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load the event
      final eventService = ref.read(eventServiceProvider);
      final event = await eventService.getEventWithRetry(widget.eventId);

      if (event == null) {
        setState(() {
          _isLoading = false;
          _error = 'Event not found';
        });
        return;
      }

      // Check if the current user is the event creator
      final currentUserId = eventService.getCurrentUserId();
      if (event.userId != currentUserId) {
        setState(() {
          _isLoading = false;
          _error = 'You are not authorized to view join requests for this event';
        });
        return;
      }

      // Load join requests
      final notificationService = ref.read(notificationServiceProvider);
      final joinRequests = await notificationService.getJoinRequestsForEvent(widget.eventId);

      setState(() {
        _event = event;
        _joinRequests = joinRequests;
        _isLoading = false;
      });
    } catch (e) {
      Logger.e('JoinRequestsScreen', 'Error loading data', e);
      setState(() {
        _isLoading = false;
        _error = 'Error loading data: $e';
      });
    }
  }

  Future<void> _handleJoinRequest(NotificationModel notification, bool isAccepted) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final notificationService = ref.read(notificationServiceProvider);
      final eventService = ref.read(eventServiceProvider);

      if (isAccepted) {
        // Accept the join request
        await notificationService.acceptJoinRequestObj(notification);

        // Add the user to the event's joinedBy list
        if (_event != null) {
          await eventService.addAttendee(_event!.id, notification.senderId);
        }
      } else {
        // Reject the join request
        await notificationService.rejectJoinRequestObj(notification);
      }

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccepted ? 'Join request accepted' : 'Join request rejected'),
          ),
        );
      }
    } catch (e) {
      Logger.e('JoinRequestsScreen', 'Error handling join request', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Requests'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_event == null) {
      return const Center(
        child: Text('Event not found'),
      );
    }

    if (_joinRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            const Text(
              'No join requests',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'When someone requests to join your event, they will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _joinRequests.length,
        itemBuilder: (context, index) {
          final notification = _joinRequests[index];
          return _buildJoinRequestCard(notification);
        },
      ),
    );
  }

  Widget _buildJoinRequestCard(NotificationModel notification) {
    final theme = Theme.of(context);
    final eventService = ref.read(eventServiceProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            FutureBuilder<String>(
              future: eventService.getUserDisplayName(notification.senderId),
              builder: (context, snapshot) {
                final displayName = snapshot.data ?? 'Loading...';
                return Row(
                  children: [
                    CircleAvatar(
                      child: Text(displayName.isNotEmpty ? displayName[0] : '?'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            'Wants to join your event',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Event info
            if (_event != null)
              Text(
                'Event: ${_event!.inquiry}',
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            // Time info
            Text(
              'Requested ${_formatTimeAgo(notification.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _handleJoinRequest(notification, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _handleJoinRequest(notification, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'just now';
    }
  }
}
