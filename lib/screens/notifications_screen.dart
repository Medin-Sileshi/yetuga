import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/event_user_service.dart';
import '../services/rsvp_service.dart';
import '../utils/logger.dart';
import '../widgets/event_info_widget.dart';
import '../widgets/notification_badge.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Keep track of which notifications have been marked as read
  final Set<String> _markedAsReadIds = {};

  @override
  void initState() {
    super.initState();
    // Schedule marking notifications as read after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllNotificationsAsRead();
    });
  }

  @override
  void dispose() {
    // Force a rebuild of the home screen when navigating back
    // This ensures the notification count is updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // This will trigger a rebuild of any widgets listening to the notification count
        ref.invalidate(notificationServiceProvider);
      }
    });
    super.dispose();
  }

  // Mark all non-join-request notifications as read when the screen is loaded
  Future<void> _markAllNotificationsAsRead() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final notifications = await notificationService.getNotifications().first;

      // Filter notifications that should be marked as read
      final notificationsToMark = notifications.where((notification) =>
        notification.status != NotificationStatus.read &&
        notification.type != NotificationType.joinRequest
      ).toList();

      if (notificationsToMark.isEmpty) return;

      Logger.d('NotificationsScreen', 'Marking ${notificationsToMark.length} notifications as read');

      // Mark all notifications as read in a batch
      await notificationService.markMultipleAsRead(
        notificationsToMark.map((n) => n.id).toList()
      );

      // Update the set of marked notifications
      setState(() {
        for (final notification in notificationsToMark) {
          _markedAsReadIds.add(notification.id);
        }
      });

      Logger.d('NotificationsScreen', 'Successfully marked ${notificationsToMark.length} notifications as read');
    } catch (e) {
      Logger.e('NotificationsScreen', 'Error marking notifications as read', e);
    }
  }
  @override
  Widget build(BuildContext context) {
    final notificationService = ref.watch(notificationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF0A2942),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Force a refresh of notifications
              final notificationService = ref.read(notificationServiceProvider);
              notificationService.checkAndSendUnreadNotifications();

              // Show a snackbar to indicate refresh
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing notifications...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force a refresh of notifications
          final notificationService = ref.read(notificationServiceProvider);
          await notificationService.checkAndSendUnreadNotifications();
          Logger.d('NotificationsScreen', 'Refreshed notifications via pull-to-refresh');
        },
        child: StreamBuilder<List<NotificationModel>>(
          stream: notificationService.getNotifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              // Use a ListView with a single item to ensure pull-to-refresh works
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (context, index) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    child: const Text('No notifications yet'),
                  );
                },
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // Ensure pull-to-refresh works
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                // Check if this notification has been marked as read locally
                // This ensures the UI reflects the read status immediately
                final bool isMarkedAsRead = _markedAsReadIds.contains(notification.id) ||
                                           notification.status == NotificationStatus.read;

                return NotificationItem(
                  notification: notification,
                  isMarkedAsRead: isMarkedAsRead,
                  onAccept: () => _handleAccept(notification),
                  onReject: () => _handleReject(notification),
                  onDismiss: () => _handleDismiss(notification),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAccept(NotificationModel notification) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);

      if (notification.type == NotificationType.joinRequest) {
        // Handle join request acceptance
        await notificationService.acceptJoinRequest(notification.id, notification.eventId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Join request accepted')),
          );
        }
      } else if (notification.type == NotificationType.eventInvitation) {
        // Handle event invitation acceptance
        final rsvpService = ref.read(rsvpServiceProvider);

        // First find the invitation ID
        final invitations = await rsvpService.getRSVPs().first;
        final invitation = invitations.firstWhere(
          (inv) => inv.eventId == notification.eventId && inv.inviterId == notification.senderId,
          orElse: () => throw Exception('Invitation not found'),
        );

        // Accept the invitation
        await rsvpService.acceptInvitation(invitation.id);

        // Mark the notification as accepted
        await notificationService.updateNotificationStatus(
          notification.id,
          NotificationStatus.accepted
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event invitation accepted')),
          );
        }
      }
    } catch (e) {
      Logger.e('NotificationsScreen', 'Error accepting notification', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleReject(NotificationModel notification) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);

      if (notification.type == NotificationType.joinRequest) {
        // Handle join request rejection
        await notificationService.rejectJoinRequest(notification.id, notification.eventId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Join request rejected')),
          );
        }
      } else if (notification.type == NotificationType.eventInvitation) {
        // Handle event invitation rejection
        final rsvpService = ref.read(rsvpServiceProvider);

        // First find the invitation ID
        final invitations = await rsvpService.getRSVPs().first;
        final invitation = invitations.firstWhere(
          (inv) => inv.eventId == notification.eventId && inv.inviterId == notification.senderId,
          orElse: () => throw Exception('Invitation not found'),
        );

        // Decline the invitation
        await rsvpService.declineInvitation(invitation.id);

        // Mark the notification as rejected
        await notificationService.updateNotificationStatus(
          notification.id,
          NotificationStatus.rejected
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event invitation rejected')),
          );
        }
      }
    } catch (e) {
      Logger.e('NotificationsScreen', 'Error rejecting notification', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDismiss(NotificationModel notification) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.deleteNotification(notification.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.e('NotificationsScreen', 'Error deleting notification', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // This method is no longer needed as we're using markMultipleAsRead instead
}

class NotificationItem extends ConsumerWidget {
  final NotificationModel notification;
  final bool isMarkedAsRead;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDismiss;

  const NotificationItem({
    Key? key,
    required this.notification,
    required this.isMarkedAsRead,
    required this.onAccept,
    required this.onReject,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventUserService = ref.watch(eventUserServiceProvider);
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text('Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        );

        // If confirmed, dismiss the notification
        if (confirmed == true) {
          onDismiss();
          return true;
        }

        // Otherwise, keep the notification
        return false;
      },
      onDismissed: (_) {}, // Animation handler (actual deletion is handled in onDismiss)
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // Add a subtle color to unread notifications
        color: !isMarkedAsRead
            ? Theme.of(context).colorScheme.primary.withAlpha(13) // ~0.05 opacity
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          // Add a colored border to unread notifications
          side: !isMarkedAsRead
              ? BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(76), width: 1) // ~0.3 opacity
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info
              FutureBuilder<String>(
                future: eventUserService.getUserDisplayName(notification.senderId),
                builder: (context, snapshot) {
                  final displayName = snapshot.data ?? 'User';

                  return Row(
                    children: [
                      // User avatar
                      FutureBuilder<bool>(
                        future: eventUserService.isBusinessAccount(notification.senderId),
                        builder: (context, businessSnapshot) {
                          final isBusiness = businessSnapshot.data ?? false;
                          // We don't need secondaryColor here as it's handled by getUserProfileImage

                          return eventUserService.getUserProfileImage(
                            notification.senderId,
                            size: 40,
                            isBusiness: isBusiness,
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      // User name and notification info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message ?? '',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Timestamp and unread indicator
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTimestamp(notification.createdAt),
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                          if (!isMarkedAsRead)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: NotificationBadge(
                                count: 1,
                                size: 8.0,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              // Event info
              if (notification.type == NotificationType.joinRequest ||
                  notification.type == NotificationType.eventInvitation)
                EventInfoWidget(eventId: notification.eventId),

              // Action buttons for pending join requests and event invitations
              if ((notification.type == NotificationType.joinRequest ||
                   notification.type == NotificationType.eventInvitation) &&
                  notification.status == NotificationStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('REJECT'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5F7A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('ACCEPT'),
                      ),
                    ],
                  ),
                ),

              // Status indicator for non-pending notifications
              if (notification.status != NotificationStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _buildStatusChip(notification.status),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(NotificationStatus status) {
    Color chipColor;
    String label;

    switch (status) {
      case NotificationStatus.accepted:
        chipColor = Colors.green;
        label = 'Accepted';
        break;
      case NotificationStatus.rejected:
        chipColor = Colors.red;
        label = 'Rejected';
        break;
      case NotificationStatus.read:
        chipColor = Colors.grey;
        label = 'Read';
        break;
      default:
        chipColor = Colors.orange;
        label = 'Pending';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
