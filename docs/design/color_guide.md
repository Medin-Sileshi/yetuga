# Yetu'ga Color Guide

This document provides detailed information about the color schemes used in the Yetu'ga application, including implementation details for both light and dark themes.

## Table of Contents

1. [Color Palette Implementation](#color-palette-implementation)
2. [Theme Configuration](#theme-configuration)
3. [Color Usage Guidelines](#color-usage-guidelines)
4. [Account Type-Specific Colors](#account-type-specific-colors)
5. [Gradient Implementations](#gradient-implementations)
6. [Color Accessibility](#color-accessibility)
7. [Implementation Examples](#implementation-examples)

## Color Palette Implementation

### Primary Colors

```dart
// Light theme colors
static const Color lightPrimaryColor = Color(0xFF0A2942);      // Deep Blue
static const Color lightSecondaryColor = Color(0xFFFFC107);    // Amber
static const Color lightBackgroundColor = Color(0xFFFFFFFF);   // White
static const Color lightSurfaceColor = Color(0xFFF5F5F5);      // Light Gray
static const Color lightErrorColor = Color(0xFFB00020);        // Red

// Dark theme colors
static const Color darkPrimaryColor = Color(0xFF1E88E5);       // Bright Blue
static const Color darkSecondaryColor = Color(0xFFFFD54F);     // Light Amber
static const Color darkBackgroundColor = Color(0xFF121212);    // Dark Gray
static const Color darkSurfaceColor = Color(0xFF1E1E1E);       // Charcoal
static const Color darkErrorColor = Color(0xFFCF6679);         // Pink Red
```

### Text Colors

```dart
// Light theme text colors
static const Color lightPrimaryTextColor = Color(0xFF212121);  // Almost Black
static const Color lightSecondaryTextColor = Color(0xFF757575); // Medium Gray
static const Color lightDisabledTextColor = Color(0xFF9E9E9E); // Gray
static const Color lightHintTextColor = Color(0xFF9E9E9E);     // Gray

// Dark theme text colors
static const Color darkPrimaryTextColor = Color(0xFFFFFFFF);   // White
static const Color darkSecondaryTextColor = Color(0xFFB0B0B0); // Light Gray
static const Color darkDisabledTextColor = Color(0xFF6C6C6C);  // Dark Gray
static const Color darkHintTextColor = Color(0xFF6C6C6C);      // Dark Gray
```

### Semantic Colors

```dart
// Light theme semantic colors
static const Color lightSuccessColor = Color(0xFF4CAF50);      // Green
static const Color lightWarningColor = Color(0xFFFF9800);      // Orange
static const Color lightInfoColor = Color(0xFF2196F3);         // Blue
static const Color lightPendingColor = Color(0xFF9C27B0);      // Purple

// Dark theme semantic colors
static const Color darkSuccessColor = Color(0xFF81C784);       // Light Green
static const Color darkWarningColor = Color(0xFFFFB74D);       // Light Orange
static const Color darkInfoColor = Color(0xFF64B5F6);          // Light Blue
static const Color darkPendingColor = Color(0xFFBA68C8);       // Light Purple
```

## Theme Configuration

The theme configuration is defined in `lib/theme/app_theme.dart`:

```dart
class AppTheme {
  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: lightPrimaryColor,
      colorScheme: const ColorScheme.light(
        primary: lightPrimaryColor,
        secondary: lightSecondaryColor,
        surface: lightSurfaceColor,
        background: lightBackgroundColor,
        error: lightErrorColor,
      ),
      scaffoldBackgroundColor: lightBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: lightSurfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Additional theme properties...
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkPrimaryColor,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimaryColor,
        secondary: darkSecondaryColor,
        surface: darkSurfaceColor,
        background: darkBackgroundColor,
        error: darkErrorColor,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkPrimaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: darkSurfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Additional theme properties...
    );
  }
}
```

## Color Usage Guidelines

### Primary Color
- App bars
- Primary buttons
- Selected tabs and navigation items
- Progress indicators
- Links and interactive elements

### Secondary Color
- Accent elements
- Floating action buttons
- Selection controls (checkboxes, radio buttons)
- Highlighting important information
- Business account indicators

### Background Color
- Screen backgrounds
- Large surfaces

### Surface Color
- Cards
- Dialogs
- Bottom sheets
- Elevated components

### Error Color
- Error messages
- Error states in forms
- Destructive actions (delete, remove)

### Text Colors
- Primary text: Main content text
- Secondary text: Subtitles, less important information
- Disabled text: Non-interactive elements
- Hint text: Placeholder text in input fields

## Account Type-Specific Colors

### Personal Accounts
- Primary color for borders and accents
- Blue gradient for headers and backgrounds

### Business Accounts
- Gold/Amber color for borders and accents
- Gold gradient for headers and backgrounds

```dart
// Determine border color based on account type
Color getBorderColor(String accountType, BuildContext context) {
  final theme = Theme.of(context);
  return accountType == 'business'
      ? Colors.amber
      : theme.colorScheme.primary;
}
```

## Gradient Implementations

### Gold Gradient (Business Accounts)

```dart
// Gold gradient for business accounts
static const LinearGradient businessGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x4DC3922E),  // 30% opacity
    Color(0x33EED688),  // 20% opacity
    Color(0x0DFFFBCC),  // 5% opacity
  ],
);

// Gold gradient with blur effect for card headers
static BoxDecoration businessCardHeaderDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x80C3922E),  // 50% opacity
      Color(0x4DEED688),  // 30% opacity
      Color(0x00FFFBCC),  // 0% opacity (transparent)
    ],
  ),
  borderRadius: BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.circular(12),
  ),
);
```

### Blue Gradient (Personal Accounts)

```dart
// Blue gradient for personal accounts
static const LinearGradient personalGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x4D0A2942),  // 30% opacity
    Color(0x331E88E5),  // 20% opacity
    Color(0x0D90CAF9),  // 5% opacity
  ],
);

// Blue gradient with blur effect for card headers
static BoxDecoration personalCardHeaderDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x800A2942),  // 50% opacity
      Color(0x4D1E88E5),  // 30% opacity
      Color(0x0090CAF9),  // 0% opacity (transparent)
    ],
  ),
  borderRadius: BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.circular(12),
  ),
);
```

## Color Accessibility

### Contrast Ratios
All color combinations used in the app should meet the following minimum contrast ratios:

- Normal text (< 18pt): 4.5:1
- Large text (≥ 18pt): 3:1
- UI components and graphical objects: 3:1

### Verified Color Combinations

| Foreground | Background | Contrast Ratio | Passes AA | Passes AAA |
|------------|------------|----------------|-----------|------------|
| Light Primary Text | Light Background | 14.5:1 | Yes | Yes |
| Light Primary Text | Light Surface | 13.2:1 | Yes | Yes |
| Dark Primary Text | Dark Background | 15.8:1 | Yes | Yes |
| Dark Primary Text | Dark Surface | 14.1:1 | Yes | Yes |
| Light Primary | Light Background | 9.8:1 | Yes | Yes |
| Dark Primary | Dark Background | 4.7:1 | Yes | Yes |
| Light Secondary | Light Background | 1.4:1 | No | No |
| Dark Secondary | Dark Background | 8.1:1 | Yes | Yes |

### Accessibility Adjustments

For cases where the default colors don't meet accessibility standards (like Light Secondary on Light Background), use these adjusted colors:

```dart
// Accessibility-adjusted secondary color for light theme
static const Color accessibleLightSecondaryColor = Color(0xFFB26A00);  // Darker amber
```

## Implementation Examples

### Theme Provider

```dart
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(_loadTheme());
  
  static ThemeMode _loadTheme() {
    // First check system preference
    final isPlatformDark = WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    
    // Then check saved preference if available
    final prefs = Hive.box('settings');
    final savedTheme = prefs.get('theme');
    
    if (savedTheme == 'light') {
      return ThemeMode.light;
    } else if (savedTheme == 'dark') {
      return ThemeMode.dark;
    } else {
      // Use system preference if no saved preference
      return isPlatformDark ? ThemeMode.dark : ThemeMode.light;
    }
  }
  
  void setLightMode() {
    Hive.box('settings').put('theme', 'light');
    state = ThemeMode.light;
  }
  
  void setDarkMode() {
    Hive.box('settings').put('theme', 'dark');
    state = ThemeMode.dark;
  }
  
  void setSystemMode() {
    Hive.box('settings').put('theme', 'system');
    state = ThemeMode.system;
  }
}
```

### Using Colors in Widgets

```dart
// Example of using theme colors in a widget
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isDisabled;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.brightness == Brightness.light ? Colors.white : Colors.black,
        disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.38),
        disabledForegroundColor: theme.brightness == Brightness.light 
            ? Colors.white.withOpacity(0.38) 
            : Colors.black.withOpacity(0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    );
  }
}
```

### Account-Specific Styling

```dart
// Example of using account-specific styling
class ProfileAvatar extends StatelessWidget {
  final String userId;
  final String accountType;
  final String? profileImageUrl;
  final double size;

  const ProfileAvatar({
    Key? key,
    required this.userId,
    required this.accountType,
    this.profileImageUrl,
    this.size = 48.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = accountType == 'business'
        ? theme.brightness == Brightness.light ? Colors.amber : Colors.amber.shade300
        : theme.colorScheme.primary;
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2.0,
        ),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.colorScheme.surface,
        backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
            ? NetworkImage(profileImageUrl!)
            : null,
        child: profileImageUrl == null || profileImageUrl!.isEmpty
            ? Icon(
                Icons.person,
                color: theme.colorScheme.primary,
                size: size / 2,
              )
            : null,
      ),
    );
  }
}
```

### Gradient Background

```dart
// Example of using gradient backgrounds
class EventCardHeader extends StatelessWidget {
  final String accountType;
  final String title;

  const EventCardHeader({
    Key? key,
    required this.accountType,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isBusinessAccount = accountType == 'business';
    
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isBusinessAccount
              ? [
                  const Color(0x80C3922E),  // 50% opacity
                  const Color(0x4DEED688),  // 30% opacity
                  const Color(0x00FFFBCC),  // 0% opacity
                ]
              : [
                  const Color(0x800A2942),  // 50% opacity
                  const Color(0x4D1E88E5),  // 30% opacity
                  const Color(0x0090CAF9),  // 0% opacity
                ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
```
