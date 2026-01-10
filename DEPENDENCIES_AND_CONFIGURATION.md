# Delivery Tracking System - Dependencies & Configuration

## Required Dependencies

### Core Dependencies (must already have)
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0  # Already in your project
  shared_preferences: ^2.0.0  # Already in your project
```

### New Dependency to Add
```yaml
dependencies:
  geolocator: ^9.0.0  # For GPS location tracking
```

### Optional Dependencies (for enhancements)
```yaml
dependencies:
  google_maps_flutter: ^2.5.0  # For map display
  firebase_messaging: ^14.0.0  # For push notifications
  image_picker: ^0.8.0  # For photo capture
  signature: ^5.0.0  # For signature capture
  rxdart: ^0.27.0  # For combining streams
```

---

## Installation Instructions

### Step 1: Add Geolocator

```bash
# Navigate to your project root
cd c:\Projects\Flutter\yalla_qr

# Add geolocator package
flutter pub add geolocator

# Install dependencies
flutter pub get
```

### Step 2: Verify Installation

```bash
# Check if geolocator is installed
flutter pub show geolocator

# Expected output:
# Package: geolocator
# Latest version: 9.0.0
# Installed version: 9.0.0
```

### Step 3: Update pubspec.yaml (if needed)

Your `pubspec.yaml` should now have:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  supabase_flutter: ^2.0.0
  shared_preferences: ^2.0.0
  geolocator: ^9.0.0  # ← NEW
```

---

## Platform-Specific Configuration

### Android Configuration

#### Step 1: Update AndroidManifest.xml

File: `android/app/src/main/AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- ✅ ADD THESE PERMISSIONS -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

    <application
        android:label="yalla_qr"
        android:icon="@mipmap/ic_launcher">
        
        <!-- ✅ ADD THIS SERVICE -->
        <service
            android:name="com.baseflow.geolocator.LocationUpdatesService"
            android:enabled="true"
            android:exported="false" />

        <!-- Your existing application content -->
        <activity
            android:name=".MainActivity"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

#### Step 2: Update build.gradle.kts

File: `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.example.yalla_qr"
    compileSdk = 34  // ✅ Minimum 33, recommend 34+

    defaultConfig {
        applicationId = "com.example.yalla_qr"
        minSdk = 21
        targetSdk = 34  // ✅ Minimum 31, recommend 34+
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
```

#### Step 3: Test on Real Device

```bash
# Build for Android
flutter build apk

# Or install directly
flutter run -d <device-id>

# Verify location works:
# Settings > Apps > Permissions > Location
# Grant "Allow all the time"
```

---

### iOS Configuration

#### Step 1: Update Info.plist

File: `ios/Runner/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ✅ ADD THESE KEYS -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app needs your location to track deliveries in real-time</string>
    
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>This app needs your location to track deliveries in real-time</string>
    
    <key>NSLocationAlwaysUsageDescription</key>
    <string>This app needs your location to track deliveries in real-time</string>
    
    <!-- Your existing config -->
    <key>CFBundleName</key>
    <string>yalla_qr</string>
    <!-- ... rest of config ... -->
</dict>
</plist>
```

#### Step 2: Update Podfile (if needed)

File: `ios/Podfile`

```ruby
# Uncomment this line if you want to specify a particular version of CocoaPods
# platform :ios, '12.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',  # Enable location permission
      ]
    end
  end
end
```

#### Step 3: Test on Real Device

```bash
# Build for iOS
flutter build ios

# Or install directly
flutter run -d <device-id>

# Verify location works:
# Settings > Privacy > Location Services
# Ensure permission is granted for your app
```

---

## Web Configuration (if supporting web)

### Step 1: Update web/index.html

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta content="IE=Edge" http-equiv="X-UA-Compatible">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- ... existing head content ... -->
    
    <!-- ✅ ADD GEOLOCATION API -->
    <script>
        // Ensure browser supports Geolocation API
        if ('geolocation' in navigator) {
            console.log('Geolocation API is supported');
        } else {
            console.warn('Geolocation API is not supported');
        }
    </script>
</head>
<body>
    <script src="flutter.js" defer></script>
</body>
</html>
```

---

## Dependency Verification

### Check Installed Packages

```bash
# List all dependencies
flutter pub deps

# Check specific package
flutter pub show geolocator

# Check for conflicts
flutter pub outdated
```

### Verify Imports Work

Create a test file to verify everything is installed:

```dart
// test_imports.dart
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  print('✓ Geolocator imported successfully');
  print('✓ Supabase imported successfully');
}
```

Run it:
```bash
dart test_imports.dart
```

---

## Version Compatibility

### Minimum Flutter Version
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
```

### Tested Versions
| Package | Tested Version | Minimum | Latest |
|---------|---|---|---|
| flutter | 3.10.0+ | 3.0.0 | 3.16.0+ |
| geolocator | 9.0.0 | 8.0.0 | 9.0.0+ |
| supabase_flutter | 2.0.0 | 1.10.0 | 2.0.0+ |

---

## Common Dependency Issues & Solutions

### Issue 1: Geolocator Not Installing

```bash
# Clear pub cache
flutter pub cache clean

# Get fresh dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade geolocator
```

### Issue 2: Android Build Fails

```bash
# Clean build
flutter clean

# Rebuild
flutter pub get
flutter build apk

# If still fails, check:
# - compileSdk >= 34
# - targetSdk >= 34
# - Android permissions in manifest
```

### Issue 3: iOS Build Fails

```bash
# Clean and reinstall pods
cd ios
rm -rf Pods
rm Podfile.lock
cd ..

# Reinstall
flutter pub get
flutter run
```

### Issue 4: Import Conflicts

If you get import conflicts:

```dart
// Use explicit imports
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// Then use prefixed names
final position = await geolocator.Geolocator.getCurrentPosition();
```

---

## Dependency Update Strategy

### Check for Updates Regularly

```bash
# Check outdated packages
flutter pub outdated

# Update all (with caution)
flutter pub upgrade

# Update specific package
flutter pub upgrade geolocator
```

### Version Pinning

For production stability, you might want to pin versions:

```yaml
dependencies:
  geolocator: 9.0.0  # Exact version instead of ^9.0.0
```

---

## Environment Setup Checklist

### Developer Machine Setup
- [ ] Flutter SDK 3.0+ installed
- [ ] Android SDK 34+ installed
- [ ] Xcode 14+ (for iOS)
- [ ] Dart SDK 3.0+ installed
- [ ] VS Code or Android Studio with Flutter plugin

### Project Configuration
- [ ] pubspec.yaml updated with geolocator
- [ ] AndroidManifest.xml has location permissions
- [ ] Info.plist has location descriptions
- [ ] build.gradle.kts has correct SDK versions
- [ ] Podfile includes flutter_additional_ios_build_settings

### Testing Environment
- [ ] Real Android device available (API 21+)
- [ ] Real iOS device available (iOS 12+)
- [ ] Location services enabled on test devices
- [ ] Google Play Services updated (Android)
- [ ] Safari updated (iOS)

---

## Continuous Integration Setup

### GitHub Actions Example

```yaml
name: Flutter Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter pub outdated
      - run: flutter analyze
      - run: flutter test
```

---

## Troubleshooting Guide

### Symptom: "Package geolocator not found"

**Solution:**
```bash
flutter pub cache clean
flutter pub get
flutter pub add geolocator
```

### Symptom: "AndroidManifestMergeException"

**Solution:**
- Check AndroidManifest.xml for duplicate permissions
- Ensure all closing tags are present
- Run: `flutter clean && flutter pub get`

### Symptom: "Geolocator methods not available"

**Solution:**
```dart
// Check import
import 'package:geolocator/geolocator.dart';

// Verify usage
final position = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.best,
  ),
);
```

### Symptom: "CocoaPods could not find compatible versions"

**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
cd ..
flutter pub get
flutter run
```

---

## Security Best Practices

### Private Keys & Secrets
```yaml
# Don't commit these:
- google_maps_api_key
- firebase_config.json
- supabase_url (if sensitive)
- supabase_key (if private)

# Use .gitignore
echo "*.config" >> .gitignore
echo "*.env" >> .gitignore
```

### Dependency Scanning

```bash
# Check for security vulnerabilities
flutter pub audit

# Check outdated packages with security issues
flutter pub outdated --mode=null-safety
```

---

## Performance Optimization

### Minimize App Size
```bash
# Android
flutter build apk --split-per-abi

# iOS
flutter build ipa --release
```

### Location Updates Optimization

In `delivery_location_service.dart`, adjust:
```dart
static const int _updateIntervalSeconds = 10; // Can increase to 15-20
static const double _distanceFilterMeters = 5; // Can increase to 10
```

---

## Summary

All dependencies are now configured! ✅

Next steps:
1. Run `flutter pub get`
2. Follow DELIVERY_TRACKING_QUICK_START.md
3. Test on real device
4. Integrate into your app

**Total Setup Time: ~10 minutes**
