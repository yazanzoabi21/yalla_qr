import 'package:flutter/material.dart';
import '../../models/delivery_live_location.dart';
import '../../models/delivery_status.dart';
import '../../services/delivery_tracking_service.dart';
import '../../models/delivery_location_history.dart';
import 'delivery_map_widget.dart';

class DeliveryTrackingWidget extends StatefulWidget {
  final String assignmentId;
  final String orderNumber;
  final bool isDriver; // True if viewing as delivery driver
  final VoidCallback? onStatusChanged;

  const DeliveryTrackingWidget({
    super.key,
    required this.assignmentId,
    required this.orderNumber,
    this.isDriver = false,
    this.onStatusChanged,
  });

  @override
  State<DeliveryTrackingWidget> createState() => _DeliveryTrackingWidgetState();
}

class _DeliveryTrackingWidgetState extends State<DeliveryTrackingWidget> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    try {
      await _trackingService.initializeDeliveryTracking(widget.assignmentId);
    } catch (e) {
      debugPrint('Error initializing tracking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery Status Section
        _buildStatusSection(),
        const SizedBox(height: 16),
        // Live Map Section - Shows driver movement in real-time
        _buildMapSection(),
        const SizedBox(height: 16),
        // Live Location Section (if driver)
        if (widget.isDriver) _buildLiveLocationSection(),
        // Location History Section
        _buildLocationHistorySection(),
      ],
    );
  }

  Widget _buildMapSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.map, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Live Tracking Map',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DeliveryMapWidget(
              assignmentId: widget.assignmentId,
              height: 300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return StreamBuilder<DeliveryStatus?>(
      stream: _trackingService.streamDeliveryStatus(widget.assignmentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final status = snapshot.data;
        if (status == null) {
          return const Center(child: Text('No status available'));
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusIcon(status.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.status.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Updated: ${_formatTime(status.updatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isDriver) _buildStatusUpdateButtons(status),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveLocationSection() {
    return StreamBuilder<DeliveryLiveLocation?>(
      stream: _trackingService.streamLiveLocation(widget.assignmentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final location = snapshot.data;
        if (location == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('No location data yet'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _startSharingLocation,
                    child: const Text('Start Sharing Location'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLocationDetails(location),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationHistorySection() {
    return StreamBuilder<List<DeliveryLocationHistory>>(
      stream: _trackingService.streamLocationHistory(widget.assignmentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }

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
                      'Location History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${history.length} points',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return _buildHistoryItem(item, index);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(
    DeliveryLocationHistory history,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${history.latitude.toStringAsFixed(4)}, ${history.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  _formatTime(history.recordedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (history.speed != null)
            Text(
              '${history.speed!.toStringAsFixed(1)} km/h',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationDetails(DeliveryLiveLocation location) {
    return Column(
      children: [
        _buildLocationRow('Latitude', location.latitude.toString()),
        _buildLocationRow('Longitude', location.longitude.toString()),
        if (location.speed != null)
          _buildLocationRow('Speed', '${location.speed!.toStringAsFixed(1)} km/h'),
        if (location.heading != null)
          _buildLocationRow('Heading', '${location.heading!.toStringAsFixed(0)}°'),
        _buildLocationRow('Updated', _formatTime(location.updatedAt)),
      ],
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DeliveryStatusType status) {
    IconData icon;
    Color color;

    switch (status) {
      case DeliveryStatusType.pending:
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case DeliveryStatusType.accepted:
        icon = Icons.check_circle;
        color = Colors.blue;
        break;
      case DeliveryStatusType.enRoute:
        icon = Icons.directions;
        color = Colors.blue;
        break;
      case DeliveryStatusType.arriving:
        icon = Icons.location_on;
        color = Colors.orange;
        break;
      case DeliveryStatusType.arrived:
        icon = Icons.location_on;
        color = Colors.green;
        break;
      case DeliveryStatusType.completed:
        icon = Icons.done_all;
        color = Colors.green;
        break;
      case DeliveryStatusType.cancelled:
        icon = Icons.cancel;
        color = Colors.red;
        break;
    }

    return Icon(icon, color: color, size: 32);
  }

  Widget _buildStatusUpdateButtons(DeliveryStatus status) {
    return PopupMenuButton<DeliveryStatusType>(
      onSelected: (newStatus) async {
        try {
          await _trackingService.updateDeliveryStatus(
            assignmentId: widget.assignmentId,
            status: newStatus,
          );
          widget.onStatusChanged?.call();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Status updated to ${newStatus.displayName}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: DeliveryStatusType.accepted,
          child: Text('Accept Delivery'),
        ),
        const PopupMenuItem(
          value: DeliveryStatusType.enRoute,
          child: Text('En Route'),
        ),
        const PopupMenuItem(
          value: DeliveryStatusType.arriving,
          child: Text('Arriving'),
        ),
        const PopupMenuItem(
          value: DeliveryStatusType.completed,
          child: Text('Completed'),
        ),
        const PopupMenuItem(
          value: DeliveryStatusType.cancelled,
          child: Text('Cancel'),
        ),
      ],
      child: const Icon(Icons.more_vert),
    );
  }

  Future<void> _startSharingLocation() async {
    // This would integrate with location tracking service
    // For now, just show a snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sharing started')),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}