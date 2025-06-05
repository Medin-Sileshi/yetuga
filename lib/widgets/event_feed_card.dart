import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/prefetch_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rsvp_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_model.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/event_management_screen.dart';
import '../services/event_user_service.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import '../utils/date_formatter.dart';
import '../utils/logger.dart';
import '../utils/confirmation_dialog.dart';
import 'user_profile_dialog.dart';

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

  // Store the current event state locally
  late EventModel _currentEvent;

  // Stream subscription for document-level updates
  StreamSubscription<DocumentSnapshot>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    try {
      // Initialize the current event from the widget
      _currentEvent = widget.event;

      // Validate event data
      if (_currentEvent.id.isEmpty) {
        Logger.e('EventFeedCard', 'Event has an empty ID, skipping initialization');
        return;
      }

      // Check for pending join requests
      _checkPendingRequest();

      // Subscribe to document-level updates
      _subscribeToEventUpdates();

      // Track event view for prefetching
      _trackEventView();
    } catch (e) {
      // Log any errors during initialization
      Logger.e('EventFeedCard', 'Error initializing event card: $e');
    }
  }

  // Track event view for prefetching
  void _trackEventView() {
    try {
      final prefetchService = ref.read(prefetchServiceProvider);
      prefetchService.trackEventView(_currentEvent.id);

      // Also track interaction with the event creator
      prefetchService.trackUserInteraction(_currentEvent.userId);
    } catch (e) {
      // Silently ignore errors in tracking
      Logger.d('EventFeedCard', 'Error tracking event view: $e');
    }
  }

  void _subscribeToEventUpdates() {
    try {
      final eventId = widget.event.id;
      if (eventId.isEmpty) {
        Logger.e('EventFeedCard', 'Cannot subscribe to updates for event with empty ID');
        return;
      }

      // Cancel any existing subscription first to prevent memory leaks
      if (_eventSubscription != null) {
        Logger.d('EventFeedCard', 'Cancelling previous subscription for event: $eventId');
        _eventSubscription!.cancel();
        _eventSubscription = null;
      }

      // Only subscribe if the widget is still mounted
      if (!mounted) {
        Logger.d('EventFeedCard', 'Widget not mounted, skipping subscription for event: $eventId');
        return;
      }

      final eventsCollection = FirebaseFirestore.instance.collection('events');

      Logger.d('EventFeedCard', 'Setting up new subscription for event: $eventId');
      _eventSubscription = eventsCollection.doc(eventId).snapshots().listen(
        (snapshot) {
          // Store the mounted state in a local variable to avoid race conditions
          final isWidgetMounted = mounted;

          if (!isWidgetMounted) {
            Logger.d('EventFeedCard', 'Widget not mounted during snapshot update for event: $eventId');
            return;
          }

          try {
            if (snapshot.exists) {
              final updatedEvent = EventModel.fromFirestore(snapshot);

              // Log privacy changes for debugging
              if (_currentEvent.isPrivate != updatedEvent.isPrivate) {
                Logger.d('EventFeedCard', 'Privacy changed for event $eventId: ${_currentEvent.isPrivate} -> ${updatedEvent.isPrivate}');
              }

              // Only update if there are actual changes to the event
              if (_hasRelevantChanges(_currentEvent, updatedEvent)) {
                // Check mounted again right before setState to avoid race conditions
                if (isWidgetMounted && mounted) {
                  try {
                    setState(() {
                      _currentEvent = updatedEvent;
                    });
                    Logger.d('EventFeedCard', 'State updated successfully for event: $eventId');
                  } catch (stateError) {
                    Logger.e('EventFeedCard', 'Error updating state: $stateError');
                  }
                } else {
                  Logger.d('EventFeedCard', 'Widget no longer mounted, skipping setState for event: $eventId');
                }
              }
            } else {
              Logger.d('EventFeedCard', 'Event document no longer exists: $eventId');
            }
          } catch (e) {
            Logger.e('EventFeedCard', 'Error processing event snapshot: $e');
          }
        },
        onError: (error) {
          Logger.e('EventFeedCard', 'Error in event subscription: $error');
        },
        onDone: () {
          Logger.d('EventFeedCard', 'Stream subscription closed for event: $eventId');
        },
      );
    } catch (e) {
      Logger.e('EventFeedCard', 'Error setting up event subscription: $e');
    }
  }

  bool _hasRelevantChanges(EventModel oldEvent, EventModel newEvent) {
    // Only check fields that would affect the UI
    return oldEvent.likedBy.length != newEvent.likedBy.length ||
           oldEvent.joinedBy.length != newEvent.joinedBy.length ||
           oldEvent.inquiry != newEvent.inquiry ||
           oldEvent.isPrivate != newEvent.isPrivate;
  }

  @override
  void didUpdateWidget(EventFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the event ID has changed, we need to resubscribe
    if (oldWidget.event.id != widget.event.id) {
      Logger.d('EventFeedCard', 'Event ID changed, resubscribing to updates');

      // Cancel the old subscription
      _eventSubscription?.cancel();

      // Update the current event
      _currentEvent = widget.event;

      // Subscribe to updates for the new event
      _subscribeToEventUpdates();

      // Check for pending requests for the new event
      _checkPendingRequest();
    }
    // If the event has changed but the ID is the same, update our local copy
    else if (oldWidget.event != widget.event) {
      Logger.d('EventFeedCard', 'Event updated, updating local copy');

      // Check if privacy changed
      if (oldWidget.event.isPrivate != widget.event.isPrivate) {
        Logger.d('EventFeedCard', 'Privacy changed: ${oldWidget.event.isPrivate} -> ${widget.event.isPrivate}');
      }

      // Update the current event if there are relevant changes
      if (_hasRelevantChanges(_currentEvent, widget.event)) {
        setState(() {
          _currentEvent = widget.event;
        });
      }
    }
  }

  @override
  void dispose() {
    final eventId = widget.event.id;
    Logger.d('EventFeedCard', 'Disposing EventFeedCard for event: $eventId');

    // Cancel the subscription when the widget is disposed
    if (_eventSubscription != null) {
      Logger.d('EventFeedCard', 'Cancelling subscription in dispose() for event: $eventId');
      _eventSubscription!.cancel();
      _eventSubscription = null;
    }

    // Clear any references that might cause memory leaks
    _currentEvent = EventModel(
      id: '',
      userId: '',
      activityType: '',
      inquiry: '',
      date: DateTime.now(),
      time: const TimeOfDay(hour: 0, minute: 0),
      isPrivate: false,
    );

    Logger.d('EventFeedCard', 'Dispose complete for event: $eventId');
    super.dispose();
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
      final isLiked = await eventService.toggleLike(_currentEvent.id);

      // Force update the UI immediately
      if (mounted) {
        setState(() {
          // Update the local event model to reflect the change
          if (isLiked) {
            // Add current user to likedBy if not already there
            if (!_currentEvent.likedBy.contains(eventService.getCurrentUserId())) {
              _currentEvent.likedBy.add(eventService.getCurrentUserId());
            }
          } else {
            // Remove current user from likedBy
            _currentEvent.likedBy.remove(eventService.getCurrentUserId());
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
      final rsvpService = ref.read(rsvpServiceProvider);

      // We don't need to check if this is the event creator here
      // since the button is disabled for event creators

      // If user is already in the event (has joined), handle leave
      if (_currentEvent.joinedBy.contains(eventService.getCurrentUserId())) {
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

        await eventService.toggleJoin(_currentEvent.id);

        // Force update the UI immediately
        if (mounted) {
          setState(() {
            // Remove current user from joinedBy
            _currentEvent.joinedBy.remove(eventService.getCurrentUserId());
          });

          // Show a message
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('You have left this event.'))
          );
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
        // Check if the user was invited to this event
        final wasInvited = await rsvpService.isUserInvited(_currentEvent.id, eventService.getCurrentUserId());

        if (wasInvited || _currentEvent.isInvited) {
          // If the user was invited, directly join the event without requiring approval
          // and create a notification for the event creator
          await notificationService.createJoinRequest(_currentEvent);

          // Force update the UI immediately
          if (mounted) {
            setState(() {
              // Add current user to joinedBy
              if (!_currentEvent.joinedBy.contains(eventService.getCurrentUserId())) {
                _currentEvent.joinedBy.add(eventService.getCurrentUserId());
              }

              // Show a message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have joined the event!'))
              );
            });
          }

          // Call the onJoin callback to update the parent widget
          widget.onJoin();
        } else {
          // For non-invited users, create a join request notification
          await notificationService.createJoinRequest(_currentEvent);

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
  // Download QR code as image
  Future<void> _downloadQrCode(BuildContext context, GlobalKey qrKey, String fileName) async {
    // Store the context before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Find the RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('QR code render object not found');
      }

      // Capture the image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // Convert to bytes
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;

      // Create file
      final File file = File('$tempPath/$fileName.png');
      await file.writeAsBytes(pngBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code in the the Yetu\'ga app to view this event event',
      );

      // Show success message
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('QR code shared successfully!'))
        );
      }
    } catch (e) {
      Logger.e('EventFeedCard', 'Error downloading QR code', e);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
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

  // Show user profile dialog
  void _showUserProfileDialog(BuildContext context, String userId) {
    // Track user interaction for prefetching
    try {
      final prefetchService = ref.read(prefetchServiceProvider);
      prefetchService.trackUserInteraction(userId);
    } catch (e) {
      // Silently ignore errors in tracking
      Logger.d('EventFeedCard', 'Error tracking user interaction: $e');
    }

    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(userId: userId),
    );
  }

  // Handle ignore button press
  Future<void> _handleIgnore(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Ignore Event',
      message: 'Are you sure you want to ignore this event? It will be removed from your feed.',
      confirmText: 'Ignore',
      isDestructive: true,
    );

    if (confirmed) {
      widget.onIgnore();
    }
  }

  // Show QR code dialog
  void _showQrCodeDialog(BuildContext context, String eventId) {
    Logger.d('EventFeedCard', 'Showing QR code for event: $eventId');

    // Create a unique data string for this event
    final String qrData = 'yetuga://event/$eventId';

    // Create a GlobalKey to capture the QR code as an image
    final GlobalKey qrKey = GlobalKey();

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
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26), // ~0.1 opacity
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
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
                    embeddedImage: const AssetImage('assets/icon/icon_white.jpg'),
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(30, 30),
                ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Event ID: $eventId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _downloadQrCode(context, qrKey, 'event_${eventId}_qr'),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
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
    final int likesCount = _currentEvent.likedBy.length;
    final int attendeesCount = _currentEvent.joinedBy.length;

    // Check if current user has joined
    final bool hasJoined = eventService.hasJoined(_currentEvent);

    // Check if current user is the event creator
    final String currentUserId = eventService.getCurrentUserId();
    final bool isEventCreator = _currentEvent.userId == currentUserId;

    // Check if attendee limit is reached
    final bool hasAttendeeLimit = _currentEvent.attendeeLimit != null;
    final bool isLimitReached = hasAttendeeLimit && attendeesCount >= _currentEvent.attendeeLimit!;

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
          // Card Header with gradient background based on account type
          FutureBuilder<bool>(
            future: ref.read(eventUserServiceProvider).isBusinessAccount(_currentEvent.userId),
            builder: (context, snapshot) {
              final isBusiness = snapshot.data ?? false;
              Logger.d('EventFeedCard', 'isBusinessAccount for ${_currentEvent.userId} = $isBusiness');

              // Define colors based on account type
              final Color headerStartColor = isBusiness ? const Color(0xFFE6C34E) : const Color(0xFF1A5F7A);
              const Color headerEndColor = Color(0xFF0A2942);
              final Color borderColor = isBusiness ? const Color(0xFFE6C34E) : Theme.of(context).colorScheme.secondary;

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
                    // User Avatar with business/personal border
                    FutureBuilder<String?>(
                      future: ref.read(eventUserServiceProvider).getUserProfileImageUrl(_currentEvent.userId),
                      builder: (context, imageSnapshot) {
                        if (imageSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final imageUrl = imageSnapshot.data;

                        // Create a tappable profile image
                        Widget profileImage;

                        if (imageUrl == null || imageUrl.isEmpty) {
                          profileImage = Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isBusiness ? const Color(0xFFE6C34E) : Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: borderColor,
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
                        } else {
                          profileImage = Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: borderColor,
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
                        }

                        // Wrap the profile image in a GestureDetector to show profile dialog on tap
                        return GestureDetector(
                          onTap: () => _showUserProfileDialog(context, _currentEvent.userId),
                          child: profileImage,
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
                            future: ref.read(eventUserServiceProvider).getUserDisplayName(_currentEvent.userId),
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
                            future: ref.read(eventUserServiceProvider).getUserUsername(_currentEvent.userId),
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

                    // QR Code button
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        _showQrCodeDialog(context, _currentEvent.id);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
              GestureDetector(
                onTap: _handleLike, // Like on tap
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildEventTypeImage(_currentEvent.activityType),
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
                        _currentEvent.activityType,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      '${DateFormatter.formatMonthShort(_currentEvent.date)} ${_currentEvent.date.day} @ ${_currentEvent.time.format(context)}',
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
                            ? "$attendeesCount/${_currentEvent.attendeeLimit} joined"
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

          // Event Inquiry with Invited flag if applicable
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show "Invited" flag if the user was invited to this event
                if (_currentEvent.isInvited)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5F7A).withAlpha(51), // 0.2 opacity = 51/255
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INVITED',
                      style: TextStyle(
                        color: Color(0xFF1A5F7A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Text(
                  _currentEvent.inquiry,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
                    onPressed: isEventCreator ? null : () => _handleIgnore(context), // Disable if user is event creator
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
                                builder: (context) => ChatRoomScreen(event: _currentEvent),
                              ),
                            );
                          } else if (value == 'manage') {
                            // Navigate to event management screen
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => EventManagementScreen(
                                  event: _currentEvent,
                                  onEventUpdated: (updatedEvent) {
                                    // Use a delayed callback to ensure we don't interfere with navigation
                                    Future.microtask(() {
                                      // Check if the widget is still mounted before updating state
                                      if (!mounted) {
                                        Logger.d('EventFeedCard', 'Widget not mounted in microtask, ignoring update callback');
                                        return;
                                      }

                                      try {
                                        // Log privacy changes for debugging
                                        if (_currentEvent.isPrivate != updatedEvent.isPrivate) {
                                          Logger.d('EventFeedCard', 'Privacy changed via callback: ${_currentEvent.isPrivate} -> ${updatedEvent.isPrivate}');
                                        }

                                        // Check mounted again right before setState
                                        if (mounted) {
                                          setState(() {
                                            _currentEvent = updatedEvent;
                                          });
                                          Logger.d('EventFeedCard', 'State updated via callback for event: ${updatedEvent.id}');
                                        }
                                      } catch (e) {
                                        Logger.e('EventFeedCard', 'Error updating state in callback: $e');
                                      }
                                    });
                                  },
                                  onEventDeleted: () {
                                    // The navigation to home screen is handled in the EventManagementScreen
                                    // This callback is still needed for the EventManagementScreen
                                    Logger.d('EventFeedCard', 'Event deleted callback triggered');
                                  },
                                ),
                              ),
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
                                    builder: (context) => ChatRoomScreen(event: _currentEvent),
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
