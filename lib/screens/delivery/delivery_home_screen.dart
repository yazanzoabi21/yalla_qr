import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/order.dart';
import '../../models/order_delivery_assignment.dart';
import '../../utils/event_bus.dart';
import '../../services/order_service.dart';
import '../../services/delivery_location_service.dart';
import '../../services/delivery_tracking_service.dart';
import '../../widgets/navbar.dart';
import '../../services/currency_service.dart';
import 'package:postgrest/postgrest.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DeliveryLocationService _locationService = DeliveryLocationService();
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  String? _userName;
  String? _deliveryAccountId;
  bool _isLoading = true;
  List<Order> _assignedOrders = [];
  // Map of orderId -> assignment
  Map<String, OrderDeliveryAssignment?> _assignments = {};
  // Map of organization account id -> name
  Map<String, String> _orgNamesById = {};
  double? _usdRate;
  late TabController _tabController;
  String _searchQuery = '';
  DateTime? _lastBackPress; // Track last back button press for double-tap exit

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Rebuild when tab index changes so we can style the active tab differently
    _tabController.addListener(() {});

    // Listen for global updates (notes/orders) so UI updates when ORG marks notes as read
    EventBus.stream.listen((event) {
      if (event == 'orders:updated') {
        if (mounted) _loadData();
      }

      if (event.startsWith('note:updated:') ||
          event.startsWith('note:deleted:')) {
        // Refresh assignments and orders so red borders and badges reflect current DB state
        if (mounted) _loadData();
      }
    });

    // Request location permissions proactively when delivery driver logs in
    _requestLocationPermissions();
    _loadData();
  }

  /// Request location permissions upfront when delivery driver logs in
  Future<void> _requestLocationPermissions() async {
    try {
      debugPrint('📍 Requesting location permissions for delivery driver...');

      // Check if location services are enabled
      final isLocationEnabled = await _locationService
          .isLocationServiceEnabled();
      if (!isLocationEnabled) {
        debugPrint('⚠️ Location services are disabled');
        return;
      }

      // Request location permission
      final permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied by user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission is required to share your delivery location',
              ),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () async {
                  await Geolocator.requestPermission();
                },
              ),
            ),
          );
        }
      } else if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied forever - opening settings');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission required. Please enable it in settings.',
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
              ),
            ),
          );
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        debugPrint('✅ Location permission granted');
      }
    } catch (e) {
      debugPrint('❌ Error requesting location permissions: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Stop location tracking when leaving the screen
    _locationService.stopLocationTracking();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load USD exchange rate
      _usdRate = await CurrencyService.getUsdRate();

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final accountResponse = await Supabase.instance.client
            .from('accounts')
            .select('id, name')
            .eq('owner_id', user.id)
            .eq('role', 'DELIVERY')
            .maybeSingle();

        if (accountResponse != null) {
          _deliveryAccountId = accountResponse['id'] as String;
          _userName = accountResponse['name'] as String?;

          // Load assigned orders (include completed so completed tab shows delivered orders)
          final orders = await _orderService.getDeliveryOrders(
            _deliveryAccountId!,
            includeCompleted: true,
          );

          // Load assignments for those orders so we can show/edit notes
          final orderIds = orders.map((o) => o.id).toList();
          try {
            _assignments = await _orderService.getAssignmentsForOrders(
              orderIds,
            );
          } catch (e) {
            debugPrint('Error loading assignments: $e');
            _assignments = {};
          }

          // Load organization names for these orders so delivery can see who ordered
          final orgIds = orders.map((o) => o.accountId).toSet().toList();
          if (orgIds.isNotEmpty) {
            try {
              final resp = await Supabase.instance.client
                  .from('accounts')
                  .select('id, name')
                  .in_('id', orgIds);
              if (resp != null) {
                for (var a in (resp as List)) {
                  final id = a['id'] as String;
                  final name = a['name'] as String? ?? id;
                  _orgNamesById[id] = name;
                }
              }
            } catch (e) {
              debugPrint('Error loading org names: $e');
            }
          }

          if (mounted) {
            setState(() {
              _assignedOrders = orders;
            });

            // Automatically start location tracking for first active (non-delivered) order
            _autoStartLocationTracking();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Automatically start location tracking for active deliveries
  Future<void> _autoStartLocationTracking() async {
    // Get first pending order (non-delivered, non-cancelled)
    final activeOrders = _assignedOrders
        .where((o) => o.status != 'DELIVERED' && o.status != 'CANCELLED')
        .toList();

    if (activeOrders.isEmpty) {
      debugPrint('📍 No active deliveries - stopping location tracking');
      await _locationService.stopLocationTracking();
      return;
    }

    // Get assignment for the first active order
    final firstOrder = activeOrders.first;
    final assignment = _assignments[firstOrder.id];

    if (assignment == null) {
      debugPrint('⚠️ No assignment found for order: ${firstOrder.id}');
      return;
    }

    try {
      // Initialize tracking in database
      await _trackingService.initializeDeliveryTracking(assignment.id);

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission not granted');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required for delivery tracking',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Start location tracking
      await _locationService.startLocationTracking(
        assignmentId: assignment.id,
        onLocationUpdate: (position) {
          debugPrint(
            '📍 Location updated for delivery: ${position.latitude}, ${position.longitude}',
          );
        },
      );

      debugPrint(
        '✅ Auto-started location tracking for order: ${firstOrder.id}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location tracking started for Order #${firstOrder.id.substring(0, 8)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error auto-starting location tracking: $e');
    }
  }

  List<Order> get _pendingOrders => _assignedOrders
      .where((o) => o.status != 'DELIVERED' && o.status != 'CANCELLED')
      .toList();

  List<Order> get _completedOrders =>
      _assignedOrders.where((o) => o.status == 'DELIVERED').toList();

  List<Order> get _filteredPendingOrders {
    if (_searchQuery.isEmpty) return _pendingOrders;
    return _pendingOrders.where((order) => _matchesSearch(order)).toList();
  }

  List<Order> get _filteredCompletedOrders {
    if (_searchQuery.isEmpty) return _completedOrders;
    return _completedOrders.where((order) => _matchesSearch(order)).toList();
  }

  bool _matchesSearch(Order order) {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return true;

    // Remove # symbol if present in query
    final cleanQuery = query.startsWith('#') ? query.substring(1) : query;

    // Search in order ID (both full ID and shortened version)
    if (order.id.toLowerCase().contains(cleanQuery)) return true;

    // Search in customer contact info
    if (order.contactName?.toLowerCase().contains(cleanQuery) ?? false)
      return true;
    if (order.deliveryPhone?.toLowerCase().contains(cleanQuery) ?? false)
      return true;
    if (order.deliveryAddress?.toLowerCase().contains(cleanQuery) ?? false)
      return true;

    // Search in organization name
    final orgName = _orgNamesById[order.accountId];
    if (orgName?.toLowerCase().contains(cleanQuery) ?? false) return true;

    // Search in status
    if (order.status.toLowerCase().contains(cleanQuery)) return true;

    // Search in total amount
    if (order.formattedTotalAmount.toLowerCase().contains(cleanQuery))
      return true;

    return false;
  }

  String _formatNumber(double number) {
    final formatted = number.toStringAsFixed(0);
    final parts = <String>[];
    for (int i = formatted.length - 1; i >= 0; i -= 3) {
      final start = i - 2 >= 0 ? i - 2 : 0;
      parts.insert(0, formatted.substring(start, i + 1));
    }
    return parts.join(',');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PREPARING':
        return Colors.purple;
      case 'READY':
        return Colors.teal;
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
    return PopScope(
      canPop: false, // Prevent default back navigation
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final now = DateTime.now();
          if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
            // First press or timeout - show snackbar
            _lastBackPress = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Press back again to exit'),
                backgroundColor: Colors.grey.shade700,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          } else {
            // Second press within 2 seconds - exit app (minimize to background)
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF0F3),
        appBar: Navbar(
        showMenuButton: true,
        searchHint: 'Search orders, customers, addresses...',
        onSearchChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Welcome Header
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${_userName ?? 'Driver'}!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_pendingOrders.length} pending ${_pendingOrders.length == 1 ? 'delivery' : 'deliveries'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // IconButton(
                        //   onPressed: _loadData,
                        //   icon: const Icon(Icons.refresh, color: Colors.white),
                        // ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: _tabController.index == 0
                            ? Colors.yellow[700]
                            : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.pending_actions, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Pending'),
                                ],
                              ),
                              if (_pendingOrders.isNotEmpty)
                                Positioned(
                                  top: -2,
                                  right: -10,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade700,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_pendingOrders.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Completed'),
                                ],
                              ),
                              if (_completedOrders.isNotEmpty)
                                Positioned(
                                  top: -4,
                                  right: -10,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_completedOrders.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Pending Orders
                        _filteredPendingOrders.isEmpty
                            ? _buildEmptyState(
                                _searchQuery.isNotEmpty
                                    ? 'No deliveries match your search'
                                    : 'No pending deliveries',
                                _searchQuery.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.local_shipping_outlined,
                              )
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: _filteredPendingOrders.length,
                                  itemBuilder: (context, index) =>
                                      _buildOrderCard(
                                        _filteredPendingOrders[index],
                                        isPending: true,
                                      ),
                                ),
                              ),

                        // Completed Orders
                        _filteredCompletedOrders.isEmpty
                            ? _buildEmptyState(
                                _searchQuery.isNotEmpty
                                    ? 'No deliveries match your search'
                                    : 'No completed deliveries',
                                _searchQuery.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.history,
                              )
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: _filteredCompletedOrders.length,
                                  itemBuilder: (context, index) =>
                                      _buildOrderCard(
                                        _filteredCompletedOrders[index],
                                        isPending: false,
                                      ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    )
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, {required bool isPending}) {
    final assignment = _assignments[order.id];
    // Show red border only when the delivery note is unread (ORG hasn't seen it yet)
    final hasUnreadNote = assignment?.deliveryNotesUnread == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: hasUnreadNote
            ? Border.all(color: Colors.red.shade300, width: 2)
            : null,
        boxShadow: hasUnreadNote
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      Order.getStatusLabel(order.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '#${order.id.substring(0, 8)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _orgNamesById[order.accountId] ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order info - Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateTime(order.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Item count and price in cards
                  Row(
                    children: [
                      // Item count card with image
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            'Items',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${order.items?.length ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 3),
                              // Product image
                              GestureDetector(
                                onTap: () => _showOrderImage(order.items ?? []),
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: _buildOrderImageSmall(order.items ?? []),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Price card
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepOrange.shade400,
                                Colors.deepOrange.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                order.formattedTotalAmount,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              if (order.currencyCode == 'LBP')
                                Builder(
                                  builder: (_) {
                                    double? usd;
                                    // Prefer stored USD value if available (consistent with admin)
                                    if (order.totalAmountUsd != null) {
                                      usd = order.totalAmountUsd;
                                    } else if (_usdRate != null) {
                                      usd = order.totalAmount / _usdRate!;
                                    }
                                    if (usd == null)
                                      return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '\u2248 \$${usd.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Customer delivery info
                  if (order.contactName != null ||
                      order.deliveryAddress != null ||
                      order.deliveryPhone != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Customer Delivery Info',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          if (order.contactName != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.account_circle,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.contactName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (order.deliveryPhone != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    order.deliveryPhone!,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (order.deliveryAddress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.deliveryAddress!,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Delivery Note display (if any)
                  Builder(
                    builder: (_) {
                      final assignment = _assignments[order.id];
                      final deliveryNotes = assignment?.deliveryNotes;
                      if (deliveryNotes != null && deliveryNotes.isNotEmpty) {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.sticky_note_2,
                                    size: 20,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery Note',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          deliveryNotes,
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _showAddNoteDialog(order),
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.orange.shade700,
                                        ),
                                        tooltip: 'Edit note',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  if (isPending) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddNoteDialog(order),
                            icon: Icon(
                              _assignments[order.id]?.deliveryNotes == null
                                  ? Icons.note_add
                                  : Icons.edit,
                              size: 18,
                              color: Colors.orange,
                            ),
                            label: Text(
                              _assignments[order.id]?.deliveryNotes == null
                                  ? 'Add Note'
                                  : 'Edit Note',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: BorderSide(color: Colors.orange.shade200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _markAsDelivered(order),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark as Delivered'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours != 1 ? 's' : ''} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays != 1 ? 's' : ''} ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Show full order image in dialog
  void _showOrderImage(List<OrderItem> items) {
    String? imageUrl;
    String? productName;

    if (items.isNotEmpty) {
      final firstItem = items.first;
      imageUrl = firstItem.product?['image_url'] as String?;
      productName = firstItem.product?['name'] as String?;
    }

    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Main content
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.95,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepOrange.shade400,
                          Colors.deepOrange.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Product Image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                productName ?? 'View Image',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Image with padding
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.deepOrange.shade400,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading image...',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Please try again later',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Footer hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.zoom_in,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pinch to zoom • Tap outside to close',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Close button (floating)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade800,
                      size: 20,
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

  /// Build small order image thumbnail from first item
  Widget _buildOrderImageSmall(List<OrderItem> items) {
    String? imageUrl;

    // Get first item's product image
    if (items.isNotEmpty) {
      final firstItem = items.first;
      imageUrl = firstItem.product?['image_url'] as String?;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: imageUrl == null
          ? Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 24)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
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
                    size: 24,
                  );
                },
              ),
            ),
    );
  }

  Future<void> _showAddNoteDialog(Order order) async {
    final TextEditingController noteController = TextEditingController(
      text: _assignments[order.id]?.deliveryNotes ?? '',
    );

    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.note_add, color: Colors.orange),
            const SizedBox(width: 12),
            Text(
              _assignments[order.id]?.deliveryNotes == null
                  ? 'Add Delivery Note'
                  : 'Edit Delivery Note',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${order.id.substring(0, 8)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'E.g., Cannot deliver, customer not available, address issue...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final bool hasExistingNote = noteController.text
                  .trim()
                  .isNotEmpty;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),

                  Row(
                    children: [
                      if (hasExistingNote)
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('Delete Note'),
                                  ],
                                ),
                                content: const Text(
                                  'Are you sure you want to remove this note?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true)
                              Navigator.pop(context, '__DELETE__');
                          },
                          child: Text(
                            'Delete Note',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, noteController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Save Note'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (note != null && mounted) {
      try {
        // Get assignment ID from order
        final assignmentResponse = await Supabase.instance.client
            .from('order_delivery_assignments')
            .select('id')
            .eq('order_id', order.id)
            .maybeSingle();

        if (assignmentResponse != null) {
          final assignmentId = assignmentResponse['id'] as String;

          if (note == '__DELETE__') {
            // Delete (clear) the note and metadata; explicitly clear unread flag
            try {
              await Supabase.instance.client
                  .from('order_delivery_assignments')
                  .update({
                    'delivery_notes': null,
                    'delivery_notes_by': null,
                    'delivery_notes_updated_at': null,
                    'delivery_notes_unread': false,
                  })
                  .eq('id', assignmentId);
            } on PostgrestException catch (_) {
              // Retry without unread column for older schemas
              await Supabase.instance.client
                  .from('order_delivery_assignments')
                  .update({
                    'delivery_notes': null,
                    'delivery_notes_by': null,
                    'delivery_notes_updated_at': null,
                  })
                  .eq('id', assignmentId);
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note deleted'),
                  backgroundColor: Colors.green,
                ),
              );

              await _loadData();
              EventBus.emit('orders:updated');

              // Notify ORG locally that the note was deleted so UI clears immediately
              EventBus.emit('note:deleted:$assignmentId:${order.id}');
            }
          } else if (note.isNotEmpty) {
            // Update the delivery notes and metadata
            try {
              await Supabase.instance.client
                  .from('order_delivery_assignments')
                  .update({
                    'delivery_notes': note,
                    'delivery_notes_by': _deliveryAccountId,
                    'delivery_notes_updated_at': DateTime.now()
                        .toUtc()
                        .toIso8601String(),
                    'delivery_notes_unread': true,
                  })
                  .eq('id', assignmentId);
            } on PostgrestException catch (e) {
              // If the unread column is missing, retry without it
              debugPrint(
                'Missing delivery_notes_unread column, retrying without it: $e',
              );
              try {
                await Supabase.instance.client
                    .from('order_delivery_assignments')
                    .update({
                      'delivery_notes': note,
                      'delivery_notes_by': _deliveryAccountId,
                      'delivery_notes_updated_at': DateTime.now()
                          .toUtc()
                          .toIso8601String(),
                    })
                    .eq('id', assignmentId);

                // Let user know migration is recommended (soft warning)
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Note saved (schema missing unread flag). Run migration to enable unread badges.',
                      ),
                      backgroundColor: Colors.orange.shade700,
                    ),
                  );

                  // Notify ORG locally that the note was created/updated (DB lacks unread flag)
                  EventBus.emit('note:updated:$assignmentId:${order.id}');
                }
              } catch (e2) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save note: $e2'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note saved successfully'),
                  backgroundColor: Colors.green,
                ),
              );

              // Refresh assignments and orders list
              await _loadData();

              // Notify ORG and navbar
              EventBus.emit('orders:updated');
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save note: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsDelivered(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Confirm Delivery'),
          ],
        ),
        content: Text('Mark order #${order.id.substring(0, 8)} as delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _orderService.completeDelivery(order.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as delivered!'),
            backgroundColor: Colors.green,
          ),
        );
        // Ensure we fetch the latest order and show it in the completed tab immediately
        final updatedOrder = await _orderService.getOrderById(order.id);
        if (updatedOrder != null && mounted) {
          final idx = _assignedOrders.indexWhere((o) => o.id == order.id);
          if (idx >= 0) {
            _assignedOrders[idx] = updatedOrder;
          } else {
            _assignedOrders.add(updatedOrder);
          }
          setState(() {});

          // Notify other widgets (navbar/org) to refresh counts immediately
          EventBus.emit('orders:updated');

          // Refresh data (gets both pending and completed) and switch to Completed tab
          await _loadData();
          if (mounted) {
            _tabController.animateTo(1);
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

