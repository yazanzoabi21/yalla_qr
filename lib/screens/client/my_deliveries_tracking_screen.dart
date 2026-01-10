import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/order_delivery_assignment.dart';
import '../../widgets/delivery_map_widget.dart';
import '../../widgets/delivery_tracking_widget.dart';

/// Screen showing all active deliveries for a customer to track
class MyDeliveriesTrackingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> activeDeliveries;

  const MyDeliveriesTrackingScreen({
    super.key,
    required this.activeDeliveries,
  });

  @override
  State<MyDeliveriesTrackingScreen> createState() => _MyDeliveriesTrackingScreenState();
}

class _MyDeliveriesTrackingScreenState extends State<MyDeliveriesTrackingScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 [MyDeliveriesTrackingScreen] Building with ${widget.activeDeliveries.length} deliveries');
    
    if (widget.activeDeliveries.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Deliveries'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Deliveries',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your orders will appear here once\nthey are assigned for delivery',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedDelivery = widget.activeDeliveries[_selectedIndex];
    final order = Order.fromJson(selectedDelivery);
    
    // Handle order_delivery_assignments which can be a Map or List
    final assignmentsData = selectedDelivery['order_delivery_assignments'];
    List<dynamic>? assignments;
    if (assignmentsData is List) {
      assignments = assignmentsData;
    } else if (assignmentsData is Map) {
      assignments = [assignmentsData];
    }
    
    final assignment = assignments != null && assignments.isNotEmpty
        ? OrderDeliveryAssignment.fromJson(assignments.first as Map<String, dynamic>)
        : null;

    debugPrint('🔍 [MyDeliveriesTrackingScreen] Order: ${order.id}, Assignment: ${assignment?.id}');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Track My Delivery'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Debug banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Text(
                  'Deliveries: ${widget.activeDeliveries.length}\nOrder: ${order.id.substring(0, 8)}\nAssignment: ${assignment?.id?.substring(0, 8) ?? "none"}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              
              // Order selector (if multiple orders)
              if (widget.activeDeliveries.length > 1) ...[
                const Text(
                  'Select Order:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.activeDeliveries.length,
                    itemBuilder: (context, index) {
                      final delivery = widget.activeDeliveries[index];
                      final deliveryOrder = Order.fromJson(delivery);
                      final isSelected = index == _selectedIndex;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.green : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '#${deliveryOrder.id.substring(0, 7)}',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Order info card
              if (assignment != null) ...[
                _buildOrderInfoCard(order, assignment),
                const SizedBox(height: 16),
                
                // Live Map
                _buildMapCard(assignment),
                const SizedBox(height: 16),
                
                // Tracking Details
                DeliveryTrackingWidget(
                  assignmentId: assignment.id,
                  orderNumber: order.id.substring(0, 8),
                  isDriver: false,
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            size: 60,
                            color: Colors.orange.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Waiting for Delivery Assignment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your order is being prepared.\nA delivery driver will be assigned soon.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(Order order, OrderDeliveryAssignment assignment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Order ID', '#${order.id.substring(0, 8)}'),
            _buildInfoRow('Total', '${order.totalAmount.toStringAsFixed(2)} ${order.currencyCode}'),
            if (assignment.deliveryAccountName != null)
              _buildInfoRow('Driver', assignment.deliveryAccountName!),
            if (assignment.deliveryAccountPhone != null)
              _buildInfoRow('Driver Phone', assignment.deliveryAccountPhone!),
            _buildInfoRow('Assigned', _formatDateTime(assignment.assignedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(OrderDeliveryAssignment assignment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Live Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DeliveryMapWidget(
              assignmentId: assignment.id,
              height: 300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'READY':
        return Colors.purple;
      case 'IN_TRANSIT':
        return Colors.green;
      case 'DELIVERED':
        return Colors.green.shade700;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

