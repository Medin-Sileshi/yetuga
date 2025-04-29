# Yetu'ga UI Component Guidelines

This document provides detailed guidelines for implementing specific UI components in the Yetu'ga application. It focuses on the implementation details, code examples, and best practices for each component.

## Table of Contents

1. [Buttons](#buttons)
2. [Input Fields](#input-fields)
3. [Cards](#cards)
4. [Tabs and Navigation](#tabs-and-navigation)
5. [Lists and Grids](#lists-and-grids)
6. [Dialogs and Modals](#dialogs-and-modals)
7. [Profile Elements](#profile-elements)
8. [Event-Specific Components](#event-specific-components)
9. [Search Components](#search-components)
10. [Theme-Aware Components](#theme-aware-components)

## Buttons

### Primary Button (Elevated)

Use for primary actions that drive the user forward in a flow.

```dart
ElevatedButton(
  onPressed: () {
    // Action
  },
  child: Text('Continue'),
)
```

The theme automatically applies:
- Border radius: 20px
- Padding: 16px vertical, 32px horizontal
- Text style: Medium (500), 16px
- Colors: Primary background with white text (light theme) or Secondary background with primary text (dark theme)

### Secondary Button (Outlined)

Use for secondary actions or alternatives to the primary action.

```dart
OutlinedButton(
  onPressed: () {
    // Action
  },
  child: Text('Cancel'),
)
```

The theme automatically applies:
- Border radius: 20px
- Border: 1px Primary (light theme) or Secondary (dark theme)
- Padding: 16px vertical, 32px horizontal
- Text style: Medium (500), 16px

### Tertiary Button (Text)

Use for low-emphasis actions or navigation.

```dart
TextButton(
  onPressed: () {
    // Action
  },
  child: Text('Learn More'),
)
```

The theme automatically applies:
- Text color: Secondary
- Text style: Regular (400), 14px
- No background or border

### Icon Button

Use for actions that can be represented by an icon.

```dart
IconButton(
  icon: Icon(Icons.favorite),
  onPressed: () {
    // Action
  },
)
```

### Follow/Unfollow Button

Special button for following/unfollowing users.

```dart
ElevatedButton(
  onPressed: () {
    // Toggle follow state
    setState(() {
      isFollowing = !isFollowing;
    });
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: isFollowing 
        ? Colors.grey.withAlpha(51) // 0.2 opacity
        : Theme.of(context).colorScheme.primary,
    foregroundColor: isFollowing 
        ? Theme.of(context).textTheme.bodyMedium?.color 
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  child: Text(isFollowing ? 'Unfollow' : 'Follow'),
)
```

## Input Fields

### Standard Text Field

Use for most text input needs.

```dart
TextField(
  controller: textController,
  decoration: InputDecoration(
    labelText: 'Display Name',
    hintText: 'Enter your display name',
  ),
)
```

The theme automatically applies:
- Border radius: 12px
- Border colors: Primary/White with Secondary focus
- Label styles: Light (300) for normal, Regular (400) for floating

### Search Field

Use for search functionality.

```dart
TextField(
  controller: searchController,
  decoration: InputDecoration(
    hintText: 'Search...',
    prefixIcon: Icon(Icons.search),
    border: InputBorder.none,
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Theme.of(context).dividerColor),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
    ),
  ),
  onChanged: (value) {
    // Perform search
  },
)
```

### Date Picker

Use for selecting dates.

```dart
// Show date picker
Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: selectedDate,
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Theme.of(context).colorScheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      );
    },
  );
  if (picked != null && picked != selectedDate) {
    setState(() {
      selectedDate = picked;
    });
  }
}
```

## Cards

### Event Card

Use for displaying events in feeds and search results.

```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  elevation: 2,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header with gradient
      Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          gradient: LinearGradient(
            colors: event.creatorType == 'business'
                ? [Color(0xFFC3922E), Color(0xFFEED688)]
                : [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          event.activityType,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // Event image
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          event.imageUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      
      // Event details
      Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 4),
            Text(
              '@${event.creatorUsername}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite, size: 16),
                SizedBox(width: 4),
                Text('${event.likes}'),
                SizedBox(width: 16),
                Icon(Icons.people, size: 16),
                SizedBox(width: 4),
                Text('${event.attendees}/${event.maxAttendees}'),
              ],
            ),
          ],
        ),
      ),
      
      // Actions
      Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: onJoin,
              child: Text('JOIN'),
            ),
            OutlinedButton(
              onPressed: onIgnore,
              child: Text('IGNORE'),
            ),
          ],
        ),
      ),
    ],
  ),
)
```

### User Card

Use for displaying users in search results and follower lists.

```dart
Card(
  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: user.id),
        ),
      );
    },
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Profile image with border
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: user.accountType == 'business'
                    ? Color(0xFFC3922E) // Gold
                    : Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Text(user.displayName[0].toUpperCase())
                  : null,
            ),
          ),
          SizedBox(width: 16),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(179), // 0.7 opacity
                  ),
                ),
              ],
            ),
          ),
          
          // Follow/Unfollow button
          ElevatedButton(
            onPressed: () {
              // Toggle follow state
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isFollowing
                  ? Colors.grey.withAlpha(51) // 0.2 opacity
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: user.isFollowing
                  ? Theme.of(context).textTheme.bodyMedium?.color
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(user.isFollowing ? 'Unfollow' : 'Follow'),
          ),
        ],
      ),
    ),
  ),
)
```

## Tabs and Navigation

### Custom Tab Bar

Use for switching between content sections.

```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // First tab
      GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = 0;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'EVENTS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.w300,
              color: _currentIndex == 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(153), // 0.6 opacity
            ),
          ),
        ),
      ),
      
      // Second tab
      GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = 1;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'USERS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.w300,
              color: _currentIndex == 1
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(153), // 0.6 opacity
            ),
          ),
        ),
      ),
    ],
  ),
)
```

### Filter Tabs

Use for filtering content by category.

```dart
Container(
  height: 50,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: categories.map((category) {
        final isSelected = category == selectedCategory;
        
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = category;
              });
              // Apply filter
            },
            child: Text(
              category,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(153), // 0.6 opacity
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w300,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  ),
)
```

### IndexedStack for Tab Content

Use for displaying content based on selected tab without losing state.

```dart
IndexedStack(
  index: _currentIndex,
  children: [
    // First tab content
    ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) => EventCard(event: events[index]),
    ),
    
    // Second tab content
    ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => UserCard(user: users[index]),
    ),
  ],
)
```

## Lists and Grids

### Event List

Use for displaying a list of events.

```dart
ListView.builder(
  padding: const EdgeInsets.all(8),
  itemCount: events.length,
  itemBuilder: (context, index) {
    final event = events[index];
    return EventCard(
      event: event,
      onJoin: () {
        // Join event
      },
      onIgnore: () {
        // Ignore event
      },
    );
  },
)
```

### User List

Use for displaying a list of users.

```dart
ListView.builder(
  padding: const EdgeInsets.all(8),
  itemCount: users.length,
  itemBuilder: (context, index) {
    final user = users[index];
    return UserCard(
      user: user,
      onFollow: () {
        // Follow/unfollow user
      },
    );
  },
)
```

### Grid Layout

Use for displaying content in a grid.

```dart
GridView.builder(
  padding: const EdgeInsets.all(8),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.75,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item content
        ],
      ),
    );
  },
)
```

## Dialogs and Modals

### Alert Dialog

Use for confirmations, warnings, and errors.

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Confirm Action'),
    content: Text('Are you sure you want to proceed?'),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text('CANCEL'),
      ),
      ElevatedButton(
        onPressed: () {
          // Perform action
          Navigator.of(context).pop();
        },
        child: Text('CONFIRM'),
      ),
    ],
  ),
);
```

### Modal Bottom Sheet

Use for additional options or detailed views.

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    expand: false,
    builder: (context, scrollController) => Column(
      children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Title
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Modal Title',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        
        // Content
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.all(16),
            children: [
              // Modal content
            ],
          ),
        ),
      ],
    ),
  ),
);
```

## Profile Elements

### Profile Header

Use for displaying user profile information.

```dart
Container(
  padding: EdgeInsets.all(16),
  child: Column(
    children: [
      // Profile image with border
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: user.accountType == 'business'
                ? Color(0xFFC3922E) // Gold
                : Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 50,
          backgroundImage: user.profileImageUrl != null
              ? NetworkImage(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl == null
              ? Text(
                  user.displayName[0].toUpperCase(),
                  style: TextStyle(fontSize: 32),
                )
              : null,
        ),
      ),
      SizedBox(height: 16),
      
      // User info
      Text(
        user.displayName,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      SizedBox(height: 4),
      Text(
        '@${user.username}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      SizedBox(height: 16),
      
      // Stats
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat('Events', user.eventCount.toString()),
          _buildStat('Following', user.followingCount.toString()),
          _buildStat('Followers', user.followerCount.toString()),
        ],
      ),
      SizedBox(height: 16),
      
      // Follow button
      if (user.id != currentUserId)
        ElevatedButton(
          onPressed: () {
            // Toggle follow state
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: user.isFollowing
                ? Colors.grey.withAlpha(51) // 0.2 opacity
                : Theme.of(context).colorScheme.primary,
            foregroundColor: user.isFollowing
                ? Theme.of(context).textTheme.bodyMedium?.color
                : Colors.white,
          ),
          child: Text(user.isFollowing ? 'Unfollow' : 'Follow'),
        ),
    ],
  ),
)
```

### Profile Stat

Helper method for profile stats.

```dart
Widget _buildStat(String label, String value) {
  return Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(179), // 0.7 opacity
        ),
      ),
    ],
  );
}
```

## Event-Specific Components

### Join Button States

Different states for the join button based on event status.

```dart
Widget _buildJoinButton(EventModel event) {
  // If user is the creator
  if (event.creatorId == currentUserId) {
    return ElevatedButton(
      onPressed: () {
        // Navigate to chat
      },
      child: Text('CHAT'),
    );
  }
  
  // If event is full
  if (event.attendees >= event.maxAttendees) {
    return ElevatedButton(
      onPressed: null, // Disabled
      child: Text('FULL'),
    );
  }
  
  // If user has a pending request
  if (event.isPendingRequest) {
    return ElevatedButton(
      onPressed: null, // Disabled
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
      ),
      child: Text('PENDING'),
    );
  }
  
  // If user has been denied
  if (event.isDenied) {
    return ElevatedButton(
      onPressed: null, // Disabled
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
      ),
      child: Text('DENIED'),
    );
  }
  
  // If user has joined
  if (event.isJoined) {
    return ElevatedButton(
      onPressed: () {
        // Navigate to chat
      },
      child: Text('CHAT'),
    );
  }
  
  // Default: can join
  return ElevatedButton(
    onPressed: () {
      // Join event
    },
    child: Text('JOIN'),
  );
}
```

### Event QR Code

Generate and display QR code for an event.

```dart
Container(
  padding: EdgeInsets.all(16),
  child: Column(
    children: [
      Text(
        'Event QR Code',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      SizedBox(height: 16),
      QrImage(
        data: 'event:${event.id}',
        version: QrVersions.auto,
        size: 200,
        backgroundColor: Colors.white,
      ),
      SizedBox(height: 16),
      ElevatedButton.icon(
        icon: Icon(Icons.download),
        label: Text('Download'),
        onPressed: () {
          // Download QR code
        },
      ),
    ],
  ),
)
```

## Search Components

### Search Bar

Use for search functionality.

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    children: [
      Icon(
        Icons.search,
        color: Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(153), // 0.6 opacity
        size: 24,
      ),
      SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: searchController,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(153), // 0.6 opacity
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            // Perform search
          },
        ),
      ),
      if (searchController.text.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear),
          onPressed: () {
            searchController.clear();
            // Clear search results
          },
        ),
    ],
  ),
)
```

### Search Results

Use for displaying search results with proper empty states.

```dart
Expanded(
  child: isSearching
      ? Center(child: CircularProgressIndicator())
      : results.isEmpty
          ? Center(
              child: searchQuery.isEmpty
                  ? Text('Enter a search term')
                  : Text('No results found'),
            )
          : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                // Return appropriate card based on result type
                return result is EventModel
                    ? EventCard(event: result)
                    : UserCard(user: result);
              },
            ),
)
```

## Theme-Aware Components

### Theme-Aware Card

Use for cards that adapt to the current theme.

```dart
Card(
  color: Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : Theme.of(context).colorScheme.surface,
  elevation: Theme.of(context).brightness == Brightness.light ? 2 : 1,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card content
      ],
    ),
  ),
)
```

### Theme-Aware Divider

Use for dividers that adapt to the current theme.

```dart
Divider(
  color: Theme.of(context).brightness == Brightness.light
      ? Color(0xFFE0E0E0) // Light gray
      : Color(0xFF2C2C2E), // Dark gray
  thickness: 1,
)
```

### Theme-Aware Icon

Use for icons that adapt to the current theme.

```dart
Icon(
  Icons.favorite,
  color: Theme.of(context).brightness == Brightness.light
      ? Theme.of(context).colorScheme.primary
      : Theme.of(context).colorScheme.secondary,
  size: 24,
)
```

## Conclusion

This component guide provides detailed implementation examples for the UI components used in the Yetu'ga application. By following these guidelines, you can ensure consistent styling and behavior across the app.

Remember to:
1. Use theme properties instead of hardcoded values
2. Follow the established design patterns
3. Ensure components adapt properly to both light and dark themes
4. Maintain consistent spacing and sizing
5. Use the appropriate styles for different account types
