# Delivery Tracking - Code Examples & Integration Patterns

## Example 1: Basic Implementation in Order/Delivery Screen

```dart
import 'package:flutter/material.dart';
import 'package:yalla_qr/widgets/delivery_tracking_widget.dart';
import 'package:yalla_qr/models/order_delivery_assignment.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  
  const OrderDetailScreen({required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDeliveryAssignment? assignment;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Order info...
            
            // Add tracking widget if delivery is assigned
            if (assignment != null)
              DeliveryTrackingWidget(
                assignmentId: assignment!.id,
                orderNumber: 'ORD-12345',
                isDriver: isCurrentUserDriver(),
                onStatusChanged: () {
                  setState(() {}); // Refresh UI
                },
              ),
          ],
        ),
      ),
    );
  }
  
  bool isCurrentUserDriver() {
    // Check if current user is the assigned driver
    return false;
  }
}
```

---

## Example 2: Driver Delivery Screen with Location Tracking

```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yalla_qr/services/delivery_location_service.dart';
import 'package:yalla_qr/services/delivery_tracking_service.dart';
import 'package:yalla_qr/models/delivery_status.dart';

class DriverDeliveryScreen extends StatefulWidget {
  final String assignmentId;
  
  const DriverDeliveryScreen({required this.assignmentId});

  @override
  State<DriverDeliveryScreen> createState() => _DriverDeliveryScreenState();
}

class _DriverDeliveryScreenState extends State<DriverDeliveryScreen> {
  final DeliveryLocationService _locationService = DeliveryLocationService();
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  
  bool isTrackingActive = false;
  String? currentLocation;
  
  @override
  void initState() {
    super.initState();
    _initializeDelivery();
  }
  
  Future<void> _initializeDelivery() async {
    try {
      // Initialize tracking in database
      await _trackingService.initializeDeliveryTracking(widget.assignmentId);
      
      // Check location services
      final isEnabled = await _locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        _showLocationDisabledDialog();
        return;
      }
      
      // Request permissions
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        return;
      }
      
      // Start tracking
      await _startLocationTracking();
    } catch (e) {
      _showError('Error initializing delivery: $e');
    }
  }
  
  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startLocationTracking(
        assignmentId: widget.assignmentId,
        onLocationUpdate: (position) {
          setState(() {
            currentLocation = '${position.latitude.toStringAsFixed(4)}, '
                '${position.longitude.toStringAsFixed(4)}';
          });
          debugPrint('Location: $currentLocation');
        },
      );
      
      setState(() => isTrackingActive = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location tracking started')),
        );
      }
    } catch (e) {
      _showError('Error starting location tracking: $e');
    }
  }
  
  Future<void> _updateDeliveryStatus(DeliveryStatusType status) async {
    try {
      await _trackingService.updateDeliveryStatus(
        assignmentId: widget.assignmentId,
        status: status,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${status.displayName}')),
        );
      }
    } catch (e) {
      _showError('Error updating status: $e');
    }
  }
  
  @override
  void dispose() {
    _locationService.stopLocationTracking();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery')),
      body: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: isTrackingActive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  isTrackingActive ? Icons.location_on : Icons.location_off,
                  color: isTrackingActive ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Location Tracking',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(isTrackingActive
                          ? 'Active - ${currentLocation ?? 'Getting location...'}'
                          : 'Not active'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!isTrackingActive)
                  ElevatedButton.icon(
                    onPressed: _startLocationTracking,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Start Sharing Location'),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _updateDeliveryStatus(DeliveryStatusType.enRoute),
                  icon: const Icon(Icons.directions),
                  label: const Text('Mark En Route'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _updateDeliveryStatus(DeliveryStatusType.arriving),
                  icon: const Icon(Icons.location_on),
                  label: const Text('Mark Arriving'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _updateDeliveryStatus(DeliveryStatusType.completed),
                  icon: const Icon(Icons.done),
                  label: const Text('Mark Completed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services to start delivery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _locationService.openLocationSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Location permission is required for delivery tracking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
```

---

## Example 3: Customer Tracking View

```dart
import 'package:flutter/material.dart';
import 'package:yalla_qr/models/delivery_live_location.dart';
import 'package:yalla_qr/models/delivery_status.dart';
import 'package:yalla_qr/services/delivery_tracking_service.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String assignmentId;
  final String orderNumber;
  
  const CustomerTrackingScreen({
    required this.assignmentId,
    required this.orderNumber,
  });

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Delivery')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Number',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(widget.orderNumber,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Status card
              _buildStatusCard(),
              const SizedBox(height: 16),
              
              // Location card
              _buildLocationCard(),
              const SizedBox(height: 16),
              
              // Estimated arrival
              _buildEstimatedArrivalCard(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusCard() {
    return StreamBuilder<DeliveryStatus?>(
      stream: _trackingService.streamDeliveryStatus(widget.assignmentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final status = snapshot.data!;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _getStatusIcon(status.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status.status.displayName,
                              style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          Text('Updated ${_timeAgo(status.updatedAt)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildLocationCard() {
    return StreamBuilder<DeliveryLiveLocation?>(
      stream: _trackingService.streamLiveLocation(widget.assignmentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Waiting for location...'),
            ),
          );
        }
        
        final location = snapshot.data!;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildLocationRow('Latitude', location.latitude.toString()),
                _buildLocationRow('Longitude', location.longitude.toString()),
                if (location.speed != null)
                  _buildLocationRow('Speed',
                      '${location.speed!.toStringAsFixed(1)} m/s'),
                _buildLocationRow('Updated', _timeAgo(location.updatedAt)),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEstimatedArrivalCard() {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estimated Arrival',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<DeliveryStatus?>(
              stream: _trackingService.streamDeliveryStatus(widget.assignmentId),
              builder: (context, snapshot) {
                if (snapshot.data?.status == DeliveryStatusType.arriving) {
                  return const Text('Arriving shortly...',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange));
                }
                return const Text('Check back for updates',
                    style: TextStyle(fontSize: 14));
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  Icon _getStatusIcon(DeliveryStatusType status) {
    switch (status) {
      case DeliveryStatusType.pending:
        return const Icon(Icons.schedule, color: Colors.orange, size: 32);
      case DeliveryStatusType.accepted:
        return const Icon(Icons.check_circle, color: Colors.blue, size: 32);
      case DeliveryStatusType.enRoute:
        return const Icon(Icons.directions, color: Colors.blue, size: 32);
      case DeliveryStatusType.arriving:
        return const Icon(Icons.location_on, color: Colors.orange, size: 32);
      case DeliveryStatusType.arrived:
        return const Icon(Icons.location_on, color: Colors.green, size: 32);
      case DeliveryStatusType.completed:
        return const Icon(Icons.done_all, color: Colors.green, size: 32);
      case DeliveryStatusType.cancelled:
        return const Icon(Icons.cancel, color: Colors.red, size: 32);
    }
  }
  
  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
```

---

## Example 4: Stream-Based Real-Time Updates

```dart
// Listen to multiple streams simultaneously
class MultiStreamTrackingWidget extends StatelessWidget {
  final String assignmentId;
  final DeliveryTrackingService trackingService;
  
  const MultiStreamTrackingWidget({
    required this.assignmentId,
    required this.trackingService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: CombineLatestStream.list<dynamic>([
        trackingService.streamDeliveryStatus(assignmentId),
        trackingService.streamLiveLocation(assignmentId),
        trackingService.streamLocationHistory(assignmentId),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final status = snapshot.data![0] as DeliveryStatus?;
        final location = snapshot.data![1] as DeliveryLiveLocation?;
        final history = snapshot.data![2] as List<DeliveryLocationHistory>;
        
        return Column(
          children: [
            if (status != null) Text('Status: ${status.status.displayName}'),
            if (location != null)
              Text('Location: ${location.latitude}, ${location.longitude}'),
            Text('History points: ${history.length}'),
          ],
        );
      },
    );
  }
}

// To use CombineLatestStream:
// flutter pub add rxdart
```

---

## Example 5: Error Handling Pattern

```dart
Future<void> safelyUpdateLocation({
  required String assignmentId,
  required double latitude,
  required double longitude,
}) async {
  try {
    await _trackingService.updateLiveLocation(
      assignmentId: assignmentId,
      latitude: latitude,
      longitude: longitude,
    );
  } on SocketException {
    // Network error - can retry later
    debugPrint('Network error - will retry');
  } on PostgrestException catch (e) {
    // Database error
    debugPrint('Database error: ${e.message}');
    if (e.code == '23505') {
      // Unique constraint violated - update instead of insert
      debugPrint('Updating existing record');
    }
  } catch (e) {
    // Unknown error
    debugPrint('Unexpected error: $e');
    rethrow;
  }
}
```

---

## Example 6: Performance Optimization

```dart
// Limit history to recent points only
Future<List<DeliveryLocationHistory>> getRecentHistory(String assignmentId) async {
  return _trackingService.getLocationHistory(
    assignmentId,
    limit: 50, // Only last 50 points instead of 100
  );
}

// Batch updates for multiple deliveries
Future<void> updateMultipleDeliveries(
    List<String> assignmentIds) async {
  for (final id in assignmentIds) {
    try {
      await _trackingService.getLiveLocation(id);
    } catch (e) {
      debugPrint('Error loading delivery $id: $e');
      continue; // Continue with next delivery
    }
  }
}

// Debounced location updates
class DebouncedLocationTracker {
  final DeliveryLocationService _service = DeliveryLocationService();
  final Duration _debounceTime = const Duration(seconds: 5);
  DateTime _lastUpdate = DateTime.now();
  
  Future<void> updateIfNeeded(Position position) async {
    final now = DateTime.now();
    if (now.difference(_lastUpdate) > _debounceTime) {
      await _service.startLocationTracking(
        assignmentId: 'assignment_id',
        onLocationUpdate: (_) {},
      );
      _lastUpdate = now;
    }
  }
}
```

---

## Example 7: Testing

```dart
// Mock service for testing
class MockDeliveryTrackingService extends Mock implements DeliveryTrackingService {
  @override
  Stream<DeliveryLiveLocation?> streamLiveLocation(String assignmentId) {
    return Stream.value(
      DeliveryLiveLocation(
        id: 'test-id',
        assignmentId: assignmentId,
        latitude: 40.7128,
        longitude: -74.0060,
        speed: 25.0,
        heading: 180.0,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

// Test widget
void main() {
  testWidgets('Delivery tracking widget displays status', (tester) async {
    final mockService = MockDeliveryTrackingService();
    
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTrackingWidget(
          assignmentId: 'test-assignment',
          orderNumber: 'ORD-001',
          isDriver: false,
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    expect(find.byType(DeliveryTrackingWidget), findsOneWidget);
  });
}
```

---

These examples demonstrate:
- ✅ Basic widget integration
- ✅ Driver-side tracking setup
- ✅ Customer-side tracking view
- ✅ Real-time stream handling
- ✅ Error handling patterns
- ✅ Performance optimization
- ✅ Testing strategies
