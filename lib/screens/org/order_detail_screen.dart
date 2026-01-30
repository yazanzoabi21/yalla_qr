import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order.dart';
import '../../models/order_delivery_assignment.dart';
import '../../services/order_service.dart';
import '../../services/delivery_location_service.dart';
import '../../services/delivery_tracking_service.dart';
import '../../widgets/delivery_tracking_widget.dart';
import '../../utils/event_bus.dart';

/// Detailed view of a single order with delivery tracking (if assigned)
class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();

  late Map<String, dynamic> _order;
  bool _isLoading = false;
  String? _currentAssignmentId;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
    _extractAssignmentId();
  }

  void _extractAssignmentId() {
    final assignmentsData = _order['order_delivery_assignments'];
    
    // Handle both Map (single object) and List (array) cases
    if (assignmentsData != null) {
      Map<String, dynamic>? assignment;
      
      if (assignmentsData is List && assignmentsData.isNotEmpty) {
        assignment = assignmentsData.first as Map<String, dynamic>;
      } else if (assignmentsData is Map<String, dynamic>) {
        assignment = assignmentsData;
      }
      
      if (assignment != null) {
        _currentAssignmentId = assignment['id'] as String?;
      }
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      final orderId = _order['id'] as String;
      final success = await _orderService.updateOrderStatus(
        orderId,
        newStatus,
      );

      if (success && mounted) {
        setState(() {
          _order['status'] = newStatus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );

        // Notify other widgets
        EventBus.emit('orders:updated');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOrderStatusIcon(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'PREPARING':
        color = Colors.orange;
        icon = Icons.restaurant;
        break;
      case 'READY':
        color = Colors.teal;
        icon = Icons.check_circle;
        break;
      case 'DELIVERED':
        color = Colors.green;
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PREPARING':
        return 'Preparing';
      case 'READY':
        return 'Ready for Pickup';
      case 'DELIVERED':
        return 'Delivered';
      case 'PENDING':
        return 'Pending';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PREPARING':
        return Colors.orange;
      case 'READY':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _order['id'] as String;
    final status = _order['status'] as String;
    final totalAmount = _order['total_amount'] as num;
    final currencyCode = _order['currency_code'] as String?;
    final createdAt = DateTime.parse(_order['created_at'] as String);
    final items = _order['order_items'] as List<dynamic>? ?? [];
    
    // Get product image from first item
    String? productImageUrl;
    if (items.isNotEmpty) {
      final firstItem = items.first as Map<String, dynamic>?;
      if (firstItem != null) {
        final products = firstItem['products'] as Map<String, dynamic>?;
        productImageUrl = products?['image_url'] as String?;
      }
    }
    
    // Handle both Map (single object) and List (array) cases for assignments
    final assignmentsData = _order['order_delivery_assignments'];
    bool hasAssignment = false;
    Map<String, dynamic>? assignmentMap;
    
    if (assignmentsData != null) {
      if (assignmentsData is List && assignmentsData.isNotEmpty) {
        hasAssignment = true;
        assignmentMap = assignmentsData.first as Map<String, dynamic>;
      } else if (assignmentsData is Map<String, dynamic>) {
        hasAssignment = true;
        assignmentMap = assignmentsData;
      }
    }
    
    OrderDeliveryAssignment? assignment;
    if (hasAssignment && assignmentMap != null) {
      try {
        assignment = OrderDeliveryAssignment.fromJson(assignmentMap);
      } catch (e) {
        debugPrint('Error parsing assignment: $e');
        // Assignment exists but has incomplete data
      }
    }

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.iconTheme?.color ?? Theme.of(context).iconTheme.color),
            onPressed: () {
              if (mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            'Order #${orderId.substring(0, 8)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Order.getStatusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order info header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Date',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              createdAt.toString().split('.')[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Items',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${items.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalAmount ${currencyCode ?? ""}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              if (currencyCode == 'LBP') ...[
                                const SizedBox(height: 4),
                                Text(
                                  '\u2248 \$${(totalAmount.toDouble() / 89500).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Product image
                        if (productImageUrl != null)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                productImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey.shade400,
                                    size: 32,
                                  );
                                },
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Delivery assignment section
              if (hasAssignment)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Assignment',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Driver: ${assignment?.deliveryAccountName ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Phone: ${assignment?.deliveryAccountPhone ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Assigned: ${assignment?.assignedAt.toString().split('.')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No delivery assigned yet',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Delivery Status Card
              if (hasAssignment)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildOrderStatusIcon(status),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStatusLabel(status),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Updated: ${createdAt.toString().split('.')[0].split(' ')[1]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Live tracking widget (only if assigned and NOT delivered)
              if (hasAssignment && _currentAssignmentId != null && status != 'DELIVERED')
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: DeliveryTrackingWidget(
                    assignmentId: _currentAssignmentId!,
                    orderNumber: orderId.substring(0, 8),
                    isDriver: false,
                  ),
                ),
              if (hasAssignment && status != 'DELIVERED')
                const SizedBox(height: 16),

              // Info message about automatic tracking (only if not delivered)
              if (hasAssignment && status != 'DELIVERED')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location tracking is automatic. The delivery driver\'s location is updated in real-time on the map.',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Status update buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: status != 'DELIVERED'
                          ? () => _updateOrderStatus('READY')
                          : null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark Ready'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: status != 'DELIVERED'
                          ? () => _updateOrderStatus('DELIVERED')
                          : null,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Items section
              // if (items.isNotEmpty) ...[
              //   Text(
              //     'Order Items (${items.length})',
              //     style: const TextStyle(
              //       fontWeight: FontWeight.bold,
              //       fontSize: 16,
              //     ),
              //   ),
              //   const SizedBox(height: 12),
              //   Container(
              //     decoration: BoxDecoration(
              //       color: Colors.white,
              //       borderRadius: BorderRadius.circular(12),
              //       border: Border.all(color: Colors.grey.shade200),
              //     ),
              //     child: ListView.builder(
              //       shrinkWrap: true,
              //       physics: const NeverScrollableScrollPhysics(),
              //       itemCount: items.length,
              //       itemBuilder: (context, index) {
              //         final item = items[index] as Map<String, dynamic>;
              //         return Column(
              //           children: [
              //             Padding(
              //               padding: const EdgeInsets.all(12),
              //               child: Row(
              //                 crossAxisAlignment: CrossAxisAlignment.start,
              //                 children: [
              //                   Expanded(
              //                     child: Column(
              //                       crossAxisAlignment:
              //                           CrossAxisAlignment.start,
              //                       children: [
              //                         Text(
              //                           item['product_name'] as String? ??
              //                               'Unknown',
              //                           style: const TextStyle(
              //                             fontWeight: FontWeight.w600,
              //                             fontSize: 14,
              //                           ),
              //                         ),
              //                         const SizedBox(height: 4),
              //                         Text(
              //                           'Qty: ${item['quantity']}',
              //                           style: TextStyle(
              //                             fontSize: 12,
              //                             color: Colors.grey.shade600,
              //                           ),
              //                         ),
              //                       ],
              //                     ),
              //                   ),
              //                   Text(
              //                     '${item['unit_price']}',
              //                     style: const TextStyle(
              //                       fontWeight: FontWeight.bold,
              //                       fontSize: 13,
              //                     ),
              //                   ),
              //                 ],
              //               ),
              //             ),
              //             if (index < items.length - 1)
              //               Divider(
              //                 height: 1,
              //                 color: Colors.grey.shade200,
              //               ),
              //           ],
              //         );
              //       },
              //     ),
              //   ),
              // ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // No need to stop tracking - it's managed by the delivery driver
    super.dispose();
  }
}
