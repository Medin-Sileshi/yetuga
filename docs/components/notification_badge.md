# Notification Badge Component

## Overview

The NotificationBadge component provides a consistent way to display notification counts throughout the Yetu'ga application. It's designed to be reusable, customizable, and follows the app's design system.

## Implementation

The NotificationBadge is implemented as a stateless widget in `lib/widgets/notification_badge.dart`. It accepts parameters for count, size, and font size, making it adaptable to different UI contexts.

```dart
class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;
  final double fontSize;

  const NotificationBadge({
    Key? key,
    required this.count,
    this.size = 16.0,
    this.fontSize = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink(); // Don't show badge if count is 0
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
```

## Usage

The NotificationBadge is used in several places throughout the application:

### 1. Home Header (Hamburger Menu)

```dart
StreamBuilder<int>(
  stream: ref.read(notificationServiceProvider).getUnreadCount(),
  builder: (context, snapshot) {
    final unreadCount = snapshot.data ?? 0;

    return Stack(
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
            right: 0,
            top: 2,
            child: NotificationBadge(
              count: unreadCount,
              size: 12.0,
              fontSize: 10.0,
            ),
          ),
      ],
    );
  },
),
```

### 2. Drawer Notifications Button

```dart
StreamBuilder<int>(
  stream: ref.read(notificationServiceProvider).getUnreadCount(),
  builder: (context, snapshot) {
    final unreadCount = snapshot.data ?? 0;

    return ListTile(
      leading: Stack(
        children: [
          Icon(Icons.notifications, color: Theme.of(context).iconTheme.color),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: NotificationBadge(
                count: unreadCount,
                size: 16.0,
                fontSize: 10.0,
              ),
            ),
        ],
      ),
      title: Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          ),
        );
      },
    );
  },
),
```

### 3. Notification Item (Unread Indicator)

```dart
if (!isMarkedAsRead)
  const Padding(
    padding: EdgeInsets.only(top: 4.0),
    child: NotificationBadge(
      count: 1,
      size: 8.0,
      fontSize: 0.0, // No text, just a dot
    ),
  ),
```

## Customization

The NotificationBadge can be customized with the following parameters:

- **count**: The number to display in the badge. If greater than 9, it shows "9+".
- **size**: The size of the badge in logical pixels (default: 16.0).
- **fontSize**: The font size for the text (default: 10.0). Set to 0.0 to create a dot indicator with no text.

## Best Practices

1. **Consistency**: Use the NotificationBadge component for all notification indicators throughout the app.
2. **Accessibility**: Ensure the badge is large enough to be visible but not so large that it obscures other UI elements.
3. **Performance**: Use the StreamBuilder pattern to update the badge count in real-time.
4. **Context Awareness**: Adjust the size and fontSize based on the context where the badge is used.
