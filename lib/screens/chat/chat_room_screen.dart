import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../../models/event_model.dart';
import '../../services/chat_service.dart';
import '../../services/event_user_service.dart';
import '../../utils/logger.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const ChatRoomScreen({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // For reply functionality
  ChatMessage? _replyToMessage;

  // For edit functionality
  ChatMessage? _editingMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // No UI state change for loading
    try {
      final chatService = ref.read(chatServiceProvider);

      // First check if the user can access this chat
      final canAccess = await chatService.canAccessChat(widget.event);
      if (!canAccess) {
        throw Exception('You do not have permission to send messages in this chat');
      }

      // Check if we're editing an existing message
      if (_editingMessage != null) {
        await chatService.editMessage(widget.event.id, _editingMessage!.id, message);
        _cancelEditing();
      } else {
        // Send a new message (with reply info if applicable)
        await chatService.sendMessage(
          widget.event.id,
          message,
          replyToId: _replyToMessage?.id,
          replyToSenderName: _replyToMessage?.senderName,
          replyToMessage: _replyToMessage?.message,
        );
        _cancelReply();
      }

      _messageController.clear();
    } catch (e) {
      Logger.e('ChatRoomScreen', 'Error sending message', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Set up a reply to a message
  void _setReplyTo(ChatMessage message) {
    setState(() {
      _replyToMessage = message;
      _editingMessage = null; // Cancel any ongoing edits
    });

    // Focus the text field for immediate reply
    FocusScope.of(context).requestFocus(FocusNode());
  }

  // Cancel the current reply
  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  // Start editing a message
  void _startEditing(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _replyToMessage = null; // Cancel any ongoing replies
      _messageController.text = message.message;
    });
    // Focus the text field and select all text for easy editing
    FocusScope.of(context).requestFocus(FocusNode());
  }

  // Cancel the current edit
  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  // Delete a message
  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.deleteMessage(widget.event.id, message.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      Logger.e('ChatRoomScreen', 'Error deleting message', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // Today, show time only
      return DateFormat.jm().format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday, ${DateFormat.jm().format(timestamp)}';
    } else {
      // Other days
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  @override
  void initState() {
    super.initState();
    // Check if the user can access this chat
    _checkChatAccess();
  }

  // Check access in the background without showing a loading screen
  Future<void> _checkChatAccess() async {
    // Don't block the UI while checking access
    Future.microtask(() async {
      try {
        final chatService = ref.read(chatServiceProvider);
        final canAccess = await chatService.canAccessChat(widget.event);

        if (!canAccess && mounted) {
          // Show error and navigate back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to access this chat.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        Logger.e('ChatRoomScreen', 'Error checking chat access', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    });
  }

  // Show message options dialog
  void _showMessageOptions(ChatMessage message, bool isCurrentUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Reply'),
            onTap: () {
              Navigator.pop(context);
              _setReplyTo(message);
            },
          ),
          if (isCurrentUser) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _startEditing(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatService = ref.read(chatServiceProvider);
    final currentUserId = chatService.getCurrentUserId();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.event.inquiry,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.appBarTheme.foregroundColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.event.activityType,
              style: TextStyle(
                fontSize: 12,
                color: theme.appBarTheme.foregroundColor?.withAlpha(179), // ~0.7 opacity
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show event details
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildEventDetailsSheet(context),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Reply to message indicator
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: theme.colorScheme.primary.withAlpha(26), // ~0.1 opacity
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${_replyToMessage!.senderName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyToMessage!.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(179), // ~0.7 opacity
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelReply,
                    iconSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),

          // Editing message indicator
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: theme.colorScheme.secondary.withAlpha(26), // ~0.1 opacity
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Editing message',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelEditing,
                    iconSize: 16,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatService.getMessages(widget.event.id),
              builder: (context, snapshot) {
                // Don't show loading indicator for waiting state - keep showing existing messages
                // This prevents full-screen loading when sending messages or performing other actions

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.colorScheme.primary.withAlpha(128), // ~0.5 opacity
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(179), // ~0.7 opacity
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to send a message!',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(128), // ~0.5 opacity
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.senderId == currentUserId;

                    return _buildMessageBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                      theme: theme,
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13), // ~0.05 opacity
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Message input field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _editingMessage != null
                          ? 'Edit message...'
                          : _replyToMessage != null
                              ? 'Reply to ${_replyToMessage!.senderName}...'
                              : 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? Colors.grey[200]
                          : Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Material(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _editingMessage != null ? Icons.check : Icons.send,
                        color: theme.colorScheme.onPrimary,
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

  Widget _buildMessageBubble({
    required ChatMessage message,
    required bool isCurrentUser,
    required ThemeData theme,
  }) {
    // Get the EventUserService to check if the sender is a business account
    final eventUserService = ref.read(eventUserServiceProvider);

    // Create the message content widget
    Widget buildMessageContent() {
      return FutureBuilder<bool>(
        future: eventUserService.isBusinessAccount(message.senderId),
        builder: (context, snapshot) {
          final isBusiness = snapshot.data ?? false;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Reply indicator if this message is a reply
                if (message.replyToMessage != null)
                  Container(
                    margin: EdgeInsets.only(
                      left: isCurrentUser ? 0 : 40,
                      right: isCurrentUser ? 8 : 0,
                      bottom: 4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(26), // ~0.1 opacity
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.reply, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Reply to ${message.replyToSenderName}: ${message.replyToMessage}',
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main message bubble
                Row(
                  mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isCurrentUser) ...[
                      _buildUserAvatar(message.senderId, theme),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: isBusiness && !isCurrentUser
                          // For business accounts, use our custom frosted glass bubble
                          ? _buildBusinessChatBubble(message: message, theme: theme)
                          // For personal accounts or current user, use regular container
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                // For personal accounts or current user, use the regular color
                                color: isCurrentUser
                                    ? theme.colorScheme.primary
                                    : theme.brightness == Brightness.light
                                        ? Colors.grey[200]
                                        : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomLeft: isCurrentUser ? const Radius.circular(16) : const Radius.circular(0),
                                  bottomRight: isCurrentUser ? const Radius.circular(0) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        message.senderName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.brightness == Brightness.light
                                              ? Colors.black.withAlpha(179) // ~0.7 opacity
                                              : Colors.white.withAlpha(179), // ~0.7 opacity
                                        ),
                                      ),
                                    ),
                                  Text(
                                    message.message,
                                    style: TextStyle(
                                      color: isCurrentUser
                                          ? theme.colorScheme.onPrimary
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimestamp(message.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isCurrentUser
                                              ? theme.colorScheme.onPrimary.withAlpha(179) // ~0.7 opacity
                                              : theme.textTheme.bodySmall?.color?.withAlpha(179), // ~0.7 opacity
                                        ),
                                      ),
                                      if (message.isEdited) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '(edited)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: isCurrentUser
                                                ? theme.colorScheme.onPrimary.withAlpha(179) // ~0.7 opacity
                                                : theme.textTheme.bodySmall?.color?.withAlpha(179), // ~0.7 opacity
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (isCurrentUser) const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    final messageContent = buildMessageContent();

    // For other users' messages, use Dismissible with opposite direction
    if (!isCurrentUser) {
      return Dismissible(
        key: Key('dismissible-${message.id}'),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          color: theme.colorScheme.primary.withAlpha(51), // ~0.2 opacity
          child: Icon(
            Icons.reply,
            color: theme.colorScheme.primary,
          ),
        ),
        direction: DismissDirection.endToStart, // Left to right for other users' messages
        dismissThresholds: const {DismissDirection.endToStart: 0.2},
        movementDuration: const Duration(milliseconds: 200),
        resizeDuration: null, // Disable resize animation
        onDismissed: (_) {
          // This should never be called because confirmDismiss returns false
        },
        confirmDismiss: (_) async {
          // Trigger reply action
          _setReplyTo(message);
          // Don't actually dismiss the message
          return false;
        },
        child: GestureDetector(
          onTap: () => _showMessageOptions(message, isCurrentUser),
          child: messageContent,
        ),
      );
    }

    // For current user's messages, use Dismissible for swipe-to-reply
    return Dismissible(
      key: Key('dismissible-${message.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        color: theme.colorScheme.primary.withAlpha(51), // ~0.2 opacity
        child: Icon(
          Icons.reply,
          color: theme.colorScheme.primary,
        ),
      ),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.2},
      movementDuration: const Duration(milliseconds: 200),
      resizeDuration: null, // Disable resize animation
      onDismissed: (_) {
        // This should never be called because confirmDismiss returns false
      },
      confirmDismiss: (_) async {
        // Trigger reply action
        _setReplyTo(message);
        // Don't actually dismiss the message
        return false;
      },
      child: GestureDetector(
        onTap: () => _showMessageOptions(message, isCurrentUser),
        child: messageContent,
      ),
    );
  }

  Widget _buildEventDetailsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;

    // Format date and time
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final timeFormat = DateFormat('h:mm a');
    final formattedDate = dateFormat.format(event.date);
    final formattedTime = timeFormat.format(DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.time.hour,
      event.time.minute,
    ));

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Event Details',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            context,
            Icons.category,
            'Activity Type',
            event.activityType,
          ),
          const Divider(),
          _buildDetailRow(
            context,
            Icons.help_outline,
            'Inquiry',
            event.inquiry,
          ),
          const Divider(),
          _buildDetailRow(
            context,
            Icons.calendar_today,
            'Date',
            formattedDate,
          ),
          const Divider(),
          _buildDetailRow(
            context,
            Icons.access_time,
            'Time',
            formattedTime,
          ),
          const Divider(),
          _buildDetailRow(
            context,
            Icons.people,
            'Attendees',
            '${event.joinedBy.length}${event.attendeeLimit != null ? ' / ${event.attendeeLimit}' : ''}',
          ),
          const Divider(),
          _buildDetailRow(
            context,
            Icons.visibility,
            'Visibility',
            event.isPrivate ? 'Private' : 'Public',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withAlpha(179), // ~0.7 opacity
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a business account chat bubble with subtle gradient fadeout effect
  Widget _buildBusinessChatBubble({
    required ChatMessage message,
    required ThemeData theme,
  }) {
    // Get text color based on theme
    final textColor = theme.brightness == Brightness.light
        ? Colors.black
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        // Subtle golden gradient with pronounced fadeout effect
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE6C34E).withAlpha(102), // ~0.4 opacity Rich Gold (more vibrant)
            const Color(0xFFFFD700).withAlpha(77), // ~0.3 opacity Pure Gold (medium)
            const Color(0xFFFFF8E1).withAlpha(26), // ~0.1 opacity Light Gold (extreme fadeout)
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomLeft: const Radius.circular(0),
        ),
        // Very subtle glow
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6C34E).withAlpha(77), // ~0.3 opacity
            blurRadius: 6,
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              message.senderName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
          // Message text
          Text(
            message.message,
            style: TextStyle(
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          // Timestamp and edited indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withAlpha(179), // ~0.7 opacity
                ),
              ),
              if (message.isEdited) ...[
                const SizedBox(width: 4),
                Text(
                  '(edited)',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: textColor.withAlpha(179), // ~0.7 opacity
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Build user avatar with profile image and account type-based border
  Widget _buildUserAvatar(String userId, ThemeData theme) {
    final eventUserService = ref.read(eventUserServiceProvider);

    return FutureBuilder<bool>(
      future: eventUserService.isBusinessAccount(userId),
      builder: (context, businessSnapshot) {
        final isBusiness = businessSnapshot.data ?? false;
        final borderColor = isBusiness
            ? const Color(0xFFE6C34E) // Rich Gold color for business accounts
            : theme.colorScheme.secondary;

        return FutureBuilder<String?>(
          future: eventUserService.getUserProfileImageUrl(userId),
          builder: (context, imageSnapshot) {
            if (imageSnapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              );
            }

            final imageUrl = imageSnapshot.data;

            // Container with border based on account type
            return Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
                // Add subtle glow for business accounts
                boxShadow: isBusiness
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE6C34E).withAlpha(128), // ~0.5 opacity
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        placeholder: (context, url) => CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        fit: BoxFit.cover,
                        width: 32,
                        height: 32,
                        cacheKey: '${userId}_profile_image',
                      )
                    : Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
