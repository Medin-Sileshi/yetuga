import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/event_model.dart';
import '../screens/chat/chat_room_screen.dart';
import '../services/event_service.dart';
import '../services/event_user_service.dart';
import '../services/notification_service.dart';
import '../services/rsvp_service.dart';
import '../utils/confirmation_dialog.dart';
import '../utils/date_formatter.dart';
import '../utils/logger.dart';

class EventQrDialog extends ConsumerStatefulWidget {
  final String eventId;

  const EventQrDialog({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<EventQrDialog> createState() => _EventQrDialogState();
}

class _EventQrDialogState extends ConsumerState<EventQrDialog> {
  bool _isLoading = true;
  EventModel? _event;
  String? _error;
  bool _isJoinLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final eventService = ref.read(eventServiceProvider);
      final event = await eventService.getEvent(widget.eventId);

      if (mounted) {
        setState(() {
          _event = event;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.e('EventQrDialog', 'Error loading event: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoin() async {
    if (_isJoinLoading || _event == null) return;

    setState(() {
      _isJoinLoading = true;
    });

    try {
      final eventService = ref.read(eventServiceProvider);
      final notificationService = ref.read(notificationServiceProvider);
      final rsvpService = ref.read(rsvpServiceProvider);

      // Get the current context before any async operations
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // If user is already in the event (has joined), handle leave
      if (_event!.joinedBy.contains(eventService.getCurrentUserId())) {
        // Show confirmation dialog
        final confirmed = await ConfirmationDialog.show(
          context: context,
          title: 'Leave Event',
          message: 'Are you sure you want to leave this event?',
          confirmText: 'Leave',
          isDestructive: true,
        );

        if (!confirmed) {
          setState(() {
            _isJoinLoading = false;
          });
          return;
        }

        await eventService.toggleJoin(_event!.id);

        // Force update the UI immediately
        if (mounted) {
          setState(() {
            // Remove current user from joinedBy
            _event!.joinedBy.remove(eventService.getCurrentUserId());
          });

          // Show a message
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('You have left this event.'))
          );

          // Close the dialog
          Navigator.of(context).pop();
        }
      }
      // If this is a new join request
      else {
        // Check if the user was invited to this event
        final wasInvited = await rsvpService.isUserInvited(_event!.id, eventService.getCurrentUserId());

        if (wasInvited || _event!.isInvited) {
          // If the user was invited, directly join the event without requiring approval
          // and create a notification for the event creator
          await notificationService.createJoinRequest(_event!);

          // Force update the UI immediately
          if (mounted) {
            setState(() {
              // Add current user to joinedBy
              if (!_event!.joinedBy.contains(eventService.getCurrentUserId())) {
                _event!.joinedBy.add(eventService.getCurrentUserId());
              }

              // Show a message
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('You have joined the event!'))
              );

              // Close the dialog
              Navigator.of(context).pop();
            });
          }
        } else {
          // For non-invited users, create a join request notification
          await notificationService.createJoinRequest(_event!);

          // Update UI to show pending state
          if (mounted) {
            // Show a message
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Join request sent. Waiting for approval from the event creator.'))
            );

            // Close the dialog
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      Logger.e('EventQrDialog', 'Error handling join request', e);
      // Show error message
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoinLoading = false;
        });
      }
    }
  }

  // Build event type image based on activity type
  Widget _buildEventTypeImage(String activityType) {
    // Normalize the activity type to match the image naming convention
    String normalizedType = activityType.trim();

    // Check if the activity type matches one of our image assets
    // The available types are: Celebrate, Drink, Eat, Play, Run, Visit, Walk, Watch
    final validTypes = ['Celebrate', 'Drink', 'Eat', 'Play', 'Run', 'Visit', 'Walk', 'Watch'];

    // If the exact type isn't found, try to find a close match
    if (!validTypes.contains(normalizedType)) {
      // Check for similar types (case insensitive)
      normalizedType = validTypes.firstWhere(
        (type) => type.toLowerCase() == normalizedType.toLowerCase(),
        orElse: () {
          // Handle common variations
          if (normalizedType.toLowerCase().contains('eat') ||
              normalizedType.toLowerCase().contains('food') ||
              normalizedType.toLowerCase().contains('dinner') ||
              normalizedType.toLowerCase().contains('lunch') ||
              normalizedType.toLowerCase().contains('restaurant')) {
            return 'Eat';
          } else if (normalizedType.toLowerCase().contains('drink') ||
                    normalizedType.toLowerCase().contains('coffee') ||
                    normalizedType.toLowerCase().contains('bar')) {
            return 'Drink';
          } else if (normalizedType.toLowerCase().contains('play') ||
                    normalizedType.toLowerCase().contains('game') ||
                    normalizedType.toLowerCase().contains('sport')) {
            return 'Play';
          } else if (normalizedType.toLowerCase().contains('walk') ||
                    normalizedType.toLowerCase().contains('hike')) {
            return 'Walk';
          } else if (normalizedType.toLowerCase().contains('run') ||
                    normalizedType.toLowerCase().contains('jog') ||
                    normalizedType.toLowerCase().contains('marathon')) {
            return 'Run';
          } else if (normalizedType.toLowerCase().contains('visit') ||
                    normalizedType.toLowerCase().contains('tour') ||
                    normalizedType.toLowerCase().contains('travel')) {
            return 'Visit';
          } else if (normalizedType.toLowerCase().contains('celebrat') ||
                    normalizedType.toLowerCase().contains('party') ||
                    normalizedType.toLowerCase().contains('event')) {
            return 'Celebrate';
          } else if (normalizedType.toLowerCase().contains('watch') ||
                    normalizedType.toLowerCase().contains('movie') ||
                    normalizedType.toLowerCase().contains('show') ||
                    normalizedType.toLowerCase().contains('concert')) {
            return 'Watch';
          }

          // Default to 'Celebrate' if no match is found
          return 'Celebrate';
        },
      );
    }

    // Construct the asset path following the naming convention '[event-type]-Card.jpg'
    final assetPath = 'assets/images/$normalizedType-Card.jpg';

    Logger.d('EventQrDialog', 'Loading image for activity type: $activityType, using asset: $assetPath');

    // Return the image widget
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        Logger.e('EventQrDialog', 'Error loading image: $error');
        // Fallback to a placeholder if the image fails to load
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.photo,
              size: 50,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: _buildDialogContent(theme),
      ),
    );
  }

  Widget _buildDialogContent(ThemeData theme) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Error loading event',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEvent,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_event == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Event not found'),
        ),
      );
    }

    final event = _event!;
    final eventService = ref.read(eventServiceProvider);
    final eventUserService = ref.read(eventUserServiceProvider);
    final currentUserId = eventService.getCurrentUserId();
    final isEventCreator = event.userId == currentUserId;
    final hasJoined = eventService.hasJoined(event);

    // Get real values for engagement stats
    final int likesCount = event.likedBy.length;
    final int attendeesCount = event.joinedBy.length;

    // Check if attendee limit is reached
    final bool hasAttendeeLimit = event.attendeeLimit != null;
    final bool isLimitReached = hasAttendeeLimit && attendeesCount >= event.attendeeLimit!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with gradient background based on account type
          FutureBuilder<bool>(
            future: eventUserService.isBusinessAccount(event.userId),
            builder: (context, snapshot) {
              final isBusiness = snapshot.data ?? false;

              // Define colors based on account type
              final Color headerStartColor = isBusiness ? const Color(0xFFE6C34E) : const Color(0xFF1A5F7A);
              const Color headerEndColor = Color(0xFF0A2942);

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerStartColor, headerEndColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // User Avatar
                    FutureBuilder<String?>(
                      future: eventUserService.getUserProfileImageUrl(event.userId),
                      builder: (context, imageSnapshot) {
                        if (imageSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final imageUrl = imageSnapshot.data;

                        if (imageUrl == null || imageUrl.isEmpty) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isBusiness ? const Color(0xFFE6C34E) : Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 12),

                    // User Name and Event Type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User display name
                          FutureBuilder<String>(
                            future: eventUserService.getUserDisplayName(event.userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 100,
                                  height: 14,
                                  child: LinearProgressIndicator(minHeight: 2),
                                );
                              }

                              final displayName = snapshot.data ?? 'User';

                              return Text(
                                displayName.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          // Username
                          FutureBuilder<String>(
                            future: eventUserService.getUserUsername(event.userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 80,
                                  height: 12,
                                  child: LinearProgressIndicator(minHeight: 2),
                                );
                              }

                              final username = snapshot.data ?? 'username';

                              return Text(
                                '@$username',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Card Image with Like Button overlay
          Stack(
            children: [
              // Image based on event type
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildEventTypeImage(event.activityType),
              ),

              // Like button overlay and counter
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        likesCount.toString(),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Engagement Stats and Date/Time - Aligned to opposite sides
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between date and stats
              children: [
                // Date and Time - Left side
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      event.activityType,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${DateFormatter.formatMonthShort(event.date)} ${event.date.day} @ ${event.time.format(context)}',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // Stats - Right side
                Row(
                  children: [
                    // Attendees count with limit
                    Text(
                      hasAttendeeLimit
                        ? "$attendeesCount/${event.attendeeLimit} joined"
                        : "$attendeesCount joined",
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 14,
                        fontWeight: isLimitReached ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Event Inquiry
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              event.inquiry,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Back Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Join/View Button
                Expanded(
                  child: isEventCreator || hasJoined
                    ? ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to chat room if the user has joined or created the event
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatRoomScreen(event: event),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF1A5F7A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'CHAT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _isJoinLoading ? null : _handleJoin,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF1A5F7A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isJoinLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'JOIN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
