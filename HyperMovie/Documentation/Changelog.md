# Changelog

## [Unreleased] - Chromia UI Style Implementation

### Added
- New theme system with support for multiple themes:
  - Classic theme (original app styling)
  - Chromia theme (new sophisticated dark interface)
- Theme selector in the View menu for easy switching between themes
- New color palette based on Chromia UI Style Guide:
  - Deep charcoal/near-black (#121214) for main background
  - Vibrant purple-pink gradient (#9D4EDD to #FF007F) for accent colors
  - White (#FFFFFF) and light gray (#E5E5E5) for text
  - Mint green (#4ADE80) for positive indicators
  - Card backgrounds in slightly lighter dark gray (#1E1E24)
  - Medium gray (#505060) for inactive elements
  - Dark gray with subtle opacity (#303040) for borders and separators

- New typography scale:
  - Large numbers/stats: 36-42px, bold
  - Section headings: 18-20px, medium
  - Regular text: 14-16px, regular
  - Small text/metadata: 12px, light
  - Using system font with appropriate weight variations

- Enhanced UI components:
  - Added hover effects to interactive elements
  - Implemented subtle glow effects for accent elements
  - Created pill-shaped buttons with gradient backgrounds
  - Added subtle border overlays to card components
  - Improved visual hierarchy with consistent spacing

### Changed
- Refactored Theme.swift to support multiple themes with a ThemeManager
- Enhanced Shadow.swift to support custom shadow colors for glow effects
- Redesigned HMCard component with subtle borders and hover effects
- Transformed HMButton component to use pill shapes and gradients
- Improved HMListItem with hover states and subtle dividers
- Refined HMGridItem with scale animations and selection indicators
- Updated corner radius values to be more consistent with Chromia UI style
- Modified animation timings to use easeOut for smoother transitions
- Updated AccentColor.colorset to use the Chromia UI primary accent color (#9D4EDD)
- Fixed import references in Home views to properly access design system components by using direct module imports instead of @_exported imports

### Technical Details
- Added ThemeManager class to handle theme selection and persistence
- Implemented ThemeType enum for theme identification
- Created ThemeSelector component for UI-based theme switching
- Added Color extension for hex color support
- Implemented custom ButtonStyle for improved press animations
- Created HoverEffect modifier for consistent hover behaviors
- Enhanced elevation system with glow effect support
- Updated preview examples to showcase the new styling
- Added new HMGridItem initializer to support decorated image views
- Fixed import references in Home views to properly access design system components
- Resolved "underlying Objective-C module 'HyperMovie' not found" errors by using proper module imports

This update completely transforms the visual appearance of the app to match the sophisticated, modern dark interface aesthetic of the Chromia UI Style Guide, featuring vibrant accent colors and a clean, minimal approach to displaying complex information. The new theme system allows users to switch between the classic and Chromia themes according to their preference. 