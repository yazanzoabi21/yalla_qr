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
import '../../services/notification_service.dart';
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
  // City / Zone lookup maps used to resolve delivery locations
  final Map<String, String> _zoneNamesById = {};
  final Map<String, String> _cityNamesById = {};
  final Map<String, String> _cityZoneMap = {};
  // customer owner_id -> { 'zone_id': ..., 'city_id': ... }
  final Map<String, Map<String, String?>> _customerLocationById = {};
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

    // Preload zones/cities used in the UI
    _loadZonesAndCities();

    // Request location permissions proactively when delivery driver logs in
    _requestLocationPermissions();
    _loadData();
  }

  Future<void> _acceptAssignment(Order order) async {
    final orderId = order.id;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Accept Delivery'),
            ],
          ),
          content: Text('Do you want to accept delivery for order #${orderId.substring(0,8)}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await _orderService.acceptDeliveryAssignment(orderId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order accepted', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );

          // Refresh local data and start tracking if needed
          await _loadData();
          _autoStartLocationTracking();
          EventBus.emit('orders:updated');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to accept order'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error accepting assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept order: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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

      final theme = Theme.of(context);

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied by user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission is required to share your delivery location',
              ),
              backgroundColor: theme.colorScheme.secondary,
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
              backgroundColor: theme.colorScheme.error,
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

  /// Load zone and city name maps used by delivery UI
  Future<void> _loadZonesAndCities() async {
    try {
      final cResp = await Supabase.instance.client
          .from('cities')
          .select('id, name_en, zone_id');
      if (cResp != null) {
        final list = List<Map<String, dynamic>>.from(cResp as List);
        for (var c in list) {
          final id = c['id'] as String?;
          final name = c['name_en'] as String?;
          final zoneId = c['zone_id'] as String?;
          if (id != null && name != null) _cityNamesById[id] = name;
          if (id != null && zoneId != null) _cityZoneMap[id] = zoneId;
        }
      }

      final zResp = await Supabase.instance.client
          .from('zones')
          .select('id, name_en');
      if (zResp != null) {
        final zlist = List<Map<String, dynamic>>.from(zResp as List);
        for (var z in zlist) {
          final id = z['id'] as String?;
          final name = z['name_en'] as String?;
          if (id != null && name != null) _zoneNamesById[id] = name;
        }
      }
    } catch (e) {
      debugPrint('Error loading zones/cities: $e');
    }
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

          // Fetch customer locations (used as a fallback to resolve city/zone names)
          final customerIds = orders
              .map((o) => o.customerId)
              .whereType<String>()
              .toSet()
              .toList();
          if (customerIds.isNotEmpty) {
            try {
              final accLocs = await Supabase.instance.client
                  .from('accounts')
                  .select('owner_id, zone_id, city_id')
                  .in_('owner_id', customerIds);

              if (accLocs != null) {
                for (var acc in (accLocs as List)) {
                  final owner = acc['owner_id'] as String?;
                  if (owner != null) {
                    _customerLocationById[owner] = {
                      'zone_id': acc['zone_id'] as String?,
                      'city_id': acc['city_id'] as String?,
                    };
                  }
                }
              }
            } catch (e) {
              debugPrint('Error loading customer locations: $e');
            }
          }

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
    final theme = Theme.of(context);
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
            SnackBar(
              content: Text(
                'Location permission is required for delivery tracking',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
              backgroundColor: theme.colorScheme.secondary,
              duration: const Duration(seconds: 3),
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
        final snackBg = theme.brightness == Brightness.dark
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.primary;
        final snackText = theme.brightness == Brightness.dark
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onPrimary;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Icon(Icons.location_on, color: snackText, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location tracking started for Order #${firstOrder.id.substring(0, 8)}',
                    style: TextStyle(fontSize: 13, color: snackText),
                  ),
                ),
              ],
            ),
            backgroundColor: snackBg,
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
        return Colors.yellow[700]!;
      case 'PENDING_DELIVERY_CONFIRMATION':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PREPARING':
        return Colors.purple;
      case 'READY':
        return Colors.teal;
      case 'DELIVERED':
        return Colors.green.shade600;
      case 'ACCEPTED_BY_DELIVERY':
        return Colors.green.shade600;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Status colors (force explicit colors regardless of theme)
    final pendingColor = Colors.yellow[700]!;
    final completedColor = Colors.green.shade600;

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
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
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
        backgroundColor: theme.scaffoldBackgroundColor,
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
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedBuilder(
                      animation: _tabController.animation ?? _tabController,
                      builder: (context, _) {
                        return TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: _tabController.index == 0 ? pendingColor : completedColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
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
                                          color: pendingColor,
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
                                          color: completedColor,
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
                        );
                      },
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
    final theme = Theme.of(context);
    final circleColor = theme.colorScheme.surfaceVariant;
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isDarkMode 
        ? Colors.yellow[700]! 
        : theme.colorScheme.onSurface.withOpacity(0.4);
    final textColor = isDarkMode 
        ? Colors.yellow[700]! 
        : (theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, {required bool isPending}) {
    final assignment = _assignments[order.id];
    // Show red border only when the delivery note is unread (ORG hasn't seen it yet)
    final hasUnreadNote = assignment?.deliveryNotesUnread == true;
    final theme = Theme.of(context);
    final pendingColorLocal = Colors.yellow[700]!;
    final completedColorLocal = Colors.green.shade600;

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
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
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
                                            color: theme.iconTheme.color?.withOpacity(0.75),
                                          ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                                'Items',
                                                style: TextStyle(
                                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
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
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
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
                              // Show subtotal, delivery fee (if available) and grand total
                              Builder(builder: (_) {
                                final subtotal = order.totalAmount;
                                final currency = order.currencyCode;
                                final deliveryLbp = order.deliveryFeeLbp ?? 0.0;
                                final deliveryUsd = order.deliveryFeeUsd ?? 0.0;
                                final currentDeliveryFee = currency == 'LBP' ? deliveryLbp : deliveryUsd;
                                final hasAnyDeliveryFee = (deliveryLbp > 0) || (deliveryUsd > 0);
                                final grandTotalValue = subtotal + currentDeliveryFee;

                                String formatPrice(double amt, String? curr) {
                                  if (curr == 'LBP') return '${_formatNumber(amt)} LBP';
                                  return '\$${amt.toStringAsFixed(2)}';
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subtotal: ${formatPrice(subtotal, currency)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (!hasAnyDeliveryFee && (order.deliveryCityId == null && order.cityId == null))
                                      Text(
                                        'Delivery city unknown — fee not applied',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                                      )
                                    else if (!hasAnyDeliveryFee && (order.deliveryCityId != null || order.cityId != null))
                                      Text(
                                        'Delivery not configured',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.yellow.shade200, fontSize: 12),
                                      )
                                    else
                                      Text(
                                        'Delivery Fee: ${formatPrice(currentDeliveryFee, currency)}',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      // Grand total = order total (stored subtotal) + delivery fee
                                      currency == 'LBP'
                                          ? '${_formatNumber(grandTotalValue)} LBP'
                                          : '\$${grandTotalValue.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (currency == 'LBP')
                                      Builder(builder: (_) {
                                        double? usdSub = order.totalAmountUsd ?? (_usdRate != null ? (order.totalAmount / _usdRate!) : null);
                                        double? usdDel = deliveryUsd > 0 ? deliveryUsd : (_usdRate != null ? (deliveryLbp / _usdRate!) : null);
                                        final grandUsd = (usdSub ?? 0) + (usdDel ?? 0);
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            if (_usdRate != null)
                                              Text(
                                                '\u2248 \$${grandUsd.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                                              )
                                            else
                                              Text(
                                                '\u2248 \$${(order.totalAmount / 89500).toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                                              ),
                                            if (usdSub != null && usdDel != null)
                                              Text(
                                                '(Sub \$${usdSub.toStringAsFixed(2)} + Del \$${usdDel.toStringAsFixed(2)})',
                                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
                                              ),
                                          ],
                                        );
                                      }),
                                  ],
                                );
                              }),
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
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                                  Icon(
                                    Icons.person,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                              const SizedBox(width: 8),
                              Text(
                                'Customer Order Information',
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

                            // Zone / City / Address (combined on one line)
                              Builder(
                                builder: (_) {
                                  String? zoneName;
                                  String? cityName;

                                  // Prefer explicit `deliveryCityId` from the typed `Order` model
                                  if (order.deliveryCityId != null) {
                                    final cityId = order.deliveryCityId;
                                    if (cityId != null) {
                                      // Look up city name and its zone
                                      cityName = _cityNamesById[cityId];
                                      if (cityName != null) {
                                        final zoneId = _cityZoneMap[cityId];
                                        if (zoneId != null) {
                                          zoneName = _zoneNamesById[zoneId];
                                        }
                                      }
                                    }
                                  }

                                  // Fallback to customer's saved `cityId` on the Order model
                                  if (cityName == null && order.cityId != null) {
                                    final c = order.cityId;
                                    cityName = c != null ? (_cityNamesById[c] ?? c) : null;
                                    final zId = c != null ? _cityZoneMap[c] : null;
                                    if (zId != null) zoneName = _zoneNamesById[zId];
                                  }

                                  // Fallback to account-stored customer location if still unresolved
                                  if (zoneName == null && cityName == null) {
                                    final custLoc = _customerLocationById[order.customerId];
                                    if (custLoc != null) {
                                      final zId = custLoc['zone_id'] as String?;
                                      final cId = custLoc['city_id'] as String?;
                                      if (zId != null) zoneName = _zoneNamesById[zId];
                                      if (cId != null) cityName = _cityNamesById[cId];
                                    }
                                  }

                                  // Note: `Order` model does not expose `zone_name`/`city_name` fields;
                                  // leave `zoneName`/`cityName` null if not resolved above.

                                  final parts = <String>[];
                                  if (zoneName != null && zoneName.isNotEmpty) {
                                    parts.add(zoneName);
                                  }
                                  if (cityName != null && cityName.isNotEmpty) {
                                    parts.add(cityName);
                                  }
                                  if (order.deliveryAddress != null &&
                                      order.deliveryAddress!.isNotEmpty) {
                                    parts.add(order.deliveryAddress!);
                                  }

                                  if (parts.isEmpty)
                                    return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).disabledColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            parts.join(', '),
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                          // if (order.deliveryAddress != null)
                          //   Padding(
                          //     padding: const EdgeInsets.only(top: 8),
                          //     child: Row(
                          //       crossAxisAlignment: CrossAxisAlignment.start,
                          //       children: [
                          //         Icon(
                          //           Icons.location_on,
                          //           size: 16,
                          //           color: Colors.grey.shade600,
                          //         ),
                          //         const SizedBox(width: 8),
                          //         Expanded(
                          //           child: Text(
                          //             order.deliveryAddress!,
                          //             style: TextStyle(
                          //               color: Colors.grey.shade700,
                          //               fontSize: 14,
                          //             ),
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
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
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.dividerColor,
                                  ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Icon(
                                      Icons.sticky_note_2,
                                      size: 20,
                                      color: theme.colorScheme.secondary,
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
                                            color: theme.colorScheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          deliveryNotes,
                                          style: TextStyle(
                                            color: theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : theme.textTheme.bodyMedium?.color ?? Colors.black,
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
                                          color: theme.colorScheme.secondary,
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
                    // Evaluate assignment in a Builder to allow local variable declaration
                    Builder(
                      builder: (_) {
                        final assign = _assignments[order.id];
                        if (assign != null && assign.userId == null) {
                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _acceptAssignment(order),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Accept Delivery'),
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
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddNoteDialog(order),
                                icon: Icon(
                                  _assignments[order.id]?.deliveryNotes == null
                                      ? Icons.note_add
                                      : Icons.edit,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                label: Text(
                                  _assignments[order.id]?.deliveryNotes == null
                                      ? 'Add Note'
                                      : 'Edit Note',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.secondary,
                                  side: BorderSide(color: Theme.of(context).colorScheme.secondary.withOpacity(0.28)),
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
                                  backgroundColor: completedColorLocal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No image available', style: TextStyle(color: theme.colorScheme.onSecondary)),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );
      return;
    }

    final theme = Theme.of(context);

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
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                                          theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading image...',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color,
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
                                            color: theme.colorScheme.error.withOpacity(0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(
                                            color: theme.textTheme.bodyMedium?.color,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Please try again later',
                                          style: TextStyle(
                                            color: theme.textTheme.bodySmall?.color,
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
                      color: theme.colorScheme.surfaceVariant,
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
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pinch to zoom • Tap outside to close',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
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
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
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
                                title: Row(
                                  children: [
                                    Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                    const SizedBox(width: 12),
                                    const Text('Delete Note'),
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
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                      foregroundColor: Colors.black,
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
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, noteController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
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
      final theme = Theme.of(context);
      try {
        final assignmentResponse = await Supabase.instance.client
            .from('order_delivery_assignments')
            .select('id')
            .eq('order_id', order.id)
            .maybeSingle();

        if (assignmentResponse == null) {
          if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to locate assignment', style: TextStyle(color: theme.colorScheme.onError)),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
          return;
        }

        final assignmentId = assignmentResponse['id'] as String;

        if (note == '__DELETE__') {
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
          } catch (_) {
            // older schema fallback
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
              SnackBar(
                content: Text('Note deleted', style: TextStyle(color: theme.colorScheme.onSecondary)),
                backgroundColor: theme.colorScheme.secondary,
              ),
            );
            await _loadData();
            EventBus.emit('orders:updated');
            EventBus.emit('note:deleted:$assignmentId:${order.id}');
          }
        } else if (note.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('order_delivery_assignments')
                .update({
                  'delivery_notes': note,
                  'delivery_notes_by': _deliveryAccountId,
                  'delivery_notes_updated_at': DateTime.now().toUtc().toIso8601String(),
                  'delivery_notes_unread': true,
                })
                .eq('id', assignmentId);
          } catch (e) {
            // Fallback if unread column missing
            try {
              await Supabase.instance.client
                  .from('order_delivery_assignments')
                  .update({
                    'delivery_notes': note,
                    'delivery_notes_by': _deliveryAccountId,
                    'delivery_notes_updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', assignmentId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note saved (schema missing unread flag).', style: TextStyle(color: theme.colorScheme.onSecondary)),
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                );
                EventBus.emit('note:updated:$assignmentId:${order.id}');
              }
            } catch (e2) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save note: $e2'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
              return;
            }
          }

          if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note saved', style: TextStyle(color: theme.colorScheme.onSecondary)),
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                );
            await _loadData();
            EventBus.emit('orders:updated');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save note: $e', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error,
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
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Confirm Delivery'),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
          SnackBar(
            content: const Text('Order marked as delivered!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
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
          // Notify the customer (user) that their order was delivered
          try {
            final notifier = NotificationService();
            await notifier.sendToUser(
              userId: order.customerId,
              title: 'Order Delivered: #${order.id.substring(0,8)}',
              message: 'Your order #${order.id.substring(0,8)} has been delivered.',
              data: {
                'type': 'order_delivered',
                'order_id': order.id,
              },
            );
            debugPrint('✅ [DeliveryHome] Notified customer ${order.customerId} about delivery');
          } catch (e) {
            debugPrint('⚠️ [DeliveryHome] Failed to notify customer: $e');
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update order'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

