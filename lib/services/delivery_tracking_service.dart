import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_live_location.dart';
import '../models/delivery_location_history.dart';
import '../models/delivery_status.dart';
import 'package:flutter/material.dart' show debugPrint;

class DeliveryTrackingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  static const String _liveLocationsTable = 'delivery_live_locations';
  static const String _locationHistoryTable = 'delivery_location_history';
  static const String _deliveryStatusTable = 'delivery_status';

  // Stream for real-time live location updates
  Stream<DeliveryLiveLocation?> streamLiveLocation(String assignmentId) {
    return _supabase
        .from(_liveLocationsTable)
        .stream(primaryKey: ['id'])
        .eq('assignment_id', assignmentId)
        .map((data) {
          if (data.isEmpty) return null;
          return DeliveryLiveLocation.fromJson(data[0]);
        });
  }

  // Stream for real-time delivery status updates
  Stream<DeliveryStatus?> streamDeliveryStatus(String assignmentId) {
    return _supabase
        .from(_deliveryStatusTable)
        .stream(primaryKey: ['id'])
        .eq('assignment_id', assignmentId)
        .map((data) {
          if (data.isEmpty) return null;
          return DeliveryStatus.fromJson(data[0]);
        });
  }

  // Stream for location history
  Stream<List<DeliveryLocationHistory>> streamLocationHistory(
    String assignmentId, {
    int limit = 100,
  }) {
    return _supabase
        .from(_locationHistoryTable)
        .stream(primaryKey: ['id'])
        .eq('assignment_id', assignmentId)
        .order('recorded_at', ascending: false)
        .limit(limit)
        .map((data) {
          return data
              .map((item) => DeliveryLocationHistory.fromJson(item))
              .toList();
        });
  }

  // Update live location - called by delivery driver
  Future<void> updateLiveLocation({
    required String assignmentId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Upsert live location (update if exists, insert if not)
      await _supabase.from(_liveLocationsTable).upsert(
        {
          'assignment_id': assignmentId,
          'lat': latitude,
          'lng': longitude,
          'speed': speed,
          'heading': heading,
          'updated_at': now.toIso8601String(),
        },
        onConflict: 'assignment_id',
      );

      // Also insert into history for tracking
      await _supabase.from(_locationHistoryTable).insert({
        'assignment_id': assignmentId,
        'lat': latitude,
        'lng': longitude,
        'speed': speed,
        'recorded_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error updating live location: $e');
      rethrow;
    }
  }

  // Update delivery status - called by delivery driver
  Future<void> updateDeliveryStatus({
    required String assignmentId,
    required DeliveryStatusType status,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Upsert delivery status
      await _supabase.from(_deliveryStatusTable).upsert(
        {
          'assignment_id': assignmentId,
          'status': status.name,
          'updated_at': now.toIso8601String(),
        },
        onConflict: 'assignment_id',
      );
    } catch (e) {
      debugPrint('❌ Error updating delivery status: $e');
      rethrow;
    }
  }

  // Get current live location
  Future<DeliveryLiveLocation?> getLiveLocation(String assignmentId) async {
    try {
      final response = await _supabase
          .from(_liveLocationsTable)
          .select()
          .eq('assignment_id', assignmentId)
          .maybeSingle();

      if (response == null) return null;
      return DeliveryLiveLocation.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error getting live location: $e');
      return null;
    }
  }

  // Get current delivery status
  Future<DeliveryStatus?> getDeliveryStatus(String assignmentId) async {
    try {
      final response = await _supabase
          .from(_deliveryStatusTable)
          .select()
          .eq('assignment_id', assignmentId)
          .maybeSingle();

      if (response == null) return null;
      return DeliveryStatus.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error getting delivery status: $e');
      return null;
    }
  }

  // Get location history for an assignment
  Future<List<DeliveryLocationHistory>> getLocationHistory(
    String assignmentId, {
    int limit = 100,
  }) async {
    try {
      final response = await _supabase
          .from(_locationHistoryTable)
          .select()
          .eq('assignment_id', assignmentId)
          .order('recorded_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => DeliveryLocationHistory.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting location history: $e');
      return [];
    }
  }

  // Initialize delivery tracking for a new assignment
  Future<void> initializeDeliveryTracking(String assignmentId) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Check if status already exists
      final existing = await _supabase
          .from(_deliveryStatusTable)
          .select()
          .eq('assignment_id', assignmentId)
          .maybeSingle();

      if (existing == null) {
        // Create initial delivery status
        await _supabase.from(_deliveryStatusTable).insert({
          'assignment_id': assignmentId,
          'status': DeliveryStatusType.pending.name,
          'updated_at': now.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing delivery tracking: $e');
      rethrow;
    }
  }

  // Calculate distance between two coordinates (in km)
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371.0;

    double dLat = _toRadian(lat2 - lat1);
    double dLng = _toRadian(lng2 - lng1);

    double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      (math.cos(_toRadian(lat1)) *
        math.cos(_toRadian(lat2)) *
        math.sin(dLng / 2) *
        math.sin(dLng / 2));

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadian(double degree) {
    return degree * (3.14159265359 / 180);
  }
}