# Best Practices for BuildContext Usage Across Async Gaps

## Overview

Using BuildContext across asynchronous gaps in Flutter can lead to subtle bugs and crashes, especially when the widget is disposed before the async operation completes. This document outlines best practices for safely using BuildContext in asynchronous operations within the Yetu'ga application.

## The Problem

Consider the following code pattern:

```dart
Future<void> _someAsyncMethod() async {
  // Start an async operation
  await someAsyncOperation();
  
  // Use BuildContext after the async gap
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Operation completed')),
  );
}
```

This pattern is problematic because:
1. The widget might be disposed while `someAsyncOperation()` is still running
2. Using `context` after the async gap can lead to "mounted widget no longer in tree" errors
3. It can cause memory leaks by preventing widgets from being garbage collected

## Best Practices

### 1. Check if the Widget is Still Mounted

Always check if the widget is still mounted before using BuildContext after an async gap:

```dart
Future<void> _someAsyncMethod() async {
  await someAsyncOperation();
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operation completed')),
    );
  }
}
```

### 2. Capture Context-Dependent Values Before Async Gaps

Capture any context-dependent values before the async gap to avoid using context afterward:

```dart
Future<void> _someAsyncMethod() async {
  // Capture the ScaffoldMessenger before the async gap
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  await someAsyncOperation();
  
  if (mounted) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Operation completed')),
    );
  }
}
```

### 3. Use Riverpod for State Management

Leverage Riverpod for state management to reduce the need for BuildContext in async operations:

```dart
// Instead of directly updating UI from async methods
Future<void> _loadData() async {
  final data = await fetchData();
  
  // Update a provider instead of directly using context
  ref.read(dataProvider.notifier).updateData(data);
  
  // The UI will automatically update through the provider
}
```

### 4. Use Callbacks for UI Updates

Pass callbacks to methods that need to update the UI after async operations:

```dart
Future<void> _loadData(void Function(String) onComplete) async {
  final data = await fetchData();
  
  // Call the callback instead of directly using context
  onComplete(data);
}

// Usage
void _handleLoadData() {
  _loadData((data) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded: $data')),
      );
    }
  });
}
```

### 5. Use Post-Frame Callbacks for UI Updates

For operations that need to update the UI after the current frame:

```dart
void _updateUIAfterFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      // Safe to use context here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Frame completed')),
      );
    }
  });
}
```

## Implementation in Yetu'ga

The Yetu'ga application follows these best practices in several places:

### Example 1: Refreshing Events in HomeScreen

```dart
Future<void> _refreshEvents(String filter, EventService eventService) async {
  Logger.d('HomeScreen', 'Refreshing events for filter: $filter');
  
  try {
    // Async operations...
    
    // Proper context usage with mounted check and captured context
    if (mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error refreshing events: $e')),
      );
    }
  } catch (e) {
    Logger.e('HomeScreen', 'Error refreshing events', e);
  }
}
```

### Example 2: Checking Notifications in HomeScreen

```dart
Future<void> _checkForUnreadNotifications() async {
  try {
    // Async operations...
    
    // Update UI safely after async operation
    if (mounted) {
      setState(() {
        // Update state safely
      });
    }
  } catch (e) {
    Logger.e('HomeScreen', 'Error checking for unread notifications', e);
  }
}
```

## Common Pitfalls

### 1. Using BuildContext in Fire-and-Forget Operations

```dart
// Problematic: Fire-and-forget without checking mounted
void _saveData() {
  apiService.saveData().then((_) {
    // This might run after the widget is disposed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data saved')),
    );
  });
}

// Better: Check mounted status
void _saveData() {
  apiService.saveData().then((_) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data saved')),
      );
    }
  });
}
```

### 2. Nested Async Operations

```dart
// Problematic: Nested async operations with context usage
Future<void> _complexOperation() async {
  await operation1();
  
  // This might run after the widget is disposed
  await operation2(context);
  
  // This context usage is unsafe
  Navigator.of(context).pop();
}

// Better: Check mounted at each step
Future<void> _complexOperation() async {
  await operation1();
  
  if (!mounted) return;
  await operation2(context);
  
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

### 3. Forgetting to Check Mounted in Error Handlers

```dart
// Problematic: Missing mounted check in catch block
Future<void> _loadData() async {
  try {
    await apiService.fetchData();
  } catch (e) {
    // This might run after the widget is disposed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

// Better: Check mounted in catch block
Future<void> _loadData() async {
  try {
    await apiService.fetchData();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

## Conclusion

Following these best practices for BuildContext usage across async gaps will help prevent subtle bugs and crashes in the Yetu'ga application. Always check if the widget is still mounted before using BuildContext after an async operation, and consider capturing context-dependent values before async gaps when possible.
