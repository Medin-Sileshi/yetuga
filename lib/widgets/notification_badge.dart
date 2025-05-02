import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;
  final double fontSize;
  final bool showCount;

  const NotificationBadge({
    Key? key,
    required this.count,
    this.size = 8.0,
    this.fontSize = 0.0,
    this.showCount = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink(); // Don't show badge if count is 0
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: showCount
          ? Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }
}
