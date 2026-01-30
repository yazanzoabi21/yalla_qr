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
    final theme = Theme.of(context);
    debugPrint('🔍 [MyDeliveriesTrackingScreen] Building with ${widget.activeDeliveries.length} deliveries');
    
    if (widget.activeDeliveries.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Deliveries'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
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
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Deliveries',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your orders will appear here once\nthey are assigned for delivery',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
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

    // Get order image
    final orderItems = selectedDelivery['order_items'] as List<dynamic>?;
    String? orderImageUrl;
    
    // Debug the entire delivery structure
    debugPrint('📦 [SelectedDelivery Keys]: ${selectedDelivery.keys.toList()}');
    debugPrint('📦 [OrderItems] Type: ${orderItems.runtimeType}, Length: ${orderItems?.length}');
    
    if (orderItems != null && orderItems.isNotEmpty) {
      final firstItem = orderItems.first as Map<String, dynamic>?;
      if (firstItem != null) {
        debugPrint('📦 [FirstItem Keys]: ${firstItem.keys.toList()}');
        
        // Check if products data is joined
        if (firstItem.containsKey('products')) {
          final products = firstItem['products'];
          debugPrint('📦 [Products] Type: ${products.runtimeType}, Data: $products');
          if (products is Map) {
            orderImageUrl = products['image_url'] as String?;
          }
        }
        
        // If no products field, log the product_id
        if (orderImageUrl == null && firstItem.containsKey('product_id')) {
          debugPrint('⚠️ [Warning] product_id exists (${firstItem['product_id']}) but no products data joined!');
          debugPrint('⚠️ [Warning] The query needs to include .select("*, products(*)") to get product details');
        }
      }
    }

    debugPrint('🔍 [MyDeliveriesTrackingScreen] Order: ${order.id}, Assignment: ${assignment?.id}');
    debugPrint('🖼️ [MyDeliveriesTrackingScreen] Order Image URL: $orderImageUrl');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Track My Delivery'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
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
              // Delivery summary banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Deliveries: ${widget.activeDeliveries.length}\nOrder: ${order.id.substring(0, 8)}\nAssignment: ${assignment?.id?.substring(0, 8) ?? "none"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Order image thumbnail (clickable)
                    GestureDetector(
                      onTap: orderImageUrl != null
                          ? () => _showFullScreenImage(context, orderImageUrl!)
                          : null,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: orderImageUrl == null
                            ? Icon(
                                Icons.image_not_supported_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                size: 24,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    // Product Image
                                    Image.network(
                                      orderImageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
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
                                        debugPrint('🖼️ Image load error: $error');
                                        return Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey.shade400,
                                          size: 24,
                                        );
                                      },
                                    ),
                                    // Overlay to indicate it's tappable
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(6),
                                            bottomRight: Radius.circular(6),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.zoom_in,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
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
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.activeDeliveries.length,
                    itemBuilder: (context, index) {
                      final theme = Theme.of(context);
                      final delivery = widget.activeDeliveries[index];
                      final deliveryOrder = Order.fromJson(delivery);
                      final isSelected = index == _selectedIndex;
                      
                      // Get first order item for image
                      final orderItems = delivery['order_items'] as List<dynamic>?;
                      String? imageUrl;
                      if (orderItems != null && orderItems.isNotEmpty) {
                        final firstItem = orderItems.first as Map<String, dynamic>?;
                        if (firstItem != null) {
                          final product = firstItem['products'] as Map<String, dynamic>?;
                          imageUrl = product?['image_url'] as String?;
                        }
                      }
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withOpacity(0.22),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order ID header
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(11),
                                    topRight: Radius.circular(11),
                                  ),
                                ),
                                child: Text(
                                  '#${deliveryOrder.id.substring(0, 7)}',
                                  style: TextStyle(
                                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              // Order details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: imageUrl == null
                                            ? Icon(
                                                Icons.shopping_bag_outlined,
                                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                                size: 24,
                                              )
                                            : ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  imageUrl,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
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
                                                    debugPrint('🖼️ Order card image error: $error');
                                                    return Icon(
                                                      Icons.broken_image_outlined,
                                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                                      size: 24,
                                                    );
                                                  },
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              deliveryOrder.currencyCode == 'LBP'
                                                  ? '\$${(deliveryOrder.totalAmount / 89500).toStringAsFixed(2)}'
                                                  : '\$${deliveryOrder.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${orderItems?.length ?? 0} item${(orderItems?.length ?? 0) != 1 ? 's' : ''}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(deliveryOrder.status)
                                                    .withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                deliveryOrder.status,
                                                style: TextStyle(
                                                  color: _getStatusColor(deliveryOrder.status),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                
                // // Live Map
                // _buildMapCard(assignment),
                // const SizedBox(height: 16),
                
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

  // Widget _buildMapCard(OrderDeliveryAssignment assignment) {
  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(12),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               const Icon(Icons.map, color: Colors.blue, size: 20),
  //               const SizedBox(width: 8),
  //               const Text(
  //                 'Live Location',
  //                 style: TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               const Spacer(),
  //               Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                 decoration: BoxDecoration(
  //                   color: Colors.green.withOpacity(0.1),
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //                 child: Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Container(
  //                       width: 8,
  //                       height: 8,
  //                       decoration: const BoxDecoration(
  //                         color: Colors.green,
  //                         shape: BoxShape.circle,
  //                       ),
  //                     ),
  //                     const SizedBox(width: 4),
  //                     const Text(
  //                       'LIVE',
  //                       style: TextStyle(
  //                         color: Colors.green,
  //                         fontWeight: FontWeight.bold,
  //                         fontSize: 10,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 12),
  //           DeliveryMapWidget(

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
        return Colors.green.shade600;
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }
}

/// Full-screen zoomable image viewer
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Order Image'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 80,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

