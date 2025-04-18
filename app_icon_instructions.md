# App Icon Generation Instructions

Follow these steps to generate app icons for all platforms from your image:

## Prerequisites

1. Make sure your icon image is:
   - Square (ideally 1024×1024 pixels)
   - PNG format with transparency (if needed)
   - Simple and recognizable at small sizes
   - Placed in the `assets/icon/` directory as `icon.png`

## Generate Icons

1. Run the following commands:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

2. The icons will be automatically generated and placed in the appropriate directories:
   - Android: `android/app/src/main/res/`
   - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
   - Web: `web/icons/`
   - Windows: `windows/runner/resources/`
   - macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

## Verify Icons

After generation, verify that the icons look good:

1. Run your app on different platforms to see how the icon appears
2. Check that the icon is visible against different backgrounds
3. Ensure the icon is not pixelated or blurry

## Troubleshooting

If you encounter issues:

1. **Icon not updating**: Clean your project with `flutter clean` and rebuild
2. **Generation errors**: Make sure your image meets the requirements (square, high resolution)
3. **iOS issues**: Open the iOS project in Xcode and verify the icon set

## Customizing Icons

If you need different icons for different platforms:

1. Update the `pubspec.yaml` configuration:

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path_android: "assets/icon/android_icon.png"
  image_path_ios: "assets/icon/ios_icon.png"
  # Other configurations...
```

2. Run the generation command again

## Adaptive Icons (Android)

For Android adaptive icons (background + foreground):

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#FFFFFF" # or a path to an image
  adaptive_icon_foreground: "assets/icon/foreground.png"
  # Other configurations...
```

## Additional Resources

- [flutter_launcher_icons documentation](https://pub.dev/packages/flutter_launcher_icons)
- [Material Design icon guidelines](https://material.io/design/iconography/product-icons.html)
- [Apple Human Interface Guidelines for App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
