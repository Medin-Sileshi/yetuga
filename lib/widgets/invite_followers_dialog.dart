import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/follow_service.dart';
import '../services/invitation_service.dart';
import '../utils/logger.dart';

class InviteFollowersDialog extends ConsumerStatefulWidget {
  final String? eventId; // Optional - if null, we're creating a new event
  final Function(List<String>)? onInviteSelected; // Callback for pre-creation invites

  const InviteFollowersDialog({
    Key? key,
    this.eventId,
    this.onInviteSelected,
  }) : super(key: key);

  @override
  ConsumerState<InviteFollowersDialog> createState() => _InviteFollowersDialogState();
}

class _InviteFollowersDialogState extends ConsumerState<InviteFollowersDialog> {
  List<Map<String, dynamic>> _following = [];
  List<String> _selectedUserIds = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Load following list after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowing();
    });
  }

  Future<void> _loadFollowing() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final followService = ref.read(followServiceProvider);
      final auth = FirebaseAuth.instance;
      final currentUserId = auth.currentUser?.uid ?? '';

      if (currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Get the first batch of following users
      final followingStream = followService.getFollowing(currentUserId);
      final following = await followingStream.first;

      // Filter out business accounts - only show personal accounts
      final personalAccounts = following.where((user) {
        return user['accountType'] == 'personal';
      }).toList();

      setState(() {
        _following = personalAccounts;
        _isLoading = false;
      });

      // If not following anyone, show an alert and close the dialog
      if (personalAccounts.isEmpty) {
        // Use a short delay to ensure the state is updated first
        Future.microtask(() {
          if (!mounted) return;

          // Show the alert dialog
          _showNoFollowersAlert();
        });
      }
    } catch (e) {
      Logger.e('InviteFollowersDialog', 'Error loading following', e);
      setState(() {
        _errorMessage = 'Failed to load following: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Show alert when user is not following anyone
  void _showNoFollowersAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Followers'),
        content: const Text('You are not following any personal accounts. Only personal accounts can be invited to private events.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the alert
              Navigator.of(context).pop(false); // Close the invite dialog
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _sendInvitations() async {
    if (_selectedUserIds.isEmpty) return;

    try {
      setState(() {
        _isSending = true;
        _errorMessage = null;
      });

      // If we have an event ID, send invitations directly
      if (widget.eventId != null && widget.eventId!.isNotEmpty) {
        final invitationService = ref.read(invitationServiceProvider);

        // Send invitations to all selected users
        for (final userId in _selectedUserIds) {
          await invitationService.sendInvitation(widget.eventId!, userId);
        }

        Logger.d('InviteFollowersDialog', 'Sent invitations for existing event ${widget.eventId}');
      } else {
        // If we're creating a new event, call the callback with selected user IDs
        if (widget.onInviteSelected != null) {
          Logger.d('InviteFollowersDialog', 'Calling onInviteSelected with ${_selectedUserIds.length} users');
          widget.onInviteSelected!(_selectedUserIds);
        } else {
          Logger.e('InviteFollowersDialog', 'No callback provided for pre-creation invites');
        }
      }

      // Close the dialog
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.e('InviteFollowersDialog', 'Error handling invitations', e);
      setState(() {
        _errorMessage = 'Failed to process invitations: ${e.toString()}';
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 500,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Center(
              child: Text(
                widget.eventId != null ? 'Invite Followers' : 'Select Invitees',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.eventId != null
                ? 'Select people to invite to your event'
                : 'Select people to invite to your private event',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Loading indicator or list of followers
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _following.isEmpty
                      ? Center(
                          child: Text(
                            'You are not following anyone yet',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _following.length,
                          itemBuilder: (context, index) {
                            final user = _following[index];
                            final userId = user['userId'] as String;
                            final displayName = user['displayName'] as String;
                            final username = user['username'] as String;
                            final profileImageUrl = user['profileImageUrl'] as String?;
                            final isSelected = _selectedUserIds.contains(userId);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                                child: profileImageUrl == null || profileImageUrl.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(displayName),
                              subtitle: Text('@$username'),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (value) => _toggleUserSelection(userId),
                              ),
                              onTap: () => _toggleUserSelection(userId),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(80, 36), // Set minimum width and height
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending || _selectedUserIds.isEmpty
                      ? null
                      : _sendInvitations,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 36), // Set minimum width and height
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.eventId != null
                          ? 'Invite (${_selectedUserIds.length})'
                          : 'Continue (${_selectedUserIds.length})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
