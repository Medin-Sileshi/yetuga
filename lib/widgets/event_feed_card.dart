import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../screens/chat/chat_room_screen.dart';
import '../services/chat_service.dart';
import '../services/event_user_service.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import '../utils/date_formatter.dart';
import '../utils/logger.dart';

class EventFeedCard extends ConsumerStatefulWidget {
  final EventModel event;
  final VoidCallback onJoin;
  final VoidCallback onIgnore;

  const EventFeedCard({
    Key? key,
    required this.event,
    required this.onJoin,
    required this.onIgnore,
  }) : super(key: key);

  @override
  ConsumerState<EventFeedCard> createState() => _EventFeedCardState();
}

class _EventFeedCardState extends ConsumerState<EventFeedCard> {
  bool _isLikeLoading = false;
  bool _isJoinLoading = false;
  bool _hasPendingRequest = false;
  bool _hasRejectedRequest = false;

  @override
  void initState() {
    super.initState();
    _checkPendingRequest();
  }

  Future<void> _checkPendingRequest() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final hasPending = await notificationService.hasPendingJoinRequest(widget.event.id);
      final hasRejected = await notificationService.hasRejectedJoinRequest(widget.event.id);

      if (mounted) {
        setState(() {
          _hasPendingRequest = hasPending;
          _hasRejectedRequest = hasRejected;
        });
      }
    } catch (e) {
      Logger.e('EventFeedCard', 'Error checking request status', e);
    }
  }

  // Handle like button press
  Future<void> _handleLike() async {
    if (_isLikeLoading) return; // Prevent multiple rapid taps

    setState(() {
      _isLikeLoading = true;
    });

    try {
      final eventService = ref.read(eventServiceProvider);
      final isLiked = await eventService.toggleLike(widget.event.id);

      // Force update the UI immediately
      if (mounted) {
        setState(() {
          // Update the local event model to reflect the change
          if (isLiked) {
            // Add current user to likedBy if not already there
            if (!widget.event.likedBy.contains(eventService.getCurrentUserId())) {
              widget.event.likedBy.add(eventService.getCurrentUserId());
            }
          } else {
            // Remove current user from likedBy
            widget.event.likedBy.remove(eventService.getCurrentUserId());
          }
        });
      }
    } catch (e) {
      Logger.e('EventFeedCard', 'Error toggling like', e);
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  // Handle join button press
  Future<void> _handleJoin() async {
    if (_isJoinLoading) return; // Prevent multiple rapid taps

    setState(() {
      _isJoinLoading = true;
    });

    try {
      final eventService = ref.read(eventServiceProvider);
      final notificationService = ref.read(notificationServiceProvider);

      // We don't need to check if this is the event creator here
      // since the button is disabled for event creators

      // If user is already in the event (has joined), handle leave
      if (widget.event.joinedBy.contains(eventService.getCurrentUserId())) {
        await eventService.toggleJoin(widget.event.id);

        // Force update the UI immediately
        if (mounted) {
          setState(() {
            // Remove current user from joinedBy
            widget.event.joinedBy.remove(eventService.getCurrentUserId());

            // Show a message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have left this event.'))
            );
          });
        }
      }
      // If user has a pending request, show message
      else if (_hasPendingRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your join request is pending approval from the event creator.'))
        );
      }
      // If user has a rejected request, show message
      else if (_hasRejectedRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your join request was denied by the event creator.'))
        );
      }
      // If this is a new join request
      else {
        // Create a join request notification
        await notificationService.createJoinRequest(widget.event);

        // Update UI to show pending state
        if (mounted) {
          setState(() {
            _hasPendingRequest = true;

            // Show a message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Join request sent. Waiting for approval from the event creator.'))
            );
          });
        }
      }
    } catch (e) {
      Logger.e('EventFeedCard', 'Error handling join request', e);
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    // Convert to title case and handle any special cases
    String normalizedType = activityType.trim();

    // Check if the activity type matches one of our image assets
    // The available types are: Celebrate, Drink, Eating, Play, Visit, Walk
    final validTypes = ['Celebrate', 'Drink', 'Eating', 'Play', 'Visit', 'Walk'];

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
              normalizedType.toLowerCase().contains('lunch')) {
            return 'Eating';
          } else if (normalizedType.toLowerCase().contains('drink') ||
                    normalizedType.toLowerCase().contains('coffee') ||
                    normalizedType.toLowerCase().contains('bar')) {
            return 'Drink';
          } else if (normalizedType.toLowerCase().contains('play') ||
                    normalizedType.toLowerCase().contains('game') ||
                    normalizedType.toLowerCase().contains('sport')) {
            return 'Play';
          } else if (normalizedType.toLowerCase().contains('walk') ||
                    normalizedType.toLowerCase().contains('hike') ||
                    normalizedType.toLowerCase().contains('run')) {
            return 'Walk';
          } else if (normalizedType.toLowerCase().contains('visit') ||
                    normalizedType.toLowerCase().contains('tour') ||
                    normalizedType.toLowerCase().contains('travel')) {
            return 'Visit';
          } else if (normalizedType.toLowerCase().contains('celebrat') ||
                    normalizedType.toLowerCase().contains('party') ||
                    normalizedType.toLowerCase().contains('event')) {
            return 'Celebrate';
          }

          // Default to 'Celebrate' if no match is found
          return 'Celebrate';
        },
      );
    }

    // Construct the asset path
    final assetPath = 'assets/images/$normalizedType-Card.jpg';

    Logger.d('EventFeedCard', 'Loading image for activity type: $activityType, using asset: $assetPath');

    // Return the image widget
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        Logger.e('EventFeedCard', 'Error loading image: $error');
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

  // Show QR code dialog
  void _showQrCodeDialog(BuildContext context, String eventId) {
    Logger.d('EventFeedCard', 'Showing QR code for event: $eventId');

    // Create a unique data string for this event
    final String qrData = 'yetuga://event/$eventId';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Event QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan this code to view the event',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: 200,
                height: 200,
                color: Colors.white,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Event ID: $eventId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventService = ref.read(eventServiceProvider);

    // Get real values for engagement stats
    final int likesCount = widget.event.likedBy.length;
    final int attendeesCount = widget.event.joinedBy.length;

    // Check if current user has joined
    final bool hasJoined = eventService.hasJoined(widget.event);

    // Check if current user is the event creator
    final String currentUserId = eventService.getCurrentUserId();
    final bool isEventCreator = widget.event.userId == currentUserId;

    // Check if attendee limit is reached
    final bool hasAttendeeLimit = widget.event.attendeeLimit != null;
    final bool isLimitReached = hasAttendeeLimit && attendeesCount >= widget.event.attendeeLimit!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(50), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias, // Ensures the image doesn't overflow the rounded corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A5F7A), Color(0xFF0A2942)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User Avatar with business/personal border
                Builder(
                  builder: (context) {
                    // Get the theme's secondary color for personal account borders
                    final secondaryColor = Theme.of(context).colorScheme.secondary;

                    return FutureBuilder<bool>(
                      future: ref.read(eventUserServiceProvider).isBusinessAccount(widget.event.userId),
                      builder: (context, businessSnapshot) {
                        final isBusiness = businessSnapshot.data ?? false;

                        return FutureBuilder<String?>(
                          future: ref.read(eventUserServiceProvider).getUserProfileImageUrl(widget.event.userId),
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
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isBusiness ? Colors.amber : secondaryColor,
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              );
                            }

                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isBusiness ? Colors.amber : secondaryColor,
                                  width: 2,
                                ),
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
                          },
                        );
                      },
                    );
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
                        future: ref.read(eventUserServiceProvider).getUserDisplayName(widget.event.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              width: 100,
                              height: 14,
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }

                          final displayName = snapshot.data ?? 'User';
                          Logger.d('EventFeedCard', 'Display name for user ${widget.event.userId}: $displayName');

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
                        future: ref.read(eventUserServiceProvider).getUserUsername(widget.event.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              width: 80,
                              height: 12,
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }

                          final username = snapshot.data ?? 'username';
                          Logger.d('EventFeedCard', 'Username for user ${widget.event.userId}: $username');

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

                // QR Code button
                IconButton(
                  icon: const Icon(
                    Icons.qr_code,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    _showQrCodeDialog(context, widget.event.id);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Card Image with Like Button overlay
          Stack(
            children: [
              // Image based on event type
              GestureDetector(
                onTap: _handleLike, // Like on tap
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildEventTypeImage(widget.event.activityType),
                ),
              ),

              // Like button overlay and counter
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: _handleLike,
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
                        widget.event.activityType,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      '${DateFormatter.formatMonthShort(widget.event.date)} ${widget.event.date.day} @ ${widget.event.time.format(context)}',
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
                    Row(
                      children: [
                        Text(
                          hasAttendeeLimit
                            ? "$attendeesCount/${widget.event.attendeeLimit} joined"
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
              ],
            ),
          ),

          // Event Inquiry
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.event.inquiry,
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



                // Ignore Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: isEventCreator ? null : widget.onIgnore, // Disable if user is event creator
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side: BorderSide(color: isEventCreator ? Colors.grey : Colors.red[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'IGNORE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Join/Chat Button
                Expanded(
                  child: isEventCreator
                    // Chat button for event creator
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'chat') {
                            // Navigate to chat room
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ChatRoomScreen(event: widget.event),
                              ),
                            );
                          } else if (value == 'manage') {
                            // TODO: Implement event management functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Event management coming soon'))
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'chat',
                            child: Row(
                              children: [
                                Icon(Icons.chat, color: Color(0xFF1A5F7A)),
                                SizedBox(width: 8),
                                Text('Chat with attendees'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'manage',
                            child: Row(
                              children: [
                                Icon(Icons.settings, color: Color(0xFF1A5F7A)),
                                SizedBox(width: 8),
                                Text('Manage event'),
                              ],
                            ),
                          ),
                        ],
                        child: ElevatedButton(
                          onPressed: null, // Button is just for show, popup is triggered by PopupMenuButton
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF1A5F7A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CHAT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      )
                    // Join/Chat button for other users
                    : hasJoined
                        // Chat button for users who have joined
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'chat') {
                                // Navigate to chat room
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ChatRoomScreen(event: widget.event),
                                  ),
                                );
                              } else if (value == 'leave') {
                                _handleJoin(); // This will toggle the join status (leave the event)
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'chat',
                                child: Row(
                                  children: [
                                    Icon(Icons.chat, color: Color(0xFF1A5F7A)),
                                    SizedBox(width: 8),
                                    Text('Chat with attendees'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'leave',
                                child: Row(
                                  children: [
                                    Icon(Icons.exit_to_app, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Leave event'),
                                  ],
                                ),
                              ),
                            ],
                            child: ElevatedButton(
                              onPressed: null, // Button is just for show, popup is triggered by PopupMenuButton
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF1A5F7A),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'CHAT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, size: 20),
                                ],
                              ),
                            ),
                          )
                        // Join/Request button for users who haven't joined
                        : ElevatedButton(
                            onPressed: isLimitReached || _hasRejectedRequest ? null : () => _handleJoin(),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: _hasPendingRequest ? Colors.orange :
                                                 _hasRejectedRequest ? Colors.red : const Color(0xFF1A5F7A),
                              disabledBackgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              isLimitReached ? 'LIMIT REACHED' :
                                (_hasPendingRequest ? 'PENDING' :
                                  (_hasRejectedRequest ? 'DENIED' : 'JOIN')),
                              style: const TextStyle(
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
