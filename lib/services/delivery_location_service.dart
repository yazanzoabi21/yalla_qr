import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../models/delivery_status.dart';
import 'delivery_tracking_service.dart';

class DeliveryLocationService {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  
  static const int _updateIntervalSeconds = 10; // Update location every 10 seconds
  static const int _distanceFilterMeters = 5; // Minimum 5 meters movement to trigger update

  // Start tracking location for a delivery assignment
  Future<void> startLocationTracking({
    required String assignmentId,
    required Function(Position) onLocationUpdate,
  }) async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        await Geolocator.openLocationSettings();
        return;
      }

      // Start position stream
      final positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: _distanceFilterMeters,
          timeLimit: const Duration(seconds: 30),
        ),
      );

      positionStream.listen(
        (Position position) async {
          onLocationUpdate(position);
          
          // Update delivery tracking service
          await _trackingService.updateLiveLocation(
            assignmentId: assignmentId,
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
            heading: position.heading,
          );

          // Check if arriving (you can customize this logic)
          await _checkArrivingStatus(assignmentId, position);
        },
        onError: (error) {
          debugPrint('❌ Location stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
      rethrow;
    }
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 30),
      );
    } catch (e) {
      debugPrint('❌ Error getting current position: $e');
      return null;
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    try {
      // Geolocator will stop listening when the stream is closed
      debugPrint('Location tracking stopped');
    } catch (e) {
      debugPrint('❌ Error stopping location tracking: $e');
    }
  }

  // Check if delivery is arriving (within certain distance)
  Future<void> _checkArrivingStatus(
    String assignmentId,
    Position currentPosition,
  ) async {
    try {
      // Get delivery destination coordinates (you'll need to fetch this from your order data)
      // For now, this is a placeholder - integrate with your order service
      
      // Example: check if within 100 meters of destination
      // double distance = _trackingService.calculateDistance(
      //   currentPosition.latitude,
      //   currentPosition.longitude,
      //   destinationLat,
      //   destinationLng,
      // );

      // if (distance < 0.1) { // 0.1 km = 100 meters
      //   await _trackingService.updateDeliveryStatus(
      //     assignmentId: assignmentId,
      //     status: DeliveryStatusType.arriving,
      //   );
      // }
    } catch (e) {
      debugPrint('❌ Error checking arriving status: $e');
    }
  }

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // Calculate distance between two points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Calculate bearing (direction) between two points
  double calculateBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
