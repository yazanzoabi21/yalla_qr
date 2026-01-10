# Quick Integration Checklist for Delivery Tracking

## 🗄️ Database Setup (Supabase)

### Step 1: Create Tables
```
☐ Open Supabase Dashboard
☐ Go to SQL Editor
☐ Copy and run: create_delivery_live_locations.sql
☐ Copy and run: create_delivery_location_history.sql
☐ Copy and run: create_delivery_status.sql
☐ Verify all 3 tables appear in Table Editor
```

### Step 2: Verify RLS Policies
```
☐ Navigate to Authentication > Policies
☐ Check delivery_live_locations has 3 policies
☐ Check delivery_location_history has 2 policies
☐ Check delivery_status has 3 policies
```

---

## 📱 Mobile App Setup

### Step 1: Add Dependencies
```bash
# In your Flutter project root:
flutter pub add geolocator

# Verify in pubspec.yaml:
# geolocator: ^9.0.0
```

### Step 2: Copy Files to Project
```
☐ Copy delivery_live_location.dart → lib/models/
☐ Copy delivery_location_history.dart → lib/models/
☐ Copy delivery_status.dart → lib/models/
☐ Copy delivery_tracking_service.dart → lib/services/
☐ Copy delivery_location_service.dart → lib/services/
☐ Copy delivery_tracking_widget.dart → lib/widgets/
☐ Copy delivery_tracking_screen.dart → lib/screens/delivery/
```

### Step 3: Android Configuration
```
File: android/app/src/main/AndroidManifest.xml

Add these permissions inside <manifest> tag:
☐ <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
☐ <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
☐ <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

Add this service inside <application> tag:
☐ <service
       android:name="com.baseflow.geolocator.LocationUpdatesService"
       android:enabled="true"
       android:exported="false" />
```

### Step 4: Android Build Configuration
```
File: android/app/build.gradle.kts (or android/app/build.gradle)

Update compileSdk:
☐ compileSdk = 34  (minimum)

Update targetSdk:
☐ targetSdk = 34  (minimum)
```

### Step 5: iOS Configuration
```
File: ios/Runner/Info.plist

Add these keys (right after opening <dict>):

☐ <key>NSLocationWhenInUseUsageDescription</key>
  <string>This app needs your location to track deliveries in real-time</string>

☐ <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>This app needs your location to track deliveries in real-time</string>

☐ <key>NSLocationAlwaysUsageDescription</key>
  <string>This app needs your location to track deliveries in real-time</string>
```

### Step 6: Flutter Configuration
```
File: pubspec.yaml

☐ Ensure these are already present:
   - supabase_flutter: ^2.0.0 or later
   - shared_preferences: ^2.0.0 or later

☐ Run: flutter pub get
```

---

## 🎯 Integration Points

### In Your Order/Delivery Screen:
```dart
// Import the widget
import 'package:yalla_qr/widgets/delivery_tracking_widget.dart';

// Add to your widget tree:
DeliveryTrackingWidget(
  assignmentId: deliveryAssignment.id,
  orderNumber: order.orderNumber,
  isDriver: isCurrentUserDriver,
  onStatusChanged: () {
    // Refresh UI or trigger notifications
  },
)
```

### In Your Driver's Delivery Screen:
```dart
// Import the service
import 'package:yalla_qr/services/delivery_location_service.dart';

// In initState:
final locationService = DeliveryLocationService();
await locationService.startLocationTracking(
  assignmentId: assignmentId,
  onLocationUpdate: (position) {
    print('Location: ${position.latitude}, ${position.longitude}');
  },
);

// In dispose:
await locationService.stopLocationTracking();
```

---

## ✅ Testing Checklist

### Android Testing
```
☐ Install app on Android device
☐ Go to Settings > Apps > Permissions > Location
☐ Grant "Allow all the time" for your app
☐ Go to Settings > Location
☐ Ensure "Location services" is ON
☐ Launch app and test location tracking
☐ Verify location updates every 10 seconds
☐ Monitor logcat for no errors
```

### iOS Testing
```
☐ Install app on iPhone
☐ Go to Settings > Privacy > Location Services
☐ Grant location permission for your app
☐ Select "Always" or "While Using"
☐ Launch app and test location tracking
☐ Verify location updates every 10 seconds
```

### Functional Testing
```
☐ Driver can start location tracking
☐ Live location updates appear in real-time
☐ Location history populates correctly
☐ Status can be updated (driver view)
☐ Customer can see live location
☐ Customer can see status updates
☐ No location visible without permission
☐ RLS policies prevent unauthorized access
```

---

## 📊 Database Monitoring

### Check Table Sizes:
```sql
-- Run in Supabase SQL Editor
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename IN ('delivery_live_locations', 'delivery_location_history', 'delivery_status')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Check Row Counts:
```sql
SELECT COUNT(*) as count FROM delivery_live_locations;
SELECT COUNT(*) as count FROM delivery_location_history;
SELECT COUNT(*) as count FROM delivery_status;
```

### Check Index Usage:
```sql
SELECT * FROM pg_stat_user_indexes 
WHERE tablename IN ('delivery_live_locations', 'delivery_location_history', 'delivery_status');
```

---

## 🐛 Troubleshooting

### Location Permission Denied
```
❌ Problem: "Location permission denied"
✅ Solution: 
   - Ensure AndroidManifest.xml has all 3 permissions
   - For iOS, check Info.plist has the keys
   - For Android, manually grant in app settings
   - On emulator: Enable mock location provider
```

### No Location Updates
```
❌ Problem: "Location updates not happening"
✅ Solution:
   - Verify GPS is enabled on device
   - Check internet connection (for Supabase sync)
   - Verify RLS policies allow access
   - Check that DeliveryTrackingService.initializeDeliveryTracking() was called
```

### Real-Time Not Working
```
❌ Problem: "Real-time streams not updating"
✅ Solution:
   - Verify Supabase Realtime is enabled
   - Check RLS policies match your user/org structure
   - Ensure assignment exists in order_delivery_assignments
   - Check browser console for WebSocket errors
```

### High Battery Drain
```
❌ Problem: "App draining battery"
✅ Solution:
   - Tracking updates every 10 seconds (necessary for delivery)
   - Only run tracking when needed (driver has active delivery)
   - Call stopLocationTracking() when delivery is complete
   - Consider increasing update interval to 15-20 seconds if acceptable
```

---

## 🚀 Performance Tips

### Optimize for Battery:
```dart
// Don't track inactive deliveries
if (status == DeliveryStatusType.completed) {
  await locationService.stopLocationTracking();
}
```

### Optimize Database:
```dart
// Limit history queries
trackingService.streamLocationHistory(
  assignmentId,
  limit: 50,  // Show last 50 points instead of 100
)
```

### Network Optimization:
```dart
// Adjust update interval if needed
// Change _updateIntervalSeconds in delivery_location_service.dart
// Default: 10 seconds (recommended for delivery accuracy)
// Max acceptable: 30 seconds
```

---

## 📝 Notes

- **Real-time Updates**: Supabase Realtime uses WebSockets for instant updates
- **Location Privacy**: All data is encrypted and subject to RLS policies
- **History Cleanup**: Consider implementing automatic history cleanup after 30 days (optional)
- **Backup Strategy**: Location history provides audit trail of deliveries

---

## ✨ Optional Enhancements

### Add Google Maps Display:
```bash
flutter pub add google_maps_flutter
flutter pub add google_maps_flutter_web
```

### Add Push Notifications:
```bash
flutter pub add firebase_messaging
```

### Add Photo/Signature Capture:
```bash
flutter pub add image_picker
flutter pub add signature
```

---

**Last Updated**: January 8, 2026
**Status**: Ready for Integration
**Estimated Setup Time**: 30-45 minutes
