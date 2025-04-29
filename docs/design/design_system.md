# Yetu'ga Design System

This document outlines the design patterns, components, and color schemes used throughout the Yetu'ga application. It serves as a reference for maintaining consistent design across both light and dark themes.

## Table of Contents

1. [Color Palette](#color-palette)
2. [Typography](#typography)
3. [Spacing and Layout](#spacing-and-layout)
4. [Components](#components)
5. [Iconography](#iconography)
6. [Animations](#animations)
7. [Theme Switching](#theme-switching)
8. [Accessibility Considerations](#accessibility-considerations)

## Color Palette

### Primary Colors

| Color Name | Light Theme | Dark Theme | Usage |
|------------|-------------|------------|-------|
| Primary | `#0A2942` (Deep Blue) | `#1E88E5` (Bright Blue) | App bar, primary buttons, selected tabs |
| Secondary | `#FFC107` (Amber) | `#FFD54F` (Light Amber) | Accents, highlights, business account indicators |
| Background | `#FFFFFF` (White) | `#121212` (Dark Gray) | Screen backgrounds |
| Surface | `#F5F5F5` (Light Gray) | `#1E1E1E` (Charcoal) | Cards, dialogs, bottom sheets |
| Error | `#B00020` (Red) | `#CF6679` (Pink Red) | Error states, destructive actions |

### Text Colors

| Color Name | Light Theme | Dark Theme | Usage |
|------------|-------------|------------|-------|
| Primary Text | `#212121` (Almost Black) | `#FFFFFF` (White) | Primary text content |
| Secondary Text | `#757575` (Medium Gray) | `#B0B0B0` (Light Gray) | Secondary text, subtitles |
| Disabled Text | `#9E9E9E` (Gray) | `#6C6C6C` (Dark Gray) | Disabled text elements |
| Hint Text | `#9E9E9E` (Gray) | `#6C6C6C` (Dark Gray) | Hint text in form fields |

### Gradient Colors

#### Gold Gradient (Business Accounts)
- Start: `#C3922E` (30% opacity)
- Middle: `#EED688` (20% opacity)
- End: `#FFFBCC` (5% opacity)

#### Blue Gradient (Personal Accounts)
- Start: `#0A2942` (30% opacity)
- Middle: `#1E88E5` (20% opacity)
- End: `#90CAF9` (5% opacity)

### Semantic Colors

| Color Name | Light Theme | Dark Theme | Usage |
|------------|-------------|------------|-------|
| Success | `#4CAF50` (Green) | `#81C784` (Light Green) | Success states, confirmations |
| Warning | `#FF9800` (Orange) | `#FFB74D` (Light Orange) | Warning states, cautions |
| Info | `#2196F3` (Blue) | `#64B5F6` (Light Blue) | Informational elements |
| Pending | `#9C27B0` (Purple) | `#BA68C8` (Light Purple) | Pending states |

## Typography

### Font Family
- Primary Font: `Roboto`
- Secondary Font: `Roboto Condensed` (for headers and emphasis)

### Text Styles

| Style Name | Font Size | Font Weight | Line Height | Letter Spacing | Usage |
|------------|-----------|-------------|-------------|----------------|-------|
| Headline 1 | 24sp | Bold (700) | 32sp | 0.25px | Main screen titles |
| Headline 2 | 20sp | Bold (700) | 28sp | 0.15px | Section headers |
| Subtitle 1 | 16sp | Medium (500) | 24sp | 0.15px | Subtitles, important information |
| Body 1 | 16sp | Regular (400) | 24sp | 0.5px | Primary body text |
| Body 2 | 14sp | Regular (400) | 20sp | 0.25px | Secondary body text |
| Caption | 12sp | Regular (400) | 16sp | 0.4px | Captions, supplementary information |
| Button | 14sp | Medium (500) | 16sp | 1.25px | Button text |
| Tab | 16sp | Bold/Light | 16sp | 0.5px | Tab text (Bold for selected, Light for unselected) |

## Spacing and Layout

### Grid System
- Base unit: 8dp
- Margins: 16dp (2x base unit)
- Padding: 16dp (2x base unit)
- Content spacing: 8dp (1x base unit)

### Screen Margins
- Horizontal screen margins: 16dp
- Vertical screen margins: 16dp
- Content padding within cards: 16dp

### Component Spacing
- Between related elements: 8dp
- Between unrelated elements: 16dp
- Between sections: 24dp

## Components

### Buttons

#### Primary Button
- Height: 48dp
- Corner radius: 24dp (fully rounded)
- Text style: Button
- Colors:
  - Light Theme: Primary color background, white text
  - Dark Theme: Primary color background, black text
- States:
  - Normal: 100% opacity
  - Pressed: 90% opacity
  - Disabled: 38% opacity

#### Secondary Button
- Height: 48dp
- Corner radius: 24dp (fully rounded)
- Text style: Button
- Colors:
  - Light Theme: White background with primary color border, primary color text
  - Dark Theme: Surface color background with primary color border, primary color text
- States:
  - Normal: 100% opacity
  - Pressed: 90% opacity
  - Disabled: 38% opacity

#### Text Button
- Height: 36dp
- No background
- Text style: Button
- Colors:
  - Light Theme: Primary color text
  - Dark Theme: Primary color text
- States:
  - Normal: 100% opacity
  - Pressed: 90% opacity
  - Disabled: 38% opacity

### Cards

#### Event Card
- Corner radius: 12dp
- Elevation: 2dp
- Padding: 16dp
- Header:
  - Gradient background based on account type
  - Blur effect with fadeout gradient
- Content:
  - Image with aspect ratio 16:9
  - Title: Headline 2
  - Description: Body 2
  - Stats: Caption
- Footer:
  - Join/Ignore buttons
  - Profile avatar with border based on account type

#### User Card
- Corner radius: 12dp
- Elevation: 2dp
- Padding: 12dp
- Profile image:
  - Size: 48dp x 48dp
  - Border: 2dp (color based on account type)
- Content:
  - Display name: Subtitle 1
  - Username: Body 2
- Action:
  - Follow/Unfollow button

### Tabs

#### Main Tabs
- Height: 48dp
- Text style: Tab
- Selected indicator: None
- Selected state:
  - Text: Primary color, Bold weight
- Unselected state:
  - Text: Secondary text color, Light weight (w200)

### Text Fields

#### Search Field
- Height: 56dp
- Corner radius: 0dp (flat)
- Border: Bottom only
- Padding: 16dp horizontal
- Leading icon: Search icon
- Text style: Body 1
- Colors:
  - Light Theme: White background, primary color focused border
  - Dark Theme: Surface color background, primary color focused border

#### Form Field
- Height: 56dp
- Corner radius: 4dp
- Border: Full outline
- Padding: 16dp horizontal
- Text style: Body 1
- Colors:
  - Light Theme: White background, primary color focused border
  - Dark Theme: Surface color background, primary color focused border

### Bottom Sheets

#### Modal Bottom Sheet
- Corner radius: 16dp (top corners only)
- Full screen width
- Drag handle: 32dp wide, 4dp high, centered
- Title: Centered, two lines maximum
- Content padding: 16dp

### Dialogs

#### Alert Dialog
- Corner radius: 16dp
- Width: 280dp
- Padding: 24dp
- Title: Headline 2
- Content: Body 1
- Button area: Right-aligned text buttons

#### RSVP Dialog
- Corner radius: 16dp
- Width: Match parent with 32dp margins
- Padding: 24dp
- Title: Headline 2
- List: Scrollable with checkboxes
- Button: "Continue (X)" format

### Navigation

#### Bottom Navigation
- Height: 56dp
- Icon size: 24dp
- Text style: Caption
- Selected state:
  - Icon and text: Primary color
- Unselected state:
  - Icon and text: Secondary text color

#### Drawer Navigation
- Width: 80% of screen width
- Header:
  - Height: 176dp
  - Background: #0A2942 (for both themes)
  - Profile image: 64dp with border based on account type
  - User info: White text
- Items:
  - Height: 48dp
  - Icon size: 24dp
  - Text style: Body 1
  - Selected state: Primary color background at 12% opacity

## Iconography

### Icon Sizes
- Small: 16dp
- Medium: 24dp (default)
- Large: 32dp

### Icon Colors
- Primary icons: Primary text color
- Secondary icons: Secondary text color
- Interactive icons: Primary color

### Common Icons
- Navigation: menu, arrow_back, close
- Actions: add, edit, delete, share, favorite
- Communication: chat, notifications
- Content: search, filter, sort
- Social: person, group, follow

## Animations

### Duration
- Short: 150ms (micro-interactions)
- Medium: 300ms (standard transitions)
- Long: 500ms (complex animations)

### Easing
- Standard: Cubic-bezier(0.4, 0.0, 0.2, 1)
- Decelerate: Cubic-bezier(0.0, 0.0, 0.2, 1)
- Accelerate: Cubic-bezier(0.4, 0.0, 1, 1)

### Transitions
- Page transitions: Slide from right
- Dialog entry: Fade in and scale up
- Bottom sheet: Slide up
- List items: Fade in staggered

## Theme Switching

### Theme Detection
1. Check system theme preference first
2. Use saved user preference if it exists
3. Default to light theme if no preference is detected

### Theme Consistency
- All components should adapt to theme changes
- Text and icon colors should adjust automatically
- Backgrounds and surfaces should maintain proper contrast

## Accessibility Considerations

### Color Contrast
- Text elements must maintain a minimum contrast ratio of 4.5:1
- Interactive elements must maintain a minimum contrast ratio of 3:1
- Use the secondary color sparingly to avoid overwhelming users

### Touch Targets
- Minimum touch target size: 48dp x 48dp
- Minimum spacing between touch targets: 8dp

### Text Scaling
- All text should scale properly with system font size changes
- Layouts should accommodate larger text sizes without breaking

### Content Descriptions
- All interactive elements should have meaningful content descriptions
- Icons without text labels must have content descriptions

## Implementation Guidelines

### Theme Implementation
- Use ThemeData in Flutter to define themes
- Create extension methods for custom theme properties
- Use theme.of(context) to access theme properties
- Avoid hardcoded colors in widget implementations

### Component Implementation
- Create reusable widgets for common components
- Use composition over inheritance
- Follow the design system specifications for spacing and sizing
- Implement proper state handling for all interactive components

### Responsive Design
- Use flexible layouts that adapt to different screen sizes
- Implement different layouts for phone and tablet when necessary
- Test on multiple device sizes and orientations
