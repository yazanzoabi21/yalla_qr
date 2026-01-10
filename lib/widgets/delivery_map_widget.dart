import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/delivery_live_location.dart';
import '../models/delivery_location_history.dart';
import '../services/delivery_tracking_service.dart';

class DeliveryMapWidget extends StatefulWidget {
  final String assignmentId;
  final bool isFullScreen;
  final double? height;

  const DeliveryMapWidget({
    super.key,
    required this.assignmentId,
    this.isFullScreen = false,
    this.height,
  });

  @override
  State<DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<DeliveryMapWidget> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  final MapController _mapController = MapController();
  
  DeliveryLiveLocation? _currentLocation;
  List<DeliveryLocationHistory> _locationHistory = [];
  bool _followDriver = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeliveryLiveLocation?>(
      stream: _trackingService.streamLiveLocation(widget.assignmentId),
      builder: (context, liveSnapshot) {
        return StreamBuilder<List<DeliveryLocationHistory>>(
          stream: _trackingService.streamLocationHistory(widget.assignmentId),
          builder: (context, historySnapshot) {
            _currentLocation = liveSnapshot.data;
            _locationHistory = historySnapshot.data ?? [];

            // Get center point - use current location or last history point
            LatLng center = const LatLng(34.4545, 35.8128); // Default to Tripoli, Lebanon
            
            if (_currentLocation != null) {
              center = LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
            } else if (_locationHistory.isNotEmpty) {
              final lastPoint = _locationHistory.first;
              center = LatLng(lastPoint.latitude, lastPoint.longitude);
            }

            // Auto-follow driver when new location comes in
            if (_followDriver && _currentLocation != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  _mapController.move(center, _mapController.camera.zoom);
                } catch (_) {}
              });
            }

            return Container(
              height: widget.isFullScreen ? null : (widget.height ?? 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 16.0,
                      minZoom: 5.0,
                      maxZoom: 18.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          // User manually moved map, stop auto-following
                          setState(() {
                            _followDriver = false;
                          });
                        }
                      },
                    ),
                    children: [
                      // OpenStreetMap Tile Layer
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.yalla_qr',
                        maxZoom: 19,
                      ),
                      // Route Polyline (location history trail)
                      if (_locationHistory.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _buildRoutePoints(),
                              color: Colors.blue.withOpacity(0.7),
                              strokeWidth: 4.0,
                            ),
                          ],
                        ),
                      // Location History Markers (small dots)
                      MarkerLayer(
                        markers: _buildHistoryMarkers(),
                      ),
                      // Current Location Marker (driver)
                      if (_currentLocation != null)
                        MarkerLayer(
                          markers: [
                            _buildDriverMarker(),
                          ],
                        ),
                    ],
                  ),
                  // Map Controls Overlay
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Column(
                      children: [
                        // Follow Driver Button
                        _buildMapButton(
                          icon: _followDriver ? Icons.gps_fixed : Icons.gps_not_fixed,
                          color: _followDriver ? Colors.blue : Colors.grey,
                          onTap: () {
                            setState(() {
                              _followDriver = !_followDriver;
                            });
                            if (_followDriver && _currentLocation != null) {
                              _mapController.move(
                                LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
                                _mapController.camera.zoom,
                              );
                            }
                          },
                          tooltip: _followDriver ? 'Following driver' : 'Follow driver',
                        ),
                        const SizedBox(height: 8),
                        // Zoom In
                        _buildMapButton(
                          icon: Icons.add,
                          onTap: () {
                            final zoom = _mapController.camera.zoom + 1;
                            _mapController.move(_mapController.camera.center, zoom.clamp(5.0, 18.0));
                          },
                          tooltip: 'Zoom in',
                        ),
                        const SizedBox(height: 8),
                        // Zoom Out
                        _buildMapButton(
                          icon: Icons.remove,
                          onTap: () {
                            final zoom = _mapController.camera.zoom - 1;
                            _mapController.move(_mapController.camera.center, zoom.clamp(5.0, 18.0));
                          },
                          tooltip: 'Zoom out',
                        ),
                        const SizedBox(height: 8),
                        // Fit All Points
                        if (_locationHistory.isNotEmpty)
                          _buildMapButton(
                            icon: Icons.fit_screen,
                            onTap: _fitAllPoints,
                            tooltip: 'Fit all points',
                          ),
                        const SizedBox(height: 8),
                        // Fullscreen Toggle
                        if (!widget.isFullScreen)
                          _buildMapButton(
                            icon: Icons.fullscreen,
                            onTap: () => _openFullScreenMap(context),
                            tooltip: 'Fullscreen',
                          ),
                      ],
                    ),
                  ),
                  // Speed & Status Overlay
                  if (_currentLocation != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.speed, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '${(_currentLocation!.speed ?? 0).toStringAsFixed(1)} km/h',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _isMoving() ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isMoving() ? 'Moving' : 'Stopped',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isMoving() ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // No Location Data Message
                  if (_currentLocation == null && _locationHistory.isEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Waiting for location data...',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Start tracking to see driver location',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<LatLng> _buildRoutePoints() {
    // Build route from history (oldest to newest)
    final points = _locationHistory.reversed.map((h) => LatLng(h.latitude, h.longitude)).toList();
    
    // Add current location as the latest point
    if (_currentLocation != null) {
      points.add(LatLng(_currentLocation!.latitude, _currentLocation!.longitude));
    }
    
    return points;
  }

  List<Marker> _buildHistoryMarkers() {
    return _locationHistory.asMap().entries.map((entry) {
      final index = entry.key;
      final history = entry.value;
      final isFirst = index == _locationHistory.length - 1; // Oldest point (start)
      
      return Marker(
        point: LatLng(history.latitude, history.longitude),
        width: isFirst ? 24 : 12,
        height: isFirst ? 24 : 12,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFirst ? Colors.green : Colors.blue.withOpacity(0.5),
            border: Border.all(
              color: isFirst ? Colors.green.shade700 : Colors.blue.shade700,
              width: 2,
            ),
          ),
          child: isFirst
              ? const Icon(Icons.play_arrow, size: 14, color: Colors.white)
              : null,
        ),
      );
    }).toList();
  }

  Marker _buildDriverMarker() {
    final heading = _currentLocation!.heading ?? 0;
    
    return Marker(
      point: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
      width: 50,
      height: 50,
      child: Transform.rotate(
        angle: heading * (3.14159 / 180), // Convert degrees to radians
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, color: color ?? Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  void _fitAllPoints() {
    if (_locationHistory.isEmpty && _currentLocation == null) return;

    final points = <LatLng>[];
    
    for (final h in _locationHistory) {
      points.add(LatLng(h.latitude, h.longitude));
    }
    
    if (_currentLocation != null) {
      points.add(LatLng(_currentLocation!.latitude, _currentLocation!.longitude));
    }

    if (points.isEmpty) return;

    // Calculate bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - latPadding, minLng - lngPadding),
          LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        padding: const EdgeInsets.all(50),
      ),
    );

    setState(() {
      _followDriver = false;
    });
  }

  bool _isMoving() {
    return (_currentLocation?.speed ?? 0) > 0.5;
  }

  void _openFullScreenMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Live Tracking'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          body: DeliveryMapWidget(
            assignmentId: widget.assignmentId,
            isFullScreen: true,
          ),
        ),
      ),
    );
  }
}
