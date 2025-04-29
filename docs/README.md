# Yetu'ga App Documentation

## Overview

Yetu'ga is a social event platform that allows users to create, join, and manage events. The application supports both personal and business accounts, with features like event creation, invitation management, chat functionality, and user following.

## Architecture

The application follows a clean architecture approach with the following components:

### Core Layers

1. **UI Layer**: Screens and widgets for user interaction
2. **Provider Layer**: State management using Riverpod
3. **Service Layer**: Business logic and external service integration
4. **Model Layer**: Data models and entities
5. **Utility Layer**: Helper functions and utilities

### Key Components

- **Firebase Integration**: Authentication, Firestore database, Storage, and Messaging
- **Caching System**: Local caching using Hive and shared preferences
- **Retry Mechanism**: Robust retry logic for network operations
- **Offline Support**: Synchronization between local and remote data
- **Theme System**: Dynamic theming with light and dark mode support

## Services

### Authentication Services

- `AuthService`: Handles user authentication and session management
- `GoogleSignInService`: Provides Google authentication integration

### Data Services

- `FirebaseService`: Core Firebase operations and configuration
- `StorageService`: File storage and retrieval operations
- `EventService`: Event creation, retrieval, and management
- `RSVPService`: Event invitation and response management
- `UserSearchService`: User search functionality and follow management
- `ChatService`: Real-time messaging functionality
- `NotificationService`: User notifications and alerts

### Caching Services

- `CacheManager`: General-purpose caching utility with memory and disk layers
- `EventCacheService`: Specialized caching for event data
- `UserCacheService`: Caching user profiles for offline access
- `PrefetchService`: Proactive data loading based on user behavior

### Utility Services

- `RetryService`: Robust retry logic for network operations
- `BatchService`: Batch operations for Firestore
- `CacheManager`: General-purpose caching utility
- `PrefetchService`: Prefetching data for improved performance
- `SyncService`: Synchronization between local and remote data

## Models

- `OnboardingData`: User onboarding information for personal accounts
- `BusinessOnboardingData`: Onboarding information for business accounts
- `EventModel`: Event data structure
- `ChatMessage`: Message structure for chat functionality
- `NotificationModel`: User notification structure
- `RSVPModel`: Event invitation and response data

## Screens

### Authentication

- `AuthScreen`: Main authentication screen
- `CreateAccountScreen`: Account creation flow
- `EmailSignInScreen`: Email-based authentication

### Onboarding

- `OnboardingScreen`: Main onboarding flow controller
- Onboarding steps:
  - Account type selection
  - Display name and username
  - Birthday/Established date
  - Phone number
  - Profile image
  - Interests/Business types

### Main App

- `HomeScreen`: Main application screen with event feed
- `SearchScreen`: Dual-tab search for events and users
- `ProfileScreen`: User profile management
- `NotificationsScreen`: User notifications
- `ChatRoomScreen`: Messaging interface
- `QRScannerScreen`: QR code scanning functionality
- `ThemeSettingsScreen`: Theme customization

## Providers

- `AuthProvider`: Authentication state management
- `OnboardingProvider`: Onboarding flow state
- `OnboardingFormProvider`: Form state for personal accounts
- `BusinessOnboardingFormProvider`: Form state for business accounts
- `ThemeProvider`: Theme state management
- `StorageProvider`: File storage state
- `UserCacheProvider`: User data caching

## Utilities

- `Logger`: Structured logging utility
- `DateFormatter`: Date formatting and manipulation
- `PasswordValidator`: Password validation logic

## Testing

The application includes test screens for various components:

- `TestMenuScreen`: Entry point for test functionality
- `CacheTestScreen`: Testing cache operations
- `PrefetchTestScreen`: Testing data prefetching
- `RetryTestScreen`: Testing retry mechanisms

## Best Practices

### Error Handling

- Use the `RetryService` for network operations
- Implement proper error boundaries in widgets
- Provide user-friendly error messages
- Log errors with appropriate context

### Performance Optimization

- Use the `CacheManager` for frequently accessed data
- Leverage `Hive` for complex data structures and offline access
- Implement specialized caching with `EventCacheService` and `UserCacheService`
- Use `PrefetchService` to proactively load data based on user behavior
- Implement pagination for large data sets
- Optimize image loading with `CachedNetworkImage`
- Use batch operations for multiple Firestore updates

### Security

- Implement proper Firestore security rules
- Validate user input on both client and server
- Use Firebase Authentication for secure user management
- Implement proper access control for private events

## Getting Started

### Prerequisites

- Flutter SDK (version 3.2.3 or higher)
- Firebase project setup
- Android Studio or VS Code with Flutter extensions

### Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase using the provided `firebase_options.dart`
4. Run the application with `flutter run`

### Configuration

- Update `firebase_options.dart` with your Firebase project details
- Configure theme colors in `app_theme.dart`
- Set up Firebase Authentication providers in Firebase Console

## Documentation

Detailed documentation for specific components:

### Services
- [RetryService Documentation](services/retry_service.md)
- [CacheManager Documentation](services/cache_manager.md)
- [EventService Documentation](services/event_service.md)
- [RSVPService Documentation](services/rsvp_service.md)

### Components
- [NotificationBadge Component](components/notification_badge.md)
- [Event Card Images](components/event_card_images.md)

### Technical Implementation
- [PageController Implementation](technical/page_controller_implementation.md)
- [Search Implementation](technical/search_implementation.md)

### Best Practices
- [Async Context Usage](best_practices/async_context_usage.md)

### Features
- [Search Functionality](search_functionality.md)
- [Search Quick Reference](guides/search_quick_reference.md)
- [Authentication Flow](auth/authentication_flow.md)
- [Onboarding Process](onboarding/onboarding_process.md)

### Design
- [Theme System](theme/theme_system.md)
- [Design Patterns and Colors](design/design_patterns_and_colors.md)
- [Visual Style Guide](design/visual_style_guide.md)
- [Component Guidelines](design/component_guidelines.md)

## Contributing

1. Follow the established architecture patterns
2. Write tests for new functionality
3. Document new features and changes
4. Follow the Flutter style guide
5. Use the provided utilities for common operations
