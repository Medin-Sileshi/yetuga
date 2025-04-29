# Event Card Images

## Overview

Event cards in the Yetu'ga application display images based on the event's activity type. The application uses a consistent naming convention for event card images, making it easy to add new event types or modify existing ones.

## Image Naming Convention

Event card images follow the naming convention:
```
[event-type]-Card.jpg
```

For example:
- `Celebrate-Card.jpg`
- `Drink-Card.jpg`
- `Eat-Card.jpg`
- `Play-Card.jpg`
- `Run-Card.jpg`
- `Visit-Card.jpg`
- `Walk-Card.jpg`
- `Watch-Card.jpg`

## Implementation

The `_buildEventTypeImage` method in the `EventFeedCard` widget handles the mapping of activity types to their corresponding images:

```dart
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
        }
        // Additional mappings...

        // Default to 'Celebrate' if no match is found
        return 'Celebrate';
      },
    );
  }

  // Construct the asset path following the naming convention '[event-type]-Card.jpg'
  final assetPath = 'assets/images/$normalizedType-Card.jpg';

  // Return the image widget
  return Image.asset(
    assetPath,
    fit: BoxFit.cover,
    // Error handling...
  );
}
```

## Activity Type Mapping

The implementation includes intelligent mapping of various activity descriptions to the standard event types:

| Input Contains | Mapped To |
|---------------|-----------|
| eat, food, dinner, lunch, restaurant | Eat |
| drink, coffee, bar | Drink |
| play, game, sport | Play |
| walk, hike | Walk |
| run, jog, marathon | Run |
| visit, tour, travel | Visit |
| celebrate, party, event | Celebrate |
| watch, movie, show, concert | Watch |

## Adding New Event Types

To add a new event type:

1. Create a new image following the naming convention `[NewType]-Card.jpg`
2. Place the image in the `assets/images/` directory
3. Add the new type to the `validTypes` list in the `_buildEventTypeImage` method
4. Add appropriate mappings for common variations of the new type

## Error Handling

If an image fails to load, a placeholder is displayed:

```dart
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
```

## Best Practices

1. **Consistent Naming**: Always follow the established naming convention for new event type images.
2. **Image Optimization**: Optimize images for mobile devices to reduce app size and improve loading times.
3. **Aspect Ratio**: Maintain a consistent aspect ratio (16:9) for all event card images.
4. **Fallback Handling**: Always provide fallback options for cases where images might not load.
5. **Logging**: Use logging to track image loading issues for debugging purposes.
