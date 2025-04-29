# Yetu'ga Visual Style Guide

This visual style guide provides examples and visual references for the Yetu'ga application's design system. It complements the detailed design patterns and color schemes documentation.

## Color Swatches

### Primary Colors

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│     Primary         │  │     Secondary       │  │     White           │
│     #00182C         │  │     #29C7E4         │  │     #FFFFFF         │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

### Business Account Colors

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│     Gold            │  │     Gold Light      │  │     Gold Pale       │
│     #C3922E         │  │     #EED688         │  │     #FFFBCC         │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

### Status Colors

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│     Error           │  │     Success         │  │     Warning         │
│     #FF3B30         │  │     #34C759         │  │     #FF9500         │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
│                     │  │                     │  │                     │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

## Typography Examples

### Headlines

```
Headline Large (32px, Light)
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
```

```
Headline Medium (24px, Light)
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
```

### Body Text

```
Body Large (16px, Light)
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
```

```
Body Medium (14px, Light)
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
```

### Labels

```
Label Large (16px, Regular)
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
```

## Component Examples

### Buttons

#### Light Theme

```
┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────┐
│                         │  │                         │  │                 │
│         PRIMARY         │  │         SECONDARY       │  │     TERTIARY    │
│                         │  │                         │  │                 │
└─────────────────────────┘  └─────────────────────────┘  └─────────────────┘

Elevated Button             Outlined Button             Text Button
Background: #00182C         Border: #00182C             Text: #29C7E4
Text: #FFFFFF               Text: #00182C               No background
```

#### Dark Theme

```
┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────┐
│                         │  │                         │  │                 │
│         PRIMARY         │  │         SECONDARY       │  │     TERTIARY    │
│                         │  │                         │  │                 │
└─────────────────────────┘  └─────────────────────────┘  └─────────────────┘

Elevated Button             Outlined Button             Text Button
Background: #29C7E4         Border: #29C7E4             Text: #29C7E4
Text: #00182C               Text: #FFFFFF               No background
```

### Input Fields

#### Light Theme

```
┌─────────────────────────────────────────┐
│                                         │
│  Label                                  │
│  ┌─────────────────────────────────┐    │
│  │ Input text                      │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘

Border: #00182C
Label: #00182C
Text: #00182C
```

#### Dark Theme

```
┌─────────────────────────────────────────┐
│                                         │
│  Label                                  │
│  ┌─────────────────────────────────┐    │
│  │ Input text                      │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘

Border: #FFFFFF
Label: #FFFFFF
Text: #FFFFFF
```

### Search Field

```
┌─────────────────────────────────────────┐
│                                         │
│  🔍 Search...                           │
│  ─────────────────────────────────────  │
│                                         │
└─────────────────────────────────────────┘

Icon: 60% opacity of text color
Underline only
```

### Cards

#### Event Card (Light Theme)

```
┌─────────────────────────────────────────┐
│  ╭─────────────────────────────────╮    │
│  │ Event Type                       │    │
│  ╰─────────────────────────────────╯    │
│                                         │
│  [Event Image]                          │
│                                         │
│  Event Title                            │
│  @username                              │
│                                         │
│  🔥 123  👥 45/50                       │
│                                         │
│  ┌─────────┐        ┌─────────┐        │
│  │  JOIN   │        │ IGNORE  │        │
│  └─────────┘        └─────────┘        │
│                                         │
└─────────────────────────────────────────┘

Border Radius: 12px
Elevation: 2
Header: Gradient based on account type
```

#### User Card (Light Theme)

```
┌─────────────────────────────────────────┐
│                                         │
│  ⭕ Display Name                        │
│     @username                 ┌───────┐ │
│                               │Follow │ │
│                               └───────┘ │
│                                         │
└─────────────────────────────────────────┘

Border Radius: 12px
Profile Image: Circle with colored border
```

### Tabs

```
┌─────────────────────────────────────────┐
│                                         │
│  EVENTS       USERS                     │
│  ─────                                  │
│                                         │
└─────────────────────────────────────────┘

Selected: Bold, Primary/Secondary color
Unselected: Light weight, 60% opacity
```

### Filter Tabs

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  All  Celebrate  Drink  Eating  Play  Run  Visit >  │
│  ───                                                │
│                                                     │
└─────────────────────────────────────────────────────┘

Selected: Bold, Primary color
Unselected: Light weight, 60% opacity
Horizontally scrollable
```

## Theme Comparison

### Light Theme vs Dark Theme

```
┌─────────────────────────┐  ┌─────────────────────────┐
│                         │  │                         │
│  Light Theme            │  │  Dark Theme             │
│                         │  │                         │
│  Background: #FFFFFF    │  │  Background: #00182C    │
│  Text: #00182C          │  │  Text: #FFFFFF          │
│  Primary: #00182C       │  │  Primary: #29C7E4       │
│  Secondary: #29C7E4     │  │  Secondary: #29C7E4     │
│                         │  │                         │
└─────────────────────────┘  └─────────────────────────┘
```

## Business Account Styling

### Profile Image Borders

```
┌─────────────────────────┐  ┌─────────────────────────┐
│                         │  │                         │
│  Personal Account       │  │  Business Account       │
│                         │  │                         │
│  ⭕ Display Name        │  │  ⭕ Business Name       │
│     @username           │  │     @businessname       │
│                         │  │                         │
│  Border: #00182C/       │  │  Border: Gold gradient  │
│          #29C7E4        │  │          #C3922E        │
│                         │  │                         │
└─────────────────────────┘  └─────────────────────────┘
```

### Chat Bubbles

```
┌─────────────────────────────────────────┐
│                                         │
│  ⭕ You                                 │
│  ┌───────────────────┐                  │
│  │ Your message      │                  │
│  └───────────────────┘                  │
│                                         │
│                      ┌───────────────┐  │
│                      │ Their message │  │
│                      └───────────────┘  │
│                                 ⭕      │
│                                         │
└─────────────────────────────────────────┘

Personal bubble: Primary/Secondary color
Business bubble: Gold gradient
```

## Layout Examples

### Standard Screen Layout

```
┌─────────────────────────────────────────┐
│  ┌─────────────────────────────────┐    │
│  │ App Bar                         │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Content Area                           │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Navigation Bar                  │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Search Screen Layout

```
┌─────────────────────────────────────────┐
│  ┌─────────────────────────────────┐    │
│  │ 🔍 Search...                    │    │
│  └─────────────────────────────────┘    │
│                                         │
│  EVENTS       USERS                     │
│  ─────                                  │
│                                         │
│  All  Celebrate  Drink  Eating  Play >  │
│  ───                                    │
│                                         │
│  [Search Results]                       │
│                                         │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

## Responsive Behavior

### Adapting to Different Screen Sizes

```
┌───────────┐  ┌─────────────────────┐  ┌─────────────────────────────┐
│           │  │                     │  │                             │
│ Small     │  │ Medium              │  │ Large                       │
│ Screen    │  │ Screen              │  │ Screen                      │
│           │  │                     │  │                             │
│ Single    │  │ Two columns         │  │ Multi-column layout         │
│ column    │  │ for content         │  │ with sidebar                │
│ layout    │  │                     │  │                             │
│           │  │                     │  │                             │
└───────────┘  └─────────────────────┘  └─────────────────────────────┘
```

## Implementation Guidelines

When implementing the UI, always:

1. Use theme properties instead of hardcoded values
2. Apply consistent spacing (16px standard)
3. Follow the established border radius patterns
4. Use the appropriate text styles from the theme
5. Ensure proper contrast in both themes
6. Test designs in both light and dark modes

## Conclusion

This visual style guide provides concrete examples of the design patterns described in the design documentation. Use it as a reference when implementing new UI components to ensure consistency throughout the Yetu'ga application.
