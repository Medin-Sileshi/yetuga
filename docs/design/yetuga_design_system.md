# Yetu'ga Design System

## 🎨 Color Palette

### Core Colors

| Name | Light Mode | Dark Mode | Preview | Usage |
|------|------------|-----------|---------|-------|
| **Primary** | `#0A2942` | `#1E88E5` | | App bars, buttons, selected tabs |
| **Secondary** | `#FFC107` | `#FFD54F` | | Accents, business accounts |
| **Background** | `#FFFFFF` | `#121212` | | Screen backgrounds |
| **Surface** | `#F5F5F5` | `#1E1E1E` | | Cards, dialogs |
| **Error** | `#B00020` | `#CF6679` | | Error states |

### Text Colors

| Name | Light Mode | Dark Mode | Preview | Usage |
|------|------------|-----------|---------|-------|
| **On Primary** | `#FFFFFF` | `#000000` | | Text on primary color |
| **On Secondary** | `#000000` | `#000000` | | Text on secondary color |
| **On Background** | `#212121` | `#FFFFFF` | | Main text |
| **On Surface** | `#212121` | `#FFFFFF` | | Text on cards |
| **On Error** | `#FFFFFF` | `#000000` | | Text on error color |

### Semantic Colors

| Name | Light Mode | Dark Mode | Preview | Usage |
|------|------------|-----------|---------|-------|
| **Success** | `#4CAF50` | `#81C784` | | Success states |
| **Warning** | `#FF9800` | `#FFB74D` | | Warning states |
| **Info** | `#2196F3` | `#64B5F6` | | Information |
| **Pending** | `#9C27B0` | `#BA68C8` | | Pending states |

### Account-Specific Colors

#### Business Account Gradient
- Start: `#C3922E` (30% opacity)
- Middle: `#EED688` (20% opacity)
- End: `#FFFBCC` (5% opacity)

#### Personal Account Gradient
- Start: `#0A2942` (30% opacity)
- Middle: `#1E88E5` (20% opacity)
- End: `#90CAF9` (5% opacity)

## 📏 Typography

### Font Family
- Primary: **Roboto**

### Text Styles

| Style | Size | Weight | Line Height | Letter Spacing | Preview |
|-------|------|--------|-------------|----------------|---------|
| **Headline 1** | 24sp | Bold (700) | 32sp | 0.25px | |
| **Headline 2** | 20sp | Bold (700) | 28sp | 0.15px | |
| **Subtitle 1** | 16sp | Medium (500) | 24sp | 0.15px | |
| **Body 1** | 16sp | Regular (400) | 24sp | 0.5px | |
| **Body 2** | 14sp | Regular (400) | 20sp | 0.25px | |
| **Caption** | 12sp | Regular (400) | 16sp | 0.4px | |
| **Button** | 14sp | Medium (500) | 16sp | 1.25px | |
| **Tab** | 16sp | Bold/Light | 16sp | 0.5px | |

## 🧩 Components

### Buttons

#### Primary Button
```
Height: 48dp
Corner radius: 24dp (fully rounded)
Text: Button text style
Colors: Primary color with white/black text
States: Normal (100%), Pressed (90%), Disabled (38%)
```

#### Secondary Button
```
Height: 48dp
Corner radius: 24dp (fully rounded)
Text: Button text style
Colors: Transparent with primary color border and text
States: Normal (100%), Pressed (90%), Disabled (38%)
```

#### Text Button
```
Height: 36dp
No background
Text: Button text style in primary color
States: Normal (100%), Pressed (90%), Disabled (38%)
```

### Cards

#### Event Card
```
Corner radius: 12dp
Elevation: 2dp
Padding: 16dp
Header: Gradient based on account type
Content: Image (16:9), Title, Description, Stats
Footer: Join/Ignore buttons, Profile avatar
```

#### User Card
```
Corner radius: 12dp
Elevation: 2dp
Padding: 12dp
Profile image: 48dp with colored border
Content: Display name, Username
Action: Follow/Unfollow button
```

### Tabs

```
Height: 48dp
Text: Tab text style
No indicator line
Selected: Primary color, Bold weight
Unselected: Secondary text color, Light weight (w200)
```

### Text Fields

#### Search Field
```
Height: 56dp
Border: Bottom only
Padding: 16dp horizontal
Leading icon: Search icon
Text: Body 1 style
```

#### Form Field
```
Height: 56dp
Corner radius: 4dp
Border: Full outline
Padding: 16dp horizontal
Text: Body 1 style
```

### Bottom Sheets

```
Corner radius: 16dp (top corners only)
Full screen width
Drag handle: 32dp × 4dp, centered
Title: Centered, two lines maximum
Content padding: 16dp
```

### Dialogs

```
Corner radius: 16dp
Width: 280dp or match parent with 32dp margins
Padding: 24dp
Title: Headline 2 style
Content: Body 1 style
Button area: Right-aligned text buttons
```

## 📱 Screen Patterns

### Home Screen
```
Header: App bar with hamburger menu, title, QR scanner
Tabs: JOINED, NEW, SHOW ALL (large text, swipeable)
Content: Stacked card carousel
FAB: Simple icon button (no background)
```

### Search Screen
```
Header: Search field with icon
Tabs: EVENTS, USERS (large text, not swipeable)
Events tab: Activity type filter, event cards
Users tab: User cards with follow/unfollow
```

### Profile Screen
```
Header: Cover image, profile picture, name, stats
Tabs: POSTS, ABOUT
Content: Event cards or profile information
```

### Chat Screen
```
Header: User info with avatar
Content: Chat bubbles with different styles per account type
Input: Text field with send button
```

## 🎭 Theme Implementation

### Light Theme

```dart
static ThemeData get lightTheme {
  return ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF0A2942),
    colorScheme: ColorScheme.light(
      primary: Color(0xFF0A2942),
      secondary: Color(0xFFFFC107),
      surface: Color(0xFFF5F5F5),
      background: Color(0xFFFFFFFF),
      error: Color(0xFFB00020),
    ),
    // Additional theme properties...
  );
}
```

### Dark Theme

```dart
static ThemeData get darkTheme {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF1E88E5),
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF1E88E5),
      secondary: Color(0xFFFFD54F),
      surface: Color(0xFF1E1E1E),
      background: Color(0xFF121212),
      error: Color(0xFFCF6679),
    ),
    // Additional theme properties...
  );
}
```

## 🖌️ Account-Specific Styling

### Business Account

```dart
// Border color for business accounts
final borderColor = Colors.amber;

// Gradient for business accounts
final businessGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x4DC3922E),  // 30% opacity
    Color(0x33EED688),  // 20% opacity
    Color(0x0DFFFBCC),  // 5% opacity
  ],
);

// Chat bubble style for business accounts
final businessChatBubble = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC3922E),
      Color(0xFFEED688),
    ],
  ),
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Color(0x40C3922E),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ],
);
```

### Personal Account

```dart
// Border color for personal accounts
final borderColor = theme.colorScheme.primary;

// Gradient for personal accounts
final personalGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x4D0A2942),  // 30% opacity
    Color(0x331E88E5),  // 20% opacity
    Color(0x0D90CAF9),  // 5% opacity
  ],
);

// Chat bubble style for personal accounts
final personalChatBubble = BoxDecoration(
  color: theme.colorScheme.primary,
  borderRadius: BorderRadius.circular(16),
);
```

## 🔄 Theme Switching Logic

```dart
// Theme detection logic
ThemeMode _loadTheme() {
  // First check system preference
  final isPlatformDark =
    WidgetsBinding.instance.window.platformBrightness == Brightness.dark;

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
```

## 📏 Spacing System

```
Base unit: 8dp
Margins: 16dp (2× base)
Padding: 16dp (2× base)
Content spacing: 8dp (1× base)
Section spacing: 24dp (3× base)
```

## 🔍 Accessibility Guidelines

```
Text contrast: Minimum 4.5:1 ratio
Interactive elements: Minimum 3:1 contrast ratio
Touch targets: Minimum 48dp × 48dp
Spacing between targets: Minimum 8dp
Text scaling: All text should scale with system settings
```

## 📱 Responsive Breakpoints

```
Small phone: < 360dp
Phone: 360dp - 599dp
Tablet: 600dp - 959dp
Desktop: ≥ 960dp
```
