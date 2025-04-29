# Yetu'ga - Social Event Platform

Yetu'ga is a social event platform that allows users to create, join, and manage events. The application supports both personal and business accounts, with features like event creation, invitation management, chat functionality, and user following.

## Features

- **User Accounts**: Support for both personal and business accounts
- **Event Management**: Create, join, and manage events
- **Search Functionality**: Search for events and users with advanced filtering
- **Chat System**: Real-time messaging between users
- **Notifications**: Push notifications for event invitations and updates
- **QR Codes**: Generate and scan QR codes for events and profiles
- **Offline Support**: Synchronization between local and remote data
- **Dynamic Theming**: Light and dark mode support
- **User Following**: Follow/unfollow other users and see their content
- **Robust Error Handling**: Graceful error recovery and improved app stability
- **Event QR Dialog**: Streamlined event viewing and joining via QR codes

## Documentation

Comprehensive documentation is available in the `docs` directory:

- [Project Overview](docs/README.md)
- [API Reference](docs/api/retry_service_api.md)
- [Guides and Tutorials](docs/guides/using_retry_service.md)
- [Service Documentation](docs/services/retry_service.md)
- [Component Documentation](docs/components/notification_badge.md)
- [Technical Implementation](docs/technical/page_controller_implementation.md)
- [Error Handling Improvements](docs/technical/error_handling_improvements.md)
- [Best Practices](docs/best_practices/async_context_usage.md)
- [Search Functionality](docs/search_functionality.md)
- [Design Patterns and Colors](docs/design/design_patterns_and_colors.md)
- [Visual Style Guide](docs/design/visual_style_guide.md)
- [Component Guidelines](docs/design/component_guidelines.md)

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
- **Caching System**: Comprehensive caching with Hive for complex data structures, in-memory caching, and prefetching
- **Retry Mechanism**: Robust retry logic for network operations
- **Offline Support**: Synchronization between local and remote data
- **Theme System**: Dynamic theming with light and dark mode support

## Contributing

1. Follow the established architecture patterns
2. Write tests for new functionality
3. Document new features and changes
4. Follow the Flutter style guide
5. Use the provided utilities for common operations

## License

This project is licensed under the MIT License - see the LICENSE file for details.
