import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/delivery_status.dart';
import 'delivery_tracking_service.dart';

class DeliveryLocationService {
  // Singleton pattern
  static final DeliveryLocationService _instance = DeliveryLocationService._internal();
  factory DeliveryLocationService() => _instance;
  DeliveryLocationService._internal();
  
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  
  static const int _updateIntervalSeconds = 10; // Update location every 10 seconds
  static const int _distanceFilterMeters = 5; // Minimum 5 meters movement to trigger update

  // Track active assignment and subscription
  String? _currentAssignmentId;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;
  String? get currentAssignmentId => _currentAssignmentId;

  // Start tracking location for a delivery assignment
  Future<void> startLocationTracking({
    required String assignmentId,
    required Function(Position) onLocationUpdate,
  }) async {
    try {
      // If already tracking the same assignment, don't restart
      if (_isTracking && _currentAssignmentId == assignmentId) {
        debugPrint('📍 Already tracking assignment: $assignmentId');
        return;
      }

      // Stop previous tracking if different assignment
      if (_isTracking && _currentAssignmentId != assignmentId) {
        await stopLocationTracking();
      }

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

      _currentAssignmentId = assignmentId;
      _isTracking = true;

      _positionSubscription = positionStream.listen(
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
          _isTracking = false;
        },
      );

      debugPrint('✅ Location tracking started for assignment: $assignmentId');
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
      _isTracking = false;
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
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _currentAssignmentId = null;
      _isTracking = false;
      debugPrint('✅ Location tracking stopped');
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
