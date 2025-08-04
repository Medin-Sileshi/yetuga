import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/notification_service.dart';
import 'notification_badge.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

class HomeHeader extends ConsumerStatefulWidget {
  final Function()? onMenuPressed;
  final Function()? onScanPressed;
  final Function(String) onFilterChanged;
  final String currentFilter;

  const HomeHeader({
    Key? key,
    this.onMenuPressed,
    this.onScanPressed,
    required this.onFilterChanged,
    required this.currentFilter,
  }) : super(key: key);

  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader> {
  bool _isOffline = false;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top row with hamburger menu and QR scanner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Hamburger menu with notification badge and offline indicator
              Row(
                children: [
                  StreamBuilder<int>(
                    stream: ref.read(notificationServiceProvider).getUnreadCount(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: widget.onMenuPressed,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 28,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              // Position the badge to overlap with the icon
                              right: 5,
                              top: 5,
                              child: NotificationBadge(
                                count: unreadCount,
                                size: 8.0,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  if (_isOffline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Offline',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),

              // QR code scanner
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: widget.onScanPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 28,
              ),
            ],
          ),
        ),

        // Filter tabs arranged horizontally
        Container(
          height: 60, // Taller height for larger text
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildFilterTab("JOINED", widget.currentFilter == "JOINED")),
              Expanded(child: _buildFilterTab("NEW", widget.currentFilter == "NEW")),
              Expanded(child: _buildFilterTab("SHOW ALL", widget.currentFilter == "SHOW ALL")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onFilterChanged(label),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            // Use theme's text color with appropriate opacity
            color: isSelected
              ? Theme.of(context).textTheme.bodyLarge?.color
              : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(128),
            fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300, // Bold for active, light for inactive
            fontSize: 22, // Even larger font size
            letterSpacing: 1.2, // Slightly spaced letters for better readability
          ),
        ),
      ),
    );
  }


}
