# Yetu'ga Design Patterns and Color Schemes

This document provides a comprehensive guide to the design patterns and color schemes used in the Yetu'ga application. It serves as a reference for maintaining consistent design throughout the app in both light and dark themes.

## Table of Contents

1. [Color Palette](#color-palette)
2. [Typography](#typography)
3. [Component Styles](#component-styles)
4. [Layout Patterns](#layout-patterns)
5. [Theme-Specific Considerations](#theme-specific-considerations)
6. [Business Account Styling](#business-account-styling)
7. [Design Best Practices](#design-best-practices)

## Color Palette

### Primary Colors

| Color Name | Hex Code | RGB | Description | Usage |
|------------|----------|-----|-------------|-------|
| Primary | `#00182C` | `rgb(0, 24, 44)` | Deep navy blue | Main brand color, headers, primary text (light theme) |
| Secondary | `#29C7E4` | `rgb(41, 199, 228)` | Bright cyan | Accents, highlights, buttons, links |
| White | `#FFFFFF` | `rgb(255, 255, 255)` | Pure white | Backgrounds (light theme), text (dark theme) |

### Extended Palette

| Color Name | Hex Code | RGB | Description | Usage |
|------------|----------|-----|-------------|-------|
| Gold (Business) | `#C3922E` | `rgb(195, 146, 46)` | Gold | Business account indicators |
| Gold Light | `#EED688` | `rgb(238, 214, 136)` | Light gold | Business account gradients |
| Gold Pale | `#FFFBCC` | `rgb(255, 251, 204)` | Pale gold | Business account highlights |
| Error | `#FF3B30` | `rgb(255, 59, 48)` | Bright red | Error messages, destructive actions |
| Success | `#34C759` | `rgb(52, 199, 89)` | Green | Success messages, confirmations |
| Warning | `#FF9500` | `rgb(255, 149, 0)` | Orange | Warning messages, alerts |
| Divider (Light) | `#E0E0E0` | `rgb(224, 224, 224)` | Light gray | Dividers in light theme |
| Divider (Dark) | `#2C2C2E` | `rgb(44, 44, 46)` | Dark gray | Dividers in dark theme |

### Theme-Specific Colors

#### Light Theme
- Background: White (`#FFFFFF`)
- Text: Primary (`#00182C`)
- Surface: White (`#FFFFFF`)
- Accent: Secondary (`#29C7E4`)

#### Dark Theme
- Background: Primary (`#00182C`)
- Text: White (`#FFFFFF`)
- Surface: Primary (`#00182C`)
- Accent: Secondary (`#29C7E4`)

### Opacity Guidelines

When using colors with opacity, use these standard values:

- High emphasis: 100% opacity
- Medium emphasis: 70% opacity
- Low emphasis: 40% opacity
- Disabled state: 30% opacity

## Typography

### Font Weights

- Light: `FontWeight.w300` - Used for most text elements
- Regular: `FontWeight.w400` - Used for labels and secondary text
- Medium: `FontWeight.w500` - Used for buttons and emphasized text
- Bold: `FontWeight.bold` - Used for tab selections and important highlights

### Text Styles

#### Headline Large
- Size: 32px
- Weight: Light (300)
- Color: Primary (light theme) / White (dark theme)
- Usage: Main screen titles, onboarding headers

#### Headline Medium
- Size: 24px
- Weight: Light (300)
- Color: Primary (light theme) / White (dark theme)
- Usage: Section headers, modal titles

#### Body Large
- Size: 16px
- Weight: Light (300)
- Color: Primary (light theme) / White (dark theme)
- Usage: Primary content text, descriptions

#### Body Medium
- Size: 14px
- Weight: Light (300)
- Color: Primary (light theme) / White (dark theme)
- Usage: Secondary content, captions, metadata

#### Label Large
- Size: 16px
- Weight: Regular (400)
- Color: Secondary
- Usage: Interactive elements, links, highlights

### Tab Text
- Size: 16px
- Weight: Bold for selected, Light (300) for unselected
- Color: Primary/Secondary for selected, 60% opacity for unselected

## Component Styles

### Buttons

#### Elevated Buttons
- Background: Primary (light theme) / Secondary (dark theme)
- Text Color: White (light theme) / Primary (dark theme)
- Border Radius: 20px
- Padding: 16px vertical, 32px horizontal
- Text Style: Medium (500), 16px
- Usage: Primary actions, confirmations

#### Outlined Buttons
- Border: 1px Primary (light theme) / Secondary (dark theme)
- Text Color: Primary (light theme) / White (dark theme)
- Border Radius: 20px
- Padding: 16px vertical, 32px horizontal
- Text Style: Medium (500), 16px
- Usage: Secondary actions, alternatives

#### Text Buttons
- Text Color: Secondary
- Text Style: Regular (400), 14px
- Usage: Tertiary actions, links, low-emphasis options

### Input Fields

#### Text Fields
- Border Radius: 12px
- Border Color: Primary (light theme) / White (dark theme)
- Focus Border: Secondary, 2px width
- Label Style: Light (300), Primary/White
- Floating Label: Regular (400), Secondary
- Usage: Form inputs, search fields

#### Search Field
- Border: None or underline only
- Background: Transparent
- Icon: Search icon in 60% opacity of text color
- Text Style: Body Large
- Usage: Search screens, filtering

### Cards

#### Event Cards
- Border Radius: 12px
- Elevation: 2
- Padding: 12px
- Header: Gradient based on account type
- Image: Rounded corners, blurred edges
- Stats: Engagement metrics with icons
- Actions: Join/Ignore buttons at bottom
- Usage: Event display in feeds and search results

#### User Cards
- Border Radius: 12px
- Elevation: 2
- Padding: 12px
- Profile Image: Circular with border based on account type
- Text: Display name (bold) and username
- Action: Follow/Unfollow button
- Usage: User search results, follower lists

### Tabs

#### Main Tabs
- Text Size: 16px
- Selected: Bold weight, Primary/Secondary color
- Unselected: Light weight (300), 60% opacity
- No underline indicators
- Usage: Primary navigation, search categories

#### Filter Tabs
- Text Size: 16px
- Selected: Bold weight, Primary/Secondary color
- Unselected: Light weight (300), 60% opacity
- Horizontally scrollable
- Usage: Content filtering, categories

### Dialogs

#### Modal Bottom Sheets
- Full screen height
- Centered title (two lines maximum)
- Rounded top corners (16px)
- White background (light theme) / Primary background (dark theme)
- Usage: Additional options, detailed views

#### Alert Dialogs
- Border Radius: 16px
- Title: Headline Medium, centered
- Content: Body Large
- Actions: Horizontally aligned buttons
- Usage: Confirmations, warnings, errors

## Layout Patterns

### Screen Structure

#### Standard Screen
- AppBar with centered title
- Body content with appropriate padding (16px standard)
- Bottom navigation when applicable
- Floating action button for primary actions

#### Search Screen
- AppBar with search field
- Tab bar for switching between search types
- Filter options when applicable
- Results in scrollable list
- No swipe gestures between tabs

#### Profile Screen
- Header with profile information and image
- Tab bar for different content sections
- Content area with appropriate lists or grids
- Action buttons for follow/unfollow

### Navigation Patterns

#### Tab Navigation
- Bold text for selected tab
- Light weight text for unselected tabs
- No swipe gestures (explicit tap navigation)
- Visual feedback on selection

#### Hamburger Menu
- Light primary color background
- Profile section at top with image and name
- Menu items with icons and labels
- Dividers between sections

#### Back Navigation
- Standard back button in AppBar
- Consistent placement across screens
- Clear visual hierarchy

## Theme-Specific Considerations

### Light Theme

- Clean, white backgrounds
- Navy blue text for high contrast
- Cyan accents for interactive elements
- Subtle shadows for elevation
- High contrast between elements

### Dark Theme

- Deep navy backgrounds
- White text for readability
- Cyan accents maintained for consistency
- Reduced shadows for comfortable viewing
- Careful use of color to maintain hierarchy

### Theme Transitions

- Smooth transitions between themes
- Consistent component appearance
- Maintained information hierarchy
- Preserved interactive element recognition

## Business Account Styling

### Profile Indicators

- Gold border around profile images
- Gold gradient backgrounds for headers
- Subtle gold accents in content

### Chat Bubbles

- Gold gradient background
- Subtle glow effect
- Adjusted colors for dark theme to prevent greenish appearance

### Event Cards

- Gold gradient in card headers
- Subtle gold accents in content
- Business indicator badge

## Design Best Practices

### Consistency Guidelines

1. **Color Usage**
   - Use primary color for main elements and structure
   - Use secondary color for interactive elements and highlights
   - Maintain consistent color meanings across the app

2. **Typography Hierarchy**
   - Maintain consistent text sizes and weights
   - Use weight more than size to create hierarchy
   - Ensure sufficient contrast for readability

3. **Component Styling**
   - Use consistent border radii (12px for cards, 20px for buttons)
   - Maintain consistent padding (16px standard)
   - Apply elevation consistently based on component importance

4. **Responsive Design**
   - Design for various screen sizes
   - Use flexible layouts that adapt to content
   - Ensure touch targets are at least 48x48px

5. **Accessibility**
   - Maintain contrast ratios of at least 4.5:1 for text
   - Provide clear focus indicators
   - Ensure interactive elements are recognizable

### Implementation Notes

- Use the `AppColors` class for all color references
- Apply theme colors through the theme system, not hardcoded values
- Use the appropriate text styles from the theme
- Follow the established border radius patterns
- Maintain consistent spacing and padding

## Example Usage

### Applying Theme Colors

```dart
// Correct
final primaryColor = Theme.of(context).colorScheme.primary;
final textColor = Theme.of(context).textTheme.bodyLarge?.color;

// Incorrect
final primaryColor = AppColors.primary;
final textColor = Colors.black;
```

### Using Text Styles

```dart
// Correct
Text(
  'Heading',
  style: Theme.of(context).textTheme.headlineMedium,
)

// Incorrect
Text(
  'Heading',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w300,
    color: AppColors.primary,
  ),
)
```

### Button Styling

```dart
// Correct
ElevatedButton(
  onPressed: () {},
  child: Text('Action'),
)

// Incorrect
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
  ),
  child: Text('Action'),
)
```

## Conclusion

This design guide serves as a reference for maintaining consistent design throughout the Yetu'ga application. By following these guidelines, we ensure a cohesive user experience across both light and dark themes, while providing special styling for business accounts.

The design system is built to be flexible enough to accommodate future enhancements while maintaining the established visual identity of the Yetu'ga brand.
