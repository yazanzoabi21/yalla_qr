import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../screens/client/my_deliveries_tracking_screen.dart';

/// Floating button that shows delivery tracking status
/// Appears above the cart icon when user has active deliveries
class FloatingTrackingButton extends StatefulWidget {
  const FloatingTrackingButton({super.key});

  @override
  State<FloatingTrackingButton> createState() => _FloatingTrackingButtonState();
}

class _FloatingTrackingButtonState extends State<FloatingTrackingButton>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  List<Map<String, dynamic>> _activeDeliveries = [];
  List<Map<String, dynamic>> _pendingOrders = [];
  bool _hasDeliveryService = true;
  List<String> _orgsWithoutDelivery = [];
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadActiveDeliveries();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveDeliveries() async {
    try {
      // Load active deliveries with assignments
      final deliveries = await _orderService.getCustomerActiveDeliveryOrders();
      
      // Also load pending orders status
      final pendingStatus = await _orderService.getCustomerPendingOrdersStatus();
      
      if (mounted) {
        setState(() {
          _activeDeliveries = deliveries;
          _pendingOrders = (pendingStatus['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _hasDeliveryService = pendingStatus['hasDeliveryService'] as bool? ?? true;
          _orgsWithoutDelivery = (pendingStatus['orgsWithoutDelivery'] as List?)?.cast<String>() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading active deliveries: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 150, // Above the cart icon
      right: 20,
      child: GestureDetector(
        onTap: () {
          if (_activeDeliveries.isEmpty) {
            // Determine what message to show based on pending orders and delivery service status
            String message;
            IconData icon;
            Color bgColor;

            if (_pendingOrders.isNotEmpty && !_hasDeliveryService) {
              // Org doesn't have delivery service configured
              final orgNames = _orgsWithoutDelivery.isNotEmpty 
                  ? _orgsWithoutDelivery.join(', ')
                  : 'this organization';
              message = 'Delivery service is not available for $orgNames.\nContact the store for pickup options.';
              icon = Icons.warning_amber_rounded;
              bgColor = Colors.orange.shade700;
            } else if (_pendingOrders.isNotEmpty) {
              // Has pending orders waiting for delivery assignment
              message = 'Your order is being prepared.\nDelivery tracking will be available once assigned.';
              icon = Icons.access_time;
              bgColor = Colors.blue.shade600;
            } else {
              // No orders at all
              message = 'No active deliveries to track.\nPlace an order to see delivery tracking!';
              icon = Icons.info_outline;
              bgColor = Colors.grey.shade700;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(message),
                    ),
                  ],
                ),
                backgroundColor: bgColor,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } else {
            // Navigate to deliveries tracking screen
            debugPrint('🚀 Navigating to MyDeliveriesTrackingScreen with ${_activeDeliveries.length} deliveries');
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (ctx) {
                  debugPrint('🏗️ Building MyDeliveriesTrackingScreen route');
                  return MyDeliveriesTrackingScreen(
                    activeDeliveries: _activeDeliveries,
                  );
                },
              ),
            ).then((value) {
              debugPrint('🔙 Returned from MyDeliveriesTrackingScreen');
            });
          }
        },
        child: _isLoading
            ? _buildLoadingButton()
            : _activeDeliveries.isEmpty
                ? _buildNoDeliveriesButton()
                : _buildActiveDeliveriesButton(),
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNoDeliveriesButton() {
    // Different visual states based on pending orders
    if (_pendingOrders.isNotEmpty && !_hasDeliveryService) {
      // Orange button - delivery not available
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Stack(
          children: [
            Center(
              child: Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            // Warning icon overlay
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.warning_amber,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      );
    } else if (_pendingOrders.isNotEmpty) {
      // Blue button - waiting for delivery assignment
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            // Clock icon to indicate waiting
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.access_time,
                  color: Colors.blue.shade600,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Grey button - no orders at all
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade400,
            Colors.grey.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Stack(
        children: [
          Center(
            child: Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          // Slash through icon to indicate no tracking
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            bottom: 15,
            child: Icon(
              Icons.not_interested,
              color: Colors.white54,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveriesButton() {
    final count = _activeDeliveries.length;
    
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade400,
              Colors.green.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.local_shipping,
                color: Colors.white,
                size: 28,
              ),
            ),
            // Badge showing count
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
