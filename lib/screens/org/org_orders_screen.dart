import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../utils/event_bus.dart';
import '../../services/currency_service.dart';
import 'order_detail_screen.dart';

/// Screen for ORG to manage orders and assign delivery
class OrgOrdersScreen extends StatefulWidget {
  const OrgOrdersScreen({super.key});

  @override
  State<OrgOrdersScreen> createState() => _OrgOrdersScreenState();
}

class _OrgOrdersScreenState extends State<OrgOrdersScreen> {
  final OrderService _orderService = OrderService();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _deliveryAccounts = [];
  bool _isLoading = true;
  String? _orgAccountId;
  double? _orgLocationLat;
  double? _orgLocationLng;
  double? _usdRate;
  String _selectedFilter = 'ALL';
  // Zones / Cities for assignment
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _cities = [];
  // Maps for quick name lookup
  final Map<String, String> _zoneNamesById = {};
  final Map<String, String> _cityNamesById = {};
  // Map city IDs to their zone IDs for zone lookups
  final Map<String, String> _cityZoneMap = {};
  // Map to store customer location preferences (city/zone) from accounts table
  final Map<String, Map<String, String?>> _customerLocationById = {};
  // Delivery pricing map: cityId -> pricingMap {price_lbp, price_usd, etc.}
  Map<String, Map<String, dynamic>> _deliveryPricingByCity = {};
  String? _selectedZoneId;
  String? _selectedCityId;
  bool _isZonesLoading = false;
  bool _isCitiesLoading = false;

  // Map to resolve account names (for delivery_notes_by)
  final Map<String, String> _accountNamesById = {};
  // Keep track of assignment ids we've already marked as read so we don't call update repeatedly
  final Set<String> _seenNoteAssignments = {};

  final List<String> _filters = [
    'ALL',
    'PREPARING',
    'PENDING_DELIVERY_CONFIRMATION', // "Pending Confirmation"
    'READY',
    'DELIVERED',
    'CANCELLED',
    'NOTED',
  ];

  @override
  void initState() {
    super.initState();
    _loadZones();
    _loadAllCities();
    _loadData();
  }

  Future<void> _loadAllCities() async {
    try {
      // Load cities with zone_id to build city-to-zone mapping
      final resp = await Supabase.instance.client
          .from('cities')
          .select('id, name_en, zone_id');
      if (resp != null) {
        final list = List<Map<String, dynamic>>.from(resp as List);
        for (var c in list) {
          final id = c['id'] as String?;
          final name = c['name_en'] as String?;
          final zoneId = c['zone_id'] as String?;
          if (id != null && name != null) _cityNamesById[id] = name;
          if (id != null && zoneId != null) _cityZoneMap[id] = zoneId;
        }
      }
      // Zone names map
      final zresp = await Supabase.instance.client
          .from('zones')
          .select('id, name_en');
      if (zresp != null) {
        final zlist = List<Map<String, dynamic>>.from(zresp as List);
        for (var z in zlist) {
          final id = z['id'] as String?;
          final name = z['name_en'] as String?;
          if (id != null && name != null) _zoneNamesById[id] = name;
        }
      }
    } catch (e) {
      debugPrint('Error loading zone/city names: $e');
    }
  }

  Future<void> _loadZones() async {
    setState(() => _isZonesLoading = true);
    try {
      final resp = await Supabase.instance.client
          .from('zones')
          .select('id, name_en, name_ar')
          .order('name_en');

      if (resp != null) {
        _zones = List<Map<String, dynamic>>.from(resp as List);
      }
    } catch (e) {
      debugPrint('Error loading zones: $e');
    } finally {
      if (mounted) setState(() => _isZonesLoading = false);
    }
  }

  Future<void> _loadCitiesForZone(String zoneId) async {
    setState(() => _isCitiesLoading = true);
    try {
      final resp = await Supabase.instance.client
          .from('cities')
          .select('id, name_en, name_ar, zone_id')
          .eq('zone_id', zoneId)
          .order('name_en');

      if (resp != null) {
        _cities = List<Map<String, dynamic>>.from(resp as List);
      }
    } catch (e) {
      debugPrint('Error loading cities for zone $zoneId: $e');
    } finally {
      if (mounted) setState(() => _isCitiesLoading = false);
    }
  }

  Future<void> _markOrgNoteAsRead(
    String assignmentId,
    Map<String, dynamic>? assignment,
  ) async {
    try {
      await Supabase.instance.client
          .from('order_delivery_assignments')
          .update({'delivery_notes_unread': false})
          .eq('id', assignmentId);

      // Update local assignment map so UI updates immediately
      if (assignment != null) {
        assignment['delivery_notes_unread'] = false;
      }

      // Ensure seen set includes this assignment
      _seenNoteAssignments.add(assignmentId);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Update navbar/unread counts
      EventBus.emit('orders:updated');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Ensure that nested select fields returned from Supabase are treated
  // as lists regardless of whether the response is a Map (single item)
  // or a List (multiple items). This prevents runtime cast errors.
  List<dynamic> _ensureList(dynamic value) {
    if (value == null) return <dynamic>[];
    if (value is List) return value;
    if (value is Map) return [value];
    return <dynamic>[];
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get ORG account ID
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final orgAccount = await Supabase.instance.client
            .from('accounts')
            .select('id, location_lat, location_lng')
            .eq('owner_id', user.id)
            .eq('role', 'ORG')
            .maybeSingle();

        if (orgAccount != null) {
          _orgAccountId = orgAccount['id'] as String;
          _orgLocationLat = (orgAccount['location_lat'] as num?)?.toDouble();
          _orgLocationLng = (orgAccount['location_lng'] as num?)?.toDouble();

          // Load delivery pricing for this store
          final pricing = await _orderService.getDeliveryPricingForAccount(
            _orgAccountId!,
          );
          _deliveryPricingByCity = {
            for (var p in pricing) p['city_id'] as String: p,
          };

          // Load orders with delivery info
          final orders = await _orderService.getOrganizationOrdersWithDelivery(
            _orgAccountId!,
          );
          // Load LBP->USD rate if available
          try {
            _usdRate = await CurrencyService.getUsdRate();
          } catch (e) {
            debugPrint('Could not fetch USD rate: $e');
            _usdRate = null;
          }

          // If rate available, attach USD total to orders that are in LBP
          if (_usdRate != null) {
            for (var ord in orders) {
              try {
                if ((ord['currency_code'] as String?) == 'LBP') {
                  final lbp = (ord['total_amount'] as num).toDouble();
                  ord['total_amount_usd'] = lbp / _usdRate!;
                }
              } catch (_) {}
            }
          }

          // Ensure each order has delivery fee populated (city -> price lookup).
          for (var ord in orders) {
            try {
              final accountId = ord['account_id'] as String? ?? _orgAccountId;
              String? cityId =
                  ord['delivery_city_id'] as String? ??
                  ord['city_id'] as String?;
              final zoneId = ord['zone_id'] as String?;

              // If order has no explicit city, try customer's saved location
              if (cityId == null && ord['customer_id'] != null) {
                final custLoc =
                    _customerLocationById[ord['customer_id'] as String];
                if (custLoc != null) {
                  cityId = custLoc['city_id'];
                }
              }

              // default values
              ord['delivery_fee_lbp'] = 0;
              ord['delivery_fee_usd'] = 0;

              if (cityId != null && accountId != null) {
                // First check pricing already loaded into _deliveryPricingByCity
                final preload = _deliveryPricingByCity[cityId];
                if (preload != null &&
                    (preload['is_available'] == null ||
                        preload['is_available'] == true)) {
                  ord['delivery_fee_lbp'] =
                      (preload['price_lbp'] as num?)?.toDouble() ?? 0;
                  ord['delivery_fee_usd'] =
                      (preload['price_usd'] as num?)?.toDouble() ?? 0;
                } else {
                  // Fallback: fetch single pricing for this account/city/zone (handles missing preload or zone fallbacks)
                  final p = await _orderService.getStoreDeliveryPrice(
                    accountId: accountId,
                    cityId: cityId,
                    zoneId: zoneId,
                  );
                  if (p != null &&
                      (p['is_available'] == null ||
                          p['is_available'] == true)) {
                    ord['delivery_fee_lbp'] =
                        (p['price_lbp'] as num?)?.toDouble() ?? 0;
                    ord['delivery_fee_usd'] =
                        (p['price_usd'] as num?)?.toDouble() ?? 0;
                  }
                }
              }
            } catch (e) {
              debugPrint(
                'Error populating delivery fee for order ${ord['id']}: $e',
              );
            }
          }

          // Load delivery accounts with proximity filtering
          final deliveryAccounts = await _orderService.getDeliveryAccounts(
            orgLocationLat: _orgLocationLat,
            orgLocationLng: _orgLocationLng,
          );

          if (mounted) {
            // Resolve delivery_notes_by account names in bulk to avoid per-card queries
            final noteAuthorIds = <String>{};
            for (var o in orders) {
              final asg = _ensureList(o['order_delivery_assignments']);
              if (asg.isNotEmpty && asg.first['delivery_notes_by'] != null) {
                noteAuthorIds.add(asg.first['delivery_notes_by'] as String);
              }
            }

            if (noteAuthorIds.isNotEmpty) {
              try {
                final resp = await Supabase.instance.client
                    .from('accounts')
                    .select('id, name')
                    .in_('id', noteAuthorIds.toList());

                if (resp != null) {
                  for (var a in (resp as List)) {
                    final id = a['id'] as String;
                    final name = a['name'] as String? ?? id;
                    _accountNamesById[id] = name;
                  }
                }
              } catch (e) {
                debugPrint('Error loading note authors: $e');
              }
            }

            // Fetch customer locations from accounts table if missing in orders
            final customerIds = orders
                .map((o) => o['customer_id'] as String?)
                .whereType<String>()
                .toSet();

            if (customerIds.isNotEmpty) {
              try {
                final accountLocs = await Supabase.instance.client
                    .from('accounts')
                    .select('owner_id, zone_id, city_id')
                    .in_('owner_id', customerIds.toList());

                if (accountLocs != null) {
                  for (var acc in (accountLocs as List)) {
                    final ownerId = acc['owner_id'] as String;
                    _customerLocationById[ownerId] = {
                      'zone_id': acc['zone_id'] as String?,
                      'city_id': acc['city_id'] as String?,
                    };
                  }
                }
              } catch (e) {
                debugPrint('Error loading customer locations: $e');
              }
            }

            setState(() {
              _orders = orders;
              _deliveryAccounts = deliveryAccounts;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'ALL') return _orders;
    // PREPARING filter should show PENDING orders (new orders displayed as "Preparing")
    if (_selectedFilter == 'PREPARING') {
      return _orders
          .where((o) => o['status'] == 'PENDING' || o['status'] == 'PREPARING')
          .toList();
    }

    // Pending Confirmation: orders assigned to a delivery person but not yet confirmed by driver
    if (_selectedFilter == 'PENDING_DELIVERY_CONFIRMATION') {
      return _orders
          .where((o) => o['status'] == 'PENDING_DELIVERY_CONFIRMATION')
          .toList();
    }

    // READY filter should show CONFIRMED orders (assigned orders displayed as "Ready")
    if (_selectedFilter == 'READY') {
      return _orders
          .where((o) => o['status'] == 'READY' || o['status'] == 'CONFIRMED')
          .toList();
    }

    // NOTED filter should show orders that have delivery notes or unread notes
    if (_selectedFilter == 'NOTED') {
      return _orders.where((o) {
        final assignments = _ensureList(o['order_delivery_assignments']);
        return assignments.any((a) {
          try {
            final note = a['delivery_notes'] as String?;
            final unread = a['delivery_notes_unread'] == true;
            return (note != null && note.trim().isNotEmpty) || unread;
          } catch (_) {
            return false;
          }
        });
      }).toList();
    }
    return _orders.where((o) => o['status'] == _selectedFilter).toList();
  }

  int _countForFilter(String filter) {
    if (filter == 'ALL') return _orders.length;
    // PREPARING filter should count PENDING orders
    if (filter == 'PREPARING') {
      return _orders
          .where((o) => o['status'] == 'PENDING' || o['status'] == 'PREPARING')
          .length;
    }

    // Pending Confirmation filter
    if (filter == 'PENDING_DELIVERY_CONFIRMATION') {
      return _orders
          .where((o) => o['status'] == 'PENDING_DELIVERY_CONFIRMATION')
          .length;
    }

    // READY filter should count CONFIRMED orders
    if (filter == 'READY') {
      return _orders
          .where((o) => o['status'] == 'READY' || o['status'] == 'CONFIRMED')
          .length;
    }

    // NOTED filter: count orders that have delivery notes or unread delivery notes
    if (filter == 'NOTED') {
      return _orders.where((o) {
        final assignments = _ensureList(o['order_delivery_assignments']);
        return assignments.any((a) {
          try {
            final note = a['delivery_notes'] as String?;
            final unread = a['delivery_notes_unread'] == true;
            return (note != null && note.trim().isNotEmpty) || unread;
          } catch (_) {
            return false;
          }
        });
      }).length;
    }

    return _orders.where((o) => o['status'] == filter).length;
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

  String _formatPrice(double amount, String currency) {
    if (currency == 'LBP') {
      return '${_formatNumber(amount)} LBP';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Calculate how long an order has been in current status
  Duration _getTimeInStatus(DateTime createdAt) {
    return DateTime.now().difference(createdAt);
  }

  /// Check if order has been waiting too long based on status
  bool _isWaitingTooLong(String status, Duration timeInStatus) {
    switch (status) {
      case 'PREPARING':
        return timeInStatus.inMinutes > 30; // Alert after 30 min
      case 'READY':
        return timeInStatus.inMinutes > 20; // Alert after 20 min
      default:
        return false;
    }
  }

  /// Format time duration in human-readable format
  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else if (duration.inDays < 7) {
      return '${duration.inDays}d';
    } else if (duration.inDays < 30) {
      final weeks = (duration.inDays / 7).floor();
      return '${weeks}w';
    } else {
      final months = (duration.inDays / 30).floor();
      return '${months}mo';
    }
  }

  /// Format a DateTime to a relative string (e.g., '10m ago')
  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.purple; // PENDING displays as PREPARING (purple)
      case 'PENDING_DELIVERY_CONFIRMATION':
        return Colors.orange; // Waiting for confirmation (distinct color)
      case 'CONFIRMED':
        return Colors.teal; // CONFIRMED displays as READY (teal)
      case 'PREPARING':
        return Colors.purple;
      case 'READY':
        return Colors.teal;
      case 'DELIVERED':
        return Colors.green;
      case 'ACCEPTED_BY_DELIVERY':
        return Colors.green.shade600;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAssignDeliveryDialog(Map<String, dynamic> order) async {
    // Ensure we have a USD rate available for conversions in the dialog
    if (_usdRate == null) {
      try {
        _usdRate = await CurrencyService.getUsdRate();
      } catch (_) {
        _usdRate = null;
      }
    }
    final orderId = order['id'] as String;
    final existingAssignment = _ensureList(order['order_delivery_assignments']);
    String? currentDeliveryId;

    if (existingAssignment != null && existingAssignment.isNotEmpty) {
      currentDeliveryId =
          existingAssignment.first['delivery_account_id'] as String?;
    }

    String? selectedDeliveryId = currentDeliveryId;
    double selectedDistance = 50.0; // Default distance
    List<Map<String, dynamic>> dialogDeliveryAccounts = List.from(
      _deliveryAccounts,
    );
    bool isLoadingAccounts = false;

    // Pre-set location for pricing based on order/customer data
    _selectedCityId =
        order['delivery_city_id'] as String? ?? order['city_id'] as String?;
    _selectedZoneId = order['zone_id'] as String?;

    if (_selectedCityId == null && _selectedZoneId == null) {
      final custLoc = _customerLocationById[order['customer_id']];
      if (custLoc != null) {
        _selectedZoneId = custLoc['zone_id'];
        _selectedCityId = custLoc['city_id'];
      }
    }

    if (_selectedCityId != null && _selectedZoneId == null) {
      _selectedZoneId = _cityZoneMap[_selectedCityId];
    }

    Future<void> loadDeliveryAccountsForDistance(StateSetter setState) async {
      setState(() => isLoadingAccounts = true);

      final accounts = await _orderService.getDeliveryAccounts(
        orgLocationLat: _orgLocationLat,
        orgLocationLng: _orgLocationLng,
        maxDistanceKm: selectedDistance,
      );

      setState(() {
        dialogDeliveryAccounts = accounts;
        isLoadingAccounts = false;
        // Reset selection if current delivery not in filtered list
        if (selectedDeliveryId != null &&
            !accounts.any((a) => a['id'] == selectedDeliveryId)) {
          selectedDeliveryId = null;
        }
      });
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delivery_dining,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Assign Delivery'),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: #${orderId.substring(0, 8)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Distance selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search Distance',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [10.0, 25.0, 50.0, 100.0].map((distance) {
                            final isSelected = selectedDistance == distance;
                            return ChoiceChip(
                              label: Text('${distance.toInt()} km'),
                              selected: isSelected,
                              onSelected: (selected) async {
                                if (selected) {
                                  setDialogState(
                                    () => selectedDistance = distance,
                                  );
                                  await loadDeliveryAccountsForDistance(
                                    setDialogState,
                                  );
                                }
                              },
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Showing delivery accounts within ${selectedDistance.toInt()}km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (isLoadingAccounts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (dialogDeliveryAccounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No delivery accounts within ${selectedDistance.toInt()}km. Try increasing the distance.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedDeliveryId,
                      decoration: InputDecoration(
                        labelText: 'Select Delivery Person',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- No Assignment --'),
                        ),
                        ...dialogDeliveryAccounts.map(
                          (d) => DropdownMenuItem<String>(
                            value: d['id'] as String,
                            child: Text(d['name'] as String? ?? 'Unknown'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedDeliveryId = value);
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDeliveryId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final currentStatus = order['status'] as String? ?? '';

                      if (selectedDeliveryId == null &&
                          currentDeliveryId != null) {
                        final removed = await _orderService
                            .removeDeliveryAssignment(orderId);
                        if (removed) {
                          var statusUpdated = true;
                          if (currentStatus != 'DELIVERED' &&
                              currentStatus != 'CANCELLED') {
                            statusUpdated = await _orderService
                                .updateOrderStatus(orderId, 'PREPARING');
                          }
                          if (mounted) {
                            final idx = _orders.indexWhere(
                              (o) => o['id'] == orderId,
                            );
                            if (idx >= 0) {
                              _orders[idx]['order_delivery_assignments'] =
                                  <dynamic>[];
                              if (statusUpdated &&
                                  currentStatus != 'DELIVERED' &&
                                  currentStatus != 'CANCELLED') {
                                _orders[idx]['status'] = 'PREPARING';
                              }
                              setState(() {});
                              EventBus.emit('orders:updated');
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Delivery assignment removed. Order reverted to Preparing.',
                                ),
                              ),
                            );
                          }
                        }
                      } else if (selectedDeliveryId != null &&
                          selectedDeliveryId != currentDeliveryId) {
                        if (currentDeliveryId != null)
                          await _orderService.removeDeliveryAssignment(orderId);
                        final assignment = await _orderService
                            .assignDeliveryToOrder(
                              orderId: orderId,
                              deliveryAccountId: selectedDeliveryId!,
                              zoneId: _selectedZoneId,
                              cityId: _selectedCityId,
                            );
                        if (assignment != null && mounted) {
                          final idx = _orders.indexWhere(
                            (o) => o['id'] == orderId,
                          );
                          if (idx >= 0) {
                            final assignmentJson = {
                              'id': assignment.id,
                              'delivery_account_id':
                                  assignment.deliveryAccountId,
                              'assigned_at': assignment.assignedAt
                                  .toIso8601String(),
                              'completed_at': assignment.completedAt
                                  ?.toIso8601String(),
                              'delivery_account': {
                                'id': assignment.deliveryAccountId,
                                'name': assignment.deliveryAccountName,
                                'phone': assignment.deliveryAccountPhone,
                              },
                            };
                            _orders[idx]['order_delivery_assignments'] = [
                              assignmentJson,
                            ];
                            _orders[idx]['status'] =
                                'PENDING_DELIVERY_CONFIRMATION';
                            await _orderService.updateOrderStatus(
                              orderId,
                              'PENDING_DELIVERY_CONFIRMATION',
                            );
                            setState(() {});
                            EventBus.emit('orders:updated');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Delivery assigned successfully. Waiting for driver confirmation.',
                                ),
                              ),
                            );
                          }
                        }
                      }

                      await _loadData();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedDeliveryId == null
                    ? null
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: selectedDeliveryId == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpdateStatusDialog(Map<String, dynamic> order) async {
    final orderId = order['id'] as String;
    final currentStatus = order['status'] as String;

    final statuses = ['PREPARING', 'READY', 'DELIVERED', 'CANCELLED'];
    String selectedStatus = currentStatus;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              const Text('Update Status'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses
                .map(
                  (status) => RadioListTile<String>(
                    value: status,
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setDialogState(() => selectedStatus = value!);
                    },
                    title: Text(Order.getStatusLabel(status)),
                    activeColor: _getStatusColor(status),
                    secondary: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (selectedStatus != currentStatus) {
                  final success = await _orderService.updateOrderStatus(
                    orderId,
                    selectedStatus,
                  );
                  if (success && mounted) {
                    // Update local state immediately
                    final idx = _orders.indexWhere((o) => o['id'] == orderId);
                    if (idx >= 0) {
                      _orders[idx]['status'] = selectedStatus;
                      setState(() {});
                    }
                  }
                  await _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick action to advance order status
  Future<void> _quickAdvanceStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    final orderId = order['id'] as String;
    final currentStatus = order['status'] as String;

    try {
      final success = await _orderService.updateOrderStatus(orderId, newStatus);

      if (success && mounted) {
        // Update local state immediately
        final idx = _orders.indexWhere((o) => o['id'] == orderId);
        if (idx >= 0) {
          _orders[idx]['status'] = newStatus;
          setState(() {});
        }

        // If marking as READY, notify delivery driver
        if (newStatus == 'READY') {
          await _notifyDeliveryDriver(order);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as ${Order.getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh from server
        await _loadData();
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

  /// Notify delivery driver when order is ready
  /// TODO: Implement push notification with Firebase/OneSignal
  Future<void> _notifyDeliveryDriver(Map<String, dynamic> order) async {
    final assignments = _ensureList(order['order_delivery_assignments']);

    if (assignments.isEmpty) {
      debugPrint('No delivery driver assigned to notify');
      return;
    }

    final assignment = assignments.first;
    final deliveryAccountId = assignment['delivery_account_id'] as String?;

    if (deliveryAccountId == null) {
      debugPrint('No delivery account ID found');
      return;
    }

    try {
      // TODO: Send push notification via Firebase Cloud Messaging
      // Example implementation:
      // await NotificationService.sendToDevice(
      //   userId: deliveryAccountId,
      //   title: 'Order Ready for Pickup',
      //   body: 'Order #${(order['id'] as String).substring(0, 8)} is ready',
      // );

      debugPrint(
        'Notification sent to driver: $deliveryAccountId (placeholder)',
      );

      // For now, just log it
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery driver notified'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error notifying driver: $e');
    }
  }

  /// Show dialog to edit delivery note (ORG view)
  Future<void> _showEditDeliveryNoteDialog(
    Map<String, dynamic> order,
    String? assignmentId,
  ) async {
    if (assignmentId == null) return;

    final assignments = _ensureList(order['order_delivery_assignments']);
    String? currentNote;
    if (assignments.isNotEmpty) {
      currentNote = assignments.first['delivery_notes'] as String?;
    }

    final TextEditingController noteController = TextEditingController(
      text: currentNote ?? '',
    );

    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.orange),
            SizedBox(width: 12),
            Text('Edit Delivery Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${(order['id'] as String).substring(0, 8)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Edit delivery note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (note != null && mounted) {
      try {
        await Supabase.instance.client
            .from('order_delivery_assignments')
            .update({
              'delivery_notes': note,
              'delivery_notes_by': _orgAccountId,
              'delivery_notes_updated_at': DateTime.now()
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('id', assignmentId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note updated'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh data
          await _loadData();

          // Notify other widgets
          EventBus.emit('orders:updated');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update note: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Confirm and cancel an order
  Future<void> _confirmCancelOrder(Map<String, dynamic> order) async {
    final orderId = order['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Text('Cancel Order'),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel order #${orderId.substring(0, 8)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _orderService.cancelOrder(orderId);
        if (success && mounted) {
          final idx = _orders.indexWhere((o) => o['id'] == orderId);
          if (idx >= 0) {
            _orders[idx]['status'] = 'CANCELLED';
            _orders[idx]['order_delivery_assignments'] = <dynamic>[];
            setState(() {});
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order successfully cancelled'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh from server to ensure consistency
          await _loadData();

          // Notify navbar and other listeners
          EventBus.emit('orders:updated');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        title: Text('Orders Management'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
        //     onPressed: _loadData,
        //   ),
        // ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final count = _countForFilter(filter);
                  final labelText = filter == 'ALL'
                      ? 'All'
                      : (filter == 'NOTED'
                            ? 'Noted'
                            : Order.getStatusLabel(filter));
                  final badgeColor = filter == 'ALL'
                      ? Colors.blue
                      : (filter == 'NOTED'
                            ? Colors.pinkAccent
                            : _getStatusColor(filter));

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FilterChip(
                          label: Text(labelText),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter);
                          },
                          selectedColor: filter == 'ALL'
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.12)
                              : _getStatusColor(filter).withValues(alpha: 0.2),
                          checkmarkColor: filter == 'ALL'
                              ? Theme.of(context).colorScheme.primary
                              : _getStatusColor(filter),
                        ),
                        if (count > 0)
                          Positioned(
                            top: -2,
                            right: -8,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: badgeColor,
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
                                  '$count',
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
                  );
                }).toList(),
              ),
            ),
          ),

          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(_filteredOrders[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'ALL'
                ? 'No orders yet'
                : 'No ${Order.getStatusLabel(_selectedFilter).toLowerCase()} orders',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String;
    final status = order['status'] as String;
    final totalAmount = (order['total_amount'] as num).toDouble();
    final currencyCode = order['currency_code'] as String;
    final createdAt = DateTime.parse(order['created_at'] as String);
    final items = _ensureList(order['order_items']);
    final assignments = _ensureList(order['order_delivery_assignments']);

    // Get city ID for delivery fee (use delivery_city_id if provided, otherwise order city)
    final String? orderCityId =
        order['delivery_city_id'] as String? ?? order['city_id'] as String?;
    final String? orderCityName = orderCityId != null
        ? _cityNamesById[orderCityId]
        : null;

    double deliveryFeeLbp = 0;
    double deliveryFeeUsd = 0;

    // Prefer per-order attached fees (populated during _loadData)
    if (order.containsKey('delivery_fee_lbp')) {
      deliveryFeeLbp = (order['delivery_fee_lbp'] as num?)?.toDouble() ?? 0;
      deliveryFeeUsd = (order['delivery_fee_usd'] as num?)?.toDouble() ?? 0;
    } else if (orderCityId != null) {
      // Fallback to preloaded map by city
      final prc = _deliveryPricingByCity[orderCityId];
      if (prc != null &&
          (prc['is_available'] == true || prc['is_available'] == null)) {
        deliveryFeeLbp = (prc['price_lbp'] as num?)?.toDouble() ?? 0;
        deliveryFeeUsd = (prc['price_usd'] as num?)?.toDouble() ?? 0;
      }
    }

    // Calculate time in status
    final timeInStatus = _getTimeInStatus(createdAt);
    final isWaitingTooLong = _isWaitingTooLong(status, timeInStatus);

    // Get delivery info if assigned
    Map<String, dynamic>? deliveryInfo;
    if (assignments.isNotEmpty) {
      final assignment = assignments.first;
      if (assignment['delivery_account'] != null) {
        deliveryInfo = assignment['delivery_account'] as Map<String, dynamic>;
      }
    }

    final bool hasUnreadNote =
        assignments.isNotEmpty &&
        (assignments.first['delivery_notes_unread'] == true);

    // Show visual alert (border / header tint) only when waiting too long
    // or there is an unread delivery note — but do NOT show these when
    // the order status is `READY` (user requested no red/exclamation on Ready).
    final bool showAlert =
        (isWaitingTooLong || hasUnreadNote) && status != 'READY';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isWaitingTooLong ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: showAlert
            ? BorderSide(
                color: Theme.of(context).colorScheme.error.withOpacity(0.6),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: showAlert
                  ? Theme.of(context).colorScheme.errorContainer
                  : _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Warning indicator if waiting too long (but not for READY)
                if (isWaitingTooLong && status != 'READY')
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 24,
                    ),
                  ),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            Order.getStatusLabel(status),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: showAlert
                                ? Theme.of(context).colorScheme.errorContainer
                                : Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: isWaitingTooLong
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatDuration(timeInStatus),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isWaitingTooLong
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${orderId.substring(0, 8)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Trash / Cancel icon next to order id
                IconButton(
                  onPressed: (status == 'DELIVERED' || status == 'CANCELLED')
                      ? null
                      : () => _confirmCancelOrder(order),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                  tooltip: 'Cancel order',
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
                // Order details - Time
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(createdAt),
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
                    // Item count and image card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
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
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Items',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${items.length}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Product image
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: _buildOrderImageSmall(items),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Price card
                    Flexible(
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
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                final currentDeliveryFee = currencyCode == 'LBP'
                                    ? deliveryFeeLbp
                                    : deliveryFeeUsd;
                                final grandTotal =
                                    totalAmount + currentDeliveryFee;

                                // consider any attached or preloaded pricing as "applied"
                                final bool hasAnyDeliveryFee =
                                    (deliveryFeeLbp > 0) ||
                                    (deliveryFeeUsd > 0);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Always show subtotal + delivery breakdown for clarity
                                    Text(
                                      'Subtotal: ${_formatPrice(totalAmount, currencyCode)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    // If there is no fee at all and order has no resolved city -> show explicit hint
                                    if (!hasAnyDeliveryFee &&
                                        orderCityId == null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_off,
                                              size: 12,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Delivery city unknown — fee not applied',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.grey.shade300,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (!hasAnyDeliveryFee &&
                                        (orderCityId != null) &&
                                        (currentDeliveryFee == 0) &&
                                        !_deliveryPricingByCity.containsKey(
                                          orderCityId,
                                        ))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Delivery not configured${orderCityName != null ? ' for $orderCityName' : ''}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.yellow.shade200,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                // Open delivery settings so admin can add pricing
                                                Navigator.pushNamed(
                                                  context,
                                                  '/settings/delivery',
                                                  arguments: {
                                                    'accountId': _orgAccountId,
                                                    'cityId': orderCityId,
                                                  },
                                                );
                                              },
                                              child: Icon(
                                                Icons.add_circle_outline,
                                                size: 14,
                                                color: Colors.yellow.shade200,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Text(
                                        orderCityId == null && hasAnyDeliveryFee
                                            ? 'Delivery Fee (applied): ${_formatPrice(currentDeliveryFee, currencyCode)}'
                                            : 'Delivery Fee (based on city${orderCityName != null ? ': $orderCityName' : ''}): ${_formatPrice(currentDeliveryFee, currencyCode)}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatPrice(grandTotal, currencyCode),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (currencyCode == 'LBP')
                              Builder(
                                builder: (_) {
                                  double? usdBase;
                                  if (order['total_amount_usd'] != null) {
                                    usdBase =
                                        (order['total_amount_usd'] as double);
                                  } else if (_usdRate != null) {
                                    usdBase = totalAmount / _usdRate!;
                                  }
                                  if (usdBase == null) {
                                    return const SizedBox.shrink();
                                  }

                                  final grandTotalUsd =
                                      usdBase + deliveryFeeUsd;

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '\u2248 \$${grandTotalUsd.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (deliveryFeeUsd > 0)
                                          Text(
                                            '(Sub \$${usdBase.toStringAsFixed(2)} + Del \$${deliveryFeeUsd.toStringAsFixed(2)})',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                          ),
                                      ],
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

                // Customer delivery / contact info
                Builder(
                  builder: (_) {
                    final contactName = order['contact_name'] as String?;
                    final deliveryAddress =
                        order['delivery_address'] as String?;
                    final deliveryPhone = order['delivery_phone'] as String?;

                    if (contactName == null &&
                        deliveryAddress == null &&
                        deliveryPhone == null) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Customer Order Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              if (deliveryPhone != null ||
                                  deliveryAddress != null) ...[
                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  color: Theme.of(context).dividerColor,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (contactName != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_circle,
                                      size: 16,
                                      color: Theme.of(context).disabledColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        contactName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (deliveryPhone != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: Theme.of(context).disabledColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        deliveryPhone,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
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

                                  // Prefer delivery_city_id for the delivery location zone/city
                                  if (order['delivery_city_id'] != null) {
                                    final cityId =
                                        order['delivery_city_id'] as String?;
                                    if (cityId != null) {
                                      // Look up city name
                                      cityName = _cityNamesById[cityId];
                                      // Look up zone for this city
                                      if (cityName != null) {
                                        final zoneId = _cityZoneMap[cityId];
                                        if (zoneId != null) {
                                          zoneName = _zoneNamesById[zoneId];
                                        }
                                      }
                                    }
                                  }

                                  // Fallback to order zone_id / city_id if available
                                  if (zoneName == null &&
                                      order['zone_id'] != null) {
                                    final z = order['zone_id'] as String?;
                                    zoneName = z != null
                                        ? (_zoneNamesById[z] ?? z)
                                        : null;
                                  }
                                  if (cityName == null &&
                                      order['city_id'] != null) {
                                    final c = order['city_id'] as String?;
                                    cityName = c != null
                                        ? (_cityNamesById[c] ?? c)
                                        : null;
                                  }

                                  // New fallback: use location from accounts table if both are still null
                                  if (zoneName == null && cityName == null) {
                                    final custLoc =
                                        _customerLocationById[order['customer_id']];
                                    if (custLoc != null) {
                                      final zId = custLoc['zone_id'];
                                      final cId = custLoc['city_id'];
                                      if (zId != null)
                                        zoneName = _zoneNamesById[zId];
                                      if (cId != null)
                                        cityName = _cityNamesById[cId];
                                    }
                                  }

                                  // Final fallback to direct name fields
                                  zoneName ??=
                                      order['zone_name'] as String? ??
                                      order['zone'] as String?;
                                  cityName ??=
                                      order['city_name'] as String? ??
                                      order['city'] as String?;

                                  final parts = <String>[];
                                  if (zoneName != null && zoneName.isNotEmpty) {
                                    parts.add(zoneName);
                                  }
                                  if (cityName != null && cityName.isNotEmpty) {
                                    parts.add(cityName);
                                  }
                                  if (deliveryAddress != null &&
                                      deliveryAddress.isNotEmpty) {
                                    parts.add(deliveryAddress);
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
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Delivery Assignment Section
                Row(
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      size: 20,
                      color: deliveryInfo != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: deliveryInfo != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned to: ${deliveryInfo['name'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (deliveryInfo['phone'] != null)
                                  Text(
                                    deliveryInfo['phone'] as String,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            )
                          : Text(
                              'No delivery assigned',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAssignDeliveryDialog(order),
                      icon: Icon(
                        deliveryInfo != null ? Icons.edit : Icons.add,
                        size: 18,
                      ),
                      label: Text(deliveryInfo != null ? 'Change' : 'Assign'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ],
                ),

                // Delivery Notes Section
                Builder(
                  builder: (_) {
                    String? deliveryNotes;
                    Map<String, dynamic>? assignment;
                    if (assignments.isNotEmpty) {
                      assignment = assignments.first as Map<String, dynamic>?;
                      deliveryNotes = assignment?['delivery_notes'] as String?;
                    }

                    if (deliveryNotes != null && deliveryNotes.isNotEmpty) {
                      // compute meta: author and time
                      String? authorName;
                      DateTime? updatedAt;
                      bool isUnread = false;

                      // Safely extract fields from nullable assignment map
                      final String? deliveryNotesBy =
                          assignment != null &&
                              assignment['delivery_notes_by'] != null
                          ? assignment['delivery_notes_by'] as String?
                          : null;
                      final String? deliveryNotesUpdatedAt =
                          assignment != null &&
                              assignment['delivery_notes_updated_at'] != null
                          ? assignment['delivery_notes_updated_at'] as String?
                          : null;
                      final bool deliveryNotesUnread =
                          assignment != null &&
                          assignment['delivery_notes_unread'] == true;

                      if (deliveryNotesBy != null) {
                        authorName = _accountNamesById[deliveryNotesBy];
                      }
                      if (deliveryNotesUpdatedAt != null) {
                        try {
                          updatedAt = DateTime.parse(deliveryNotesUpdatedAt);
                        } catch (_) {}
                      }
                      if (deliveryNotesUnread) {
                        isUnread = true;
                      }

                      // Assignment id (if present)
                      final String? assignmentId =
                          assignment != null && assignment['id'] != null
                          ? assignment['id'] as String?
                          : null;

                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? Colors.red.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUnread
                                    ? Colors.red.shade300
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sticky_note_2,
                                  size: 20,
                                  color: isUnread
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Delivery Note',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isUnread
                                                  ? Colors.red.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                          if (authorName != null ||
                                              updatedAt != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '·',
                                              style: TextStyle(
                                                color: isUnread
                                                    ? Colors.red.shade700
                                                    : Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                          if (authorName != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                authorName,
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          if (updatedAt != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                _formatRelative(updatedAt),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        deliveryNotes,
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // ORG should be able to mark notes as read so they control unread badge
                                if (isUnread && assignmentId != null)
                                  IconButton(
                                    onPressed: () => _markOrgNoteAsRead(
                                      assignmentId,
                                      assignment,
                                    ),
                                    icon: Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green.shade700,
                                    ),
                                    tooltip: 'Mark as read',
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

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateStatusDialog(order),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text(
                          'Update Status',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue.shade200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetails(order),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text(
                          'View Details',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  void _showOrderDetails(Map<String, dynamic> order) {
    // Navigate to the detailed order screen with delivery tracking
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order)),
    );
  }

  // Legacy method kept as reference - use _showOrderDetails instead
  void _showOrderDetailsBottomSheet(Map<String, dynamic> order) {
    final items = _ensureList(order['order_items']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Order Items',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Show customer and delivery info at the top of details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Delivery Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final contactName = order['contact_name'] as String?;
                      final deliveryAddress =
                          order['delivery_address'] as String?;
                      final deliveryPhone = order['delivery_phone'] as String?;
                      final assignments = _ensureList(
                        order['order_delivery_assignments'],
                      );
                      String deliveryAssignedTo = 'No delivery assigned';
                      String? deliveryAssignedPhone;
                      if (assignments.isNotEmpty) {
                        final a = assignments.first;
                        if (a['delivery_account'] != null) {
                          final acc =
                              a['delivery_account'] as Map<String, dynamic>;
                          deliveryAssignedTo =
                              acc['name'] as String? ?? deliveryAssignedTo;
                          deliveryAssignedPhone = acc['phone'] as String?;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (contactName != null)
                            Text(
                              contactName,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          if (deliveryPhone != null)
                            Text(
                              deliveryPhone,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          if (deliveryAddress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                deliveryAddress,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Assigned Delivery: $deliveryAssignedTo',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (deliveryAssignedPhone != null)
                            Text(
                              deliveryAssignedPhone,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  const Divider(),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index] as Map<String, dynamic>;
                  final quantity = item['quantity'] as int;
                  final price = (item['price'] as num).toDouble();
                  final productId = item['product_id'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                      title: Text('Product #${productId.substring(0, 8)}'),
                      subtitle: Text('Qty: $quantity'),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(
                              price * quantity,
                              order['currency_code'] as String,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if ((order['currency_code'] as String) == 'LBP')
                            Builder(
                              builder: (_) {
                                double? usd;
                                if (order['total_amount_usd'] != null &&
                                    _usdRate != null) {
                                  // If order-level USD exists, compute item USD proportionally
                                  final orderLbp =
                                      (order['total_amount'] as num).toDouble();
                                  if (orderLbp > 0) {
                                    final itemLbp = price * quantity;
                                    final proportion = itemLbp / orderLbp;
                                    usd =
                                        (order['total_amount_usd'] as double) *
                                        proportion;
                                  }
                                } else if (_usdRate != null) {
                                  usd = (price * quantity) / _usdRate!;
                                }
                                if (usd == null) return const SizedBox.shrink();
                                return Text(
                                  '\$${usd.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build small order image thumbnail from first item (55x55)
  Widget _buildOrderImageSmall(List<dynamic> items) {
    String? imageUrl;

    // Get first item's product image
    if (items.isNotEmpty) {
      final firstItem = items.first as Map<String, dynamic>?;
      if (firstItem != null) {
        final products = firstItem['products'] as Map<String, dynamic>?;
        imageUrl = products?['image_url'] as String?;
      }
    }

    final content = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: imageUrl == null
          ? Icon(
              Icons.image_outlined,
              color: Theme.of(context).disabledColor,
              size: 24,
            )
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
                    color: Theme.of(context).disabledColor,
                    size: 24,
                  );
                },
              ),
            ),
    );

    if (imageUrl == null) return content;
    return InkWell(
      onTap: () => _showImagePreview(imageUrl!),
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }

  /// Build order image thumbnail from first item
  Widget _buildOrderImage(List<dynamic> items) {
    String? imageUrl;

    // Get first item's product image
    if (items.isNotEmpty) {
      final firstItem = items.first as Map<String, dynamic>?;
      if (firstItem != null) {
        final products = firstItem['products'] as Map<String, dynamic>?;
        imageUrl = products?['image_url'] as String?;
      }
    }

    final content = Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: imageUrl == null
          ? Icon(
              Icons.image_outlined,
              color: Theme.of(context).disabledColor,
              size: 32,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 70,
                height: 70,
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
                  return Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey.shade400,
                    size: 32,
                  );
                },
              ),
            ),
    );

    if (imageUrl == null) return content;
    return InkWell(
      onTap: () => _showImagePreview(imageUrl!),
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}
