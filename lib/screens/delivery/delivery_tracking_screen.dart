import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/order.dart';
import '../../models/order_delivery_assignment.dart';
import '../../services/delivery_tracking_service.dart';
import '../../services/delivery_location_service.dart';
import '../../services/order_service.dart';
import '../../widgets/delivery_tracking_widget.dart';
import '../../widgets/navbar.dart';

/// Example screen showing how to use the delivery tracking system
/// This demonstrates both driver and customer perspectives
class DeliveryTrackingScreen extends StatefulWidget {
  final String assignmentId;
  final String orderNumber;
  final bool isDriver;

  const DeliveryTrackingScreen({
    super.key,
    required this.assignmentId,
    required this.orderNumber,
    required this.isDriver,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  final DeliveryLocationService _locationService = DeliveryLocationService();
  final OrderService _orderService = OrderService();

  late OrderDeliveryAssignment assignment;
  bool isLoading = true;
  bool isTrackingActive = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssignmentData();
    if (widget.isDriver) {
      _initializeTracking();
    }
  }

  Future<void> _loadAssignmentData() async {
    try {
      // Load the delivery assignment data
      // This is a placeholder - implement based on your data structure
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading delivery: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _initializeTracking() async {
    try {
      // Initialize tracking in Supabase
      await _trackingService.initializeDeliveryTracking(widget.assignmentId);

      // Check if location services are available
      final isEnabled = await _locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services are disabled'),
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () async {
                  await _locationService.openLocationSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      // Request location permissions
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for delivery tracking'),
            ),
          );
        }
        return;
      }

      // Start location tracking
      await _locationService.startLocationTracking(
        assignmentId: widget.assignmentId,
        onLocationUpdate: (position) {
          debugPrint(
            'Location updated: ${position.latitude}, ${position.longitude}',
          );
        },
      );

      if (mounted) {
        setState(() {
          isTrackingActive = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing tracking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.isDriver) {
      _locationService.stopLocationTracking();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Tracking'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Information Card
                    _buildOrderInfoCard(),
                    const SizedBox(height: 16),

                    // Driver Status Card (if driver)
                    if (widget.isDriver) _buildDriverStatusCard(),
                    if (widget.isDriver) const SizedBox(height: 16),

                    // Main Tracking Widget
                    DeliveryTrackingWidget(
                      assignmentId: widget.assignmentId,
                      orderNumber: widget.orderNumber,
                      isDriver: widget.isDriver,
                      onStatusChanged: () {
                        // Refresh or trigger actions on status change
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    if (widget.isDriver) _buildDriverActionButtons(),

                    // Error Message
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const Navbar(),
    );
  }

  Widget _buildOrderInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Number',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  widget.orderNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Assignment ID',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  widget.assignmentId.substring(0, 8),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverStatusCard() {
    return Card(
      color: isTrackingActive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  const Text(
                    'Location Tracking',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isTrackingActive ? 'Active - Location being shared' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: isTrackingActive ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isTrackingActive ? null : _initializeTracking,
            icon: const Icon(Icons.location_on),
            label: const Text('Start Location Sharing'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showContactSupport,
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showContactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('How would you like to contact support?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Implement phone call
              Navigator.pop(context);
            },
            child: const Text('Call'),
          ),
          TextButton(
            onPressed: () {
              // Implement chat
              Navigator.pop(context);
            },
            child: const Text('Chat'),
          ),
        ],
      ),
    );
  }
}
