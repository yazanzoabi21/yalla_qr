# Delivery Tracking System - Implementation Guide

This guide explains how to integrate the real-time delivery tracking system into your Yalla QR application.

## Overview

The delivery tracking system allows:
- **Delivery Drivers**: Share real-time GPS location while making deliveries
- **Customers**: Track incoming deliveries in real-time
- **Organizations**: Monitor all active deliveries with live location updates
- **Complete History**: Full location history and delivery status tracking

## Files Created

### SQL Migrations
1. **create_delivery_live_locations.sql** - Real-time current location tracking
2. **create_delivery_location_history.sql** - Historical location data
3. **create_delivery_status.sql** - Delivery status tracking (pending, en-route, arriving, completed, etc.)

### Dart Models
1. **lib/models/delivery_live_location.dart** - Current location model
2. **lib/models/delivery_location_history.dart** - Location history model
3. **lib/models/delivery_status.dart** - Delivery status with enum types

### Dart Services
1. **lib/services/delivery_tracking_service.dart** - Main service for tracking operations
   - Stream live locations
   - Update locations
   - Update delivery status
   - Manage location history
   - Distance calculations

2. **lib/services/delivery_location_service.dart** - GPS location handling
   - GPS tracking with background support
   - Distance/bearing calculations
   - Automatic "arriving" detection
   - Permission handling

### UI Widgets
1. **lib/widgets/delivery_tracking_widget.dart** - Complete tracking UI component
   - Real-time location display
   - Status updates
   - Location history view
   - Distance and speed display

## Installation Steps

### 1. Apply SQL Migrations to Supabase

1. Go to Supabase Dashboard
2. Navigate to SQL Editor
3. Run each SQL file:
   - First: `create_delivery_live_locations.sql`
   - Second: `create_delivery_location_history.sql`
   - Third: `create_delivery_status.sql`

### 2. Update pubspec.yaml

Add these dependencies if not already present:

```yaml
dependencies:
  geolocator: ^9.0.0
  google_maps_flutter: ^2.0.0  # Optional for map display
```

### 3. Platform-Specific Configuration

#### Android (android/app/build.gradle)
```gradle
android {
    compileSdk 34
    
    defaultConfig {
        targetSdk 34
    }
}
```

#### Android Manifest (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<service
    android:name="com.baseflow.geolocator.LocationUpdatesService"
    android:enabled="true"
    android:exported="false" />
```

#### iOS (ios/Runner/Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to track deliveries</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs your location to track deliveries</string>
```

## Usage Examples

### 1. Display Delivery Tracking Widget

In your delivery/order screen:

```dart
DeliveryTrackingWidget(
  assignmentId: deliveryAssignment.id,
  orderNumber: order.orderNumber,
  isDriver: isCurrentUserDriver,
  onStatusChanged: () {
    // Refresh UI or trigger notifications
  },
),
```

### 2. Start GPS Tracking (Driver Side)

```dart
final locationService = DeliveryLocationService();

// Start tracking
await locationService.startLocationTracking(
  assignmentId: assignmentId,
  onLocationUpdate: (position) {
    print('Updated location: ${position.latitude}, ${position.longitude}');
  },
);
```

### 3. Get Current Delivery Status

```dart
final trackingService = DeliveryTrackingService();

final status = await trackingService.getDeliveryStatus(assignmentId);
print('Status: ${status?.status.displayName}');
```

### 4. Update Delivery Status (Manual)

```dart
await trackingService.updateDeliveryStatus(
  assignmentId: assignmentId,
  status: DeliveryStatusType.enRoute,
);
```

### 5. Stream Location History

```dart
trackingService.streamLocationHistory(assignmentId).listen((history) {
  print('Location history: ${history.length} points');
  // Update UI with history
});
```

## Real-Time Features

### Location Streaming
- Updates every 10 seconds (configurable)
- Minimum 5 meters movement to update (prevents noise)
- Full GPS data: latitude, longitude, speed, heading
- Automatic recording to history

### Status Types
- **Pending** - Delivery assigned but not accepted
- **Accepted** - Driver accepted the delivery
- **En Route** - Driver heading to delivery location
- **Arriving** - Driver near destination (auto-detected)
- **Arrived** - Driver at location
- **Completed** - Delivery completed
- **Cancelled** - Delivery cancelled

### Visibility
- **Drivers**: Can see their own location and status
- **Customers**: Can see incoming delivery location and status
- **Organizations**: Can see all delivery locations (if they have the account assigned)

## Row Level Security (RLS)

All tables have RLS policies:
- Users can only view their own deliveries
- Drivers can only update their own locations
- Organizations can view deliveries they're assigned to

## Performance Optimization

1. **Location Updates**: Only sent when movement > 5 meters
2. **Stream Limits**: Max 100 history points per stream
3. **Indexes**: Multiple indexes for fast queries
4. **Unique Constraints**: One live location per assignment

## Troubleshooting

### Permissions Not Working
- Check AndroidManifest.xml and Info.plist
- Request permissions explicitly in app
- Test on actual device (not emulator)

### Location Not Updating
- Check GPS is enabled on device
- Verify permissions are granted
- Check internet connectivity
- Review delivery_tracking_service.dart logs

### Stream Not Showing Data
- Ensure assignment exists in database
- Verify RLS policies allow access
- Check that status has been initialized

## Integration Checklist

- [ ] Run SQL migrations
- [ ] Add geolocator dependency
- [ ] Configure Android permissions
- [ ] Configure iOS permissions
- [ ] Import DeliveryTrackingWidget in screens
- [ ] Add location tracking to driver flow
- [ ] Test with real device
- [ ] Implement push notifications for status changes
- [ ] Add map view (optional but recommended)

## Advanced Features to Add

1. **Push Notifications**: Notify users when status changes
2. **Map Display**: Show real-time driver location on map
3. **ETA Calculation**: Estimate arrival time
4. **Geofencing**: Trigger "arriving" automatically
5. **Route Optimization**: Calculate best delivery routes
6. **Signature Capture**: Collect signatures on delivery
7. **Photo Upload**: Document delivery completion

## Support

For issues or questions, refer to:
- [Geolocator Documentation](https://pub.dev/packages/geolocator)
- [Supabase Real-Time Docs](https://supabase.com/docs/guides/realtime)
- Flutter Location Services Best Practices
