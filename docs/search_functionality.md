# Search Functionality Documentation

## Overview

The Yetu'ga app includes a comprehensive search functionality that allows users to search for both events and users. The search screen provides a dual-tab interface with separate search capabilities for each content type.

## Features

### 1. Dual Search Capability
- **Events Search**: Search for events by name, description, or activity type
- **Users Search**: Search for other users by display name or username

### 2. Tab Navigation
- Switch between Events and Users tabs using the tab bar at the top
- Each tab maintains its own search state and results
- Swipe functionality is disabled to provide a more controlled navigation experience

### 3. Activity Type Filtering
- Filter events by activity type (Celebrate, Drink, Eating, etc.)
- Activity type filter is only shown when in the Events tab
- Selecting an activity type automatically triggers a search

### 4. User Interaction
- **Follow/Unfollow**: Follow or unfollow users directly from search results
- **Profile Navigation**: Tap on a user to view their full profile
- **Event Interaction**: Join or ignore events directly from search results

### 5. Visual Feedback
- Custom styling for business accounts (gold borders)
- Visual indication of selected tabs and filters
- Loading indicators during search operations

## Implementation Details

### Search Screen Structure
The search screen is implemented in `lib/screens/search_screen.dart` and uses the following key components:

1. **Tab Controller**: Manages the tab state and navigation
2. **IndexedStack**: Displays the appropriate content based on the selected tab
3. **Custom Tab Bar**: Provides visual feedback and handles tab switching
4. **Search Controller**: Manages the search input and triggers searches

### Search Logic
The search functionality is implemented with these key methods:

1. `_performSearch()`: Executes the search based on the current tab and query
2. `_onTabChanged()`: Handles tab switching and triggers appropriate searches
3. `_onSearchChanged()`: Responds to changes in the search input

### User Search Service
The user search functionality is implemented in `lib/services/user_search_service.dart` and provides:

1. Searching users by display name or username
2. Following and unfollowing users
3. Retrieving user information including profile images and account types

### Event Search Service
The event search functionality is part of the EventService and provides:

1. Searching events by text query and activity type
2. Filtering based on privacy settings
3. Sorting results by relevance and recency

## Usage

1. **Basic Search**:
   - Enter text in the search field at the top of the screen
   - Results will update automatically as you type

2. **Switching Tabs**:
   - Tap on the "EVENTS" or "USERS" tab to switch between search types
   - Each tab maintains its own search state

3. **Filtering Events**:
   - When in the Events tab, select an activity type from the horizontal list
   - Results will update automatically based on the selected filter

4. **Interacting with Results**:
   - For users: Tap the Follow/Unfollow button or tap the user card to view profile
   - For events: Tap Join to join an event or Ignore to remove it from results

## Error Handling

The search functionality includes robust error handling:

1. **Empty Queries**: Appropriate messages are shown when no search term is entered
2. **No Results**: Clear feedback when a search returns no results
3. **Network Errors**: Graceful handling of connection issues
4. **State Management**: Proper cleanup to prevent memory leaks

## Recent Updates

1. **Improved Tab Navigation**: Enhanced tab switching with better visual feedback
2. **Fixed User Search Display**: Resolved issues with displaying user search results
3. **Optimized Search Performance**: Improved search response time and result relevance
4. **Enhanced Error Handling**: Added better error recovery and user feedback
5. **Disabled Swipe Functionality**: Removed horizontal swipe gestures for more controlled navigation
6. **Added Detailed Logging**: Improved debugging capabilities with comprehensive logging
