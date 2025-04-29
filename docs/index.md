# Yetu'ga App Documentation

Welcome to the Yetu'ga app documentation. This documentation provides comprehensive information about the application's architecture, components, and usage guidelines.

## Getting Started

- [Project Overview](README.md)
- [Architecture Overview](architecture/overview.md)
- [Development Setup](setup/development_setup.md)

## Core Components

### Services

- [RetryService](services/retry_service.md) - Robust retry logic for network operations
- [BatchService](services/batch_service.md) - Efficient batch operations for Firestore
- [Caching System](services/caching_system.md) - Comprehensive caching with Hive and in-memory storage
- [EventService](services/event_service.md) - Event management
- [RSVPService](services/rsvp_service.md) - Event invitation and response management
- [AuthService](services/auth_service.md) - Authentication and user management
- [ChatService](services/chat_service.md) - Real-time messaging
- [NotificationService](services/notification_service.md) - User notifications
- [SyncService](services/sync_service.md) - Data synchronization

### Components

- [NotificationBadge](components/notification_badge.md) - Consistent notification indicator component
- [Event Card Images](components/event_card_images.md) - Event card image implementation

### Utilities

- [Logger](utils/logger.md) - Structured logging utility
- [DateFormatter](utils/date_formatter.md) - Date formatting and manipulation
- [PasswordValidator](utils/password_validator.md) - Password validation

### Models

- [EventModel](models/event_model.md) - Event data structure
- [OnboardingData](models/onboarding_data.md) - User onboarding information
- [ChatMessage](models/chat_message.md) - Message structure
- [NotificationModel](models/notification_model.md) - Notification structure
- [RSVPModel](models/rsvp_model.md) - Event invitation and response data

## Guides

- [Using RetryService](guides/using_retry_service.md) - Best practices for retry logic
- [RSVP System](guides/rsvp_system.md) - Event invitation and response management
- [Firebase Integration](guides/firebase_integration.md) - Working with Firebase
- [Offline Support](guides/offline_support.md) - Implementing offline functionality
- [Performance Optimization](guides/performance_optimization.md) - Optimizing app performance
- [Testing Guide](guides/testing_guide.md) - Testing components and features

## Technical Documentation

- [PageController Implementation](technical/page_controller_implementation.md) - PageController usage in HomeScreen
- [Error Handling Improvements](technical/error_handling_improvements.md) - Enhanced error handling and app stability

## API Reference

- [RetryService API](api/retry_service_api.md) - Complete API reference for RetryService
- [BatchService API](api/batch_service_api.md) - Complete API reference for BatchService
- [EventService API](api/event_service_api.md) - Complete API reference for EventService
- [AuthService API](api/auth_service_api.md) - Complete API reference for AuthService

## Best Practices

- [Error Handling](best_practices/error_handling.md) - Guidelines for error handling
- [State Management](best_practices/state_management.md) - Effective state management
- [Code Style](best_practices/code_style.md) - Coding standards and style guide
- [Performance Tips](best_practices/performance_tips.md) - Performance optimization tips
- [Async Context Usage](best_practices/async_context_usage.md) - Safe BuildContext usage across async gaps

## Contributing

- [Contribution Guidelines](contributing/guidelines.md) - How to contribute
- [Pull Request Process](contributing/pull_request_process.md) - PR submission and review
- [Issue Reporting](contributing/issue_reporting.md) - Reporting bugs and feature requests

## Troubleshooting

- [Common Issues](troubleshooting/common_issues.md) - Solutions to common problems
- [Debugging Guide](troubleshooting/debugging_guide.md) - Debugging techniques
- [FAQ](troubleshooting/faq.md) - Frequently asked questions
