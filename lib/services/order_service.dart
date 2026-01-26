import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/cart.dart';
// import '../models/cart_item.dart'; // not required here
import '../models/order_delivery_assignment.dart';
import 'notification_service.dart';

/// Service for managing orders
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  /// Create an order from a cart
  Future<Order?> createOrderFromCart(Cart cart, {Map<String, dynamic>? customerInfo}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to create an order');
      }

      if (cart.items.isEmpty) {
        throw Exception('Cart is empty');
      }

      // Determine the currency and total amount
      // Prefer LBP if available, otherwise use USD
      String currencyCode;
      double totalAmount;

      if (cart.totalPriceLbp != null && cart.totalPriceLbp! > 0) {
        currencyCode = 'LBP';
        totalAmount = cart.totalPriceLbp!;
      } else if (cart.totalPriceUsd != null && cart.totalPriceUsd! > 0) {
        currencyCode = 'USD';
        totalAmount = cart.totalPriceUsd!;
      } else {
        throw Exception('Cart has no valid price');
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🛒 [OrderService] Creating order from cart');
      debugPrint(
        '   📦 Organization: ${cart.organizationName} (${cart.organizationId})',
      );
      debugPrint('   👤 Customer: ${user.email} (${user.id})');
      debugPrint('   💰 Total: $totalAmount $currencyCode');
      debugPrint('   📝 Items: ${cart.items.length}');

      // Create the order
      final insertData = {
        'account_id': cart.organizationId,
        'customer_id': user.id,
        'total_amount': totalAmount,
        'currency_code': currencyCode,
        'status': 'PENDING',
      };

      // Merge optional customer information into the order record (delivery/contact info)
      if (customerInfo != null) {
        if (customerInfo['contact_name'] != null) {
          insertData['contact_name'] = customerInfo['contact_name'];
        }
        if (customerInfo['delivery_address'] != null) {
          insertData['delivery_address'] = customerInfo['delivery_address'];
        }
        if (customerInfo['delivery_phone'] != null) {
          insertData['delivery_phone'] = customerInfo['delivery_phone'];
        }
        if (customerInfo['notes'] != null) {
          insertData['notes'] = customerInfo['notes'];
        }
      }

      final orderResponse = await _supabase
          .from('orders')
          .insert(insertData)
          .select()
          .single();

      final orderId = orderResponse['id'] as String;
      debugPrint('   ✅ Order created: $orderId');

      // Create order items
      final orderItems = <Map<String, dynamic>>[];
      for (var item in cart.items) {
        // Determine the price based on currency
        double price;
        if (currencyCode == 'LBP') {
          price = item.product.priceLbp?.toDouble() ?? 0;
        } else {
          price = item.product.priceUsd ?? 0;
        }

        orderItems.add({
          'order_id': orderId,
          'product_id': item.product.id,
          'quantity': item.quantity,
          'price': price,
        });
      }

      await _supabase.from('order_items').insert(orderItems);
      debugPrint('   ✅ ${orderItems.length} order items created');

      // Deduct product quantities from stock
      for (var item in cart.items) {
        final productId = item.product.id;
        final orderedQuantity = item.quantity;
        
        // Get current product quantity
        final productResponse = await _supabase
            .from('products')
            .select('quantity')
            .eq('id', productId)
            .single();
        
        final currentQuantity = productResponse['quantity'] as int? ?? 0;
        final newQuantity = (currentQuantity - orderedQuantity).clamp(0, currentQuantity);
        
        // Update product quantity and in_stock status
        await _supabase
            .from('products')
            .update({
              'quantity': newQuantity,
              'in_stock': newQuantity > 0,
            })
            .eq('id', productId);
        
        debugPrint('   📦 Product $productId: $currentQuantity -> $newQuantity');
      }
      debugPrint('   ✅ Product quantities updated');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Notify the organization about the new order
      try {
        final customerAccount = await _supabase
            .from('accounts')
            .select('name')
            .eq('owner_id', user.id)
            .maybeSingle();
        
        final customerName = customerAccount?['name'] ?? user.email ?? 'Customer';
        
        await _notificationService.notifyOrgNewOrder(
          orgAccountId: cart.organizationId,
          orderNumber: orderId.substring(0, 8),
          customerName: customerName,
          totalAmount: totalAmount,
          currency: currencyCode,
        );
        
        debugPrint('   ✅ Organization notified about new order');
      } catch (e) {
        debugPrint('   ⚠️ Could not send notification to organization: $e');
        // Don't fail the order creation if notification fails
      }

      // Return the created order
      return Order.fromJson(orderResponse);
    } catch (e) {
      debugPrint('❌ [OrderService] Error creating order: $e');
      rethrow;
    }
  }

  /// Create orders from multiple carts (for combined checkout)
  Future<List<Order>> createOrdersFromCarts(List<Cart> carts, {Map<String, dynamic>? customerInfo}) async {
    final orders = <Order>[];

    for (var cart in carts) {
      if (cart.items.isNotEmpty) {
        final order = await createOrderFromCart(cart, customerInfo: customerInfo);
        if (order != null) {
          orders.add(order);
        }
      }
    }

    return orders;
  }

  /// Get orders for the current user (customer)
  Future<List<Order>> getCustomerOrders() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching customer orders: $e');
      return [];
    }
  }

  /// Get orders for an organization (account)
  Future<List<Order>> getOrganizationOrders(String accountId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('account_id', accountId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching organization orders: $e');
      return [];
    }
  }

  /// Get a single order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching order: $e');
      return null;
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);

      debugPrint(
        '✅ [OrderService] Order $orderId status updated to $newStatus',
      );
      return true;
    } catch (e) {
      debugPrint('❌ [OrderService] Error updating order status: $e');
      return false;
    }
  }

  /// Cancel an order
  Future<bool> cancelOrder(String orderId) async {
    return await updateOrderStatus(orderId, 'CANCELLED');
  }

  // ============== DELIVERY ASSIGNMENT METHODS ==============

  /// Get all delivery accounts
  /// If [orgLocationLat] and [orgLocationLng] are provided, only returns delivery
  /// accounts within [maxDistanceKm] of the organization's location.
  /// Default max distance is 50 km.
  Future<List<Map<String, dynamic>>> getDeliveryAccounts({
    double? orgLocationLat,
    double? orgLocationLng,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      final response = await _supabase
          .from('accounts')
          .select('id, name, phone, email, location_lat, location_lng')
          .eq('role', 'DELIVERY')
          .order('name');

      final allAccounts = (response as List).cast<Map<String, dynamic>>();

      // If no org location provided, return all accounts
      if (orgLocationLat == null || orgLocationLng == null) {
        debugPrint('⚠️ [OrderService] No org location provided - returning all delivery accounts');
        return allAccounts;
      }

      // Filter by proximity using Haversine formula
      final nearbyAccounts = allAccounts.where((account) {
        final lat = (account['location_lat'] as num?)?.toDouble();
        final lng = (account['location_lng'] as num?)?.toDouble();

        // Skip accounts without location data
        if (lat == null || lng == null) {
          debugPrint('⚠️ [OrderService] Skipping account ${account['name']} - no location data');
          return false;
        }

        final distance = _calculateDistance(orgLocationLat, orgLocationLng, lat, lng);
        debugPrint('📍 [OrderService] ${account['name']}: ${distance.toStringAsFixed(2)} km away');
        return distance <= maxDistanceKm;
      }).toList();

      debugPrint('✅ [OrderService] Found ${nearbyAccounts.length}/${allAccounts.length} delivery accounts within ${maxDistanceKm}km');
      return nearbyAccounts;
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching delivery accounts: $e');
      return [];
    }
  }

  /// Calculate distance between two coordinates using Haversine formula (in kilometers)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371.0;
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Assign a delivery person to an order
  Future<OrderDeliveryAssignment?> assignDeliveryToOrder({
    required String orderId,
    required String deliveryAccountId,
  }) async {
    try {
      debugPrint('🚚 [OrderService] Assigning delivery to order: $orderId');
      
      final response = await _supabase
          .from('order_delivery_assignments')
          .insert({
            'order_id': orderId,
            'delivery_account_id': deliveryAccountId,
          })
          .select('*, delivery_account:accounts!fk_order_delivery_account(name, phone)')
          .single();

      debugPrint('✅ [OrderService] Delivery assigned successfully');
      
      // Update order status to CONFIRMED
      await updateOrderStatus(orderId, 'CONFIRMED');
      
      // Notify delivery person about the assignment
      try {
        final orderData = await _supabase
            .from('orders')
            .select('account:accounts!fk_order_account(name, location_address), delivery_address')
            .eq('id', orderId)
            .single();
        
        final orgAccount = orderData['account'] as Map<String, dynamic>?;
        final pickupAddress = orgAccount?['location_address'] ?? 'Store location';
        final deliveryAddress = orderData['delivery_address'] ?? 'Customer address';
        
        await _notificationService.notifyDeliveryAssignment(
          deliveryAccountId: deliveryAccountId,
          orderNumber: orderId.substring(0, 8),
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
        );
        
        debugPrint('   ✅ Delivery person notified about assignment');
      } catch (e) {
        debugPrint('   ⚠️ Could not send notification to delivery person: $e');
        // Don't fail the assignment if notification fails
      }
      
      return OrderDeliveryAssignment.fromJson(response);
    } catch (e) {
      debugPrint('❌ [OrderService] Error assigning delivery: $e');
      return null;
    }
  }

  /// Remove delivery assignment from an order
  Future<bool> removeDeliveryAssignment(String orderId) async {
    try {
      await _supabase
          .from('order_delivery_assignments')
          .delete()
          .eq('order_id', orderId);

      debugPrint('✅ [OrderService] Delivery assignment removed');
      return true;
    } catch (e) {
      debugPrint('❌ [OrderService] Error removing delivery assignment: $e');
      return false;
    }
  }

  /// Get delivery assignment for an order
  Future<OrderDeliveryAssignment?> getDeliveryAssignment(String orderId) async {
    try {
      final response = await _supabase
          .from('order_delivery_assignments')
          .select('*, delivery_account:accounts!fk_order_delivery_account(name, phone)')
          .eq('order_id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return OrderDeliveryAssignment.fromJson(response);
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching delivery assignment: $e');
      return null;
    }
  }

  /// Get delivery assignments for multiple orders
  Future<Map<String, OrderDeliveryAssignment>> getAssignmentsForOrders(List<String> orderIds) async {
    final Map<String, OrderDeliveryAssignment> map = {};
    if (orderIds.isEmpty) return map;

    try {
      final response = await _supabase
          .from('order_delivery_assignments')
          .select('*, delivery_account:accounts!fk_order_delivery_account(name, phone)')
          .in_('order_id', orderIds);

      if (response == null) return map;
      for (var item in (response as List)) {
        final ada = OrderDeliveryAssignment.fromJson(item as Map<String, dynamic>);
        map[ada.orderId] = ada;
      }
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching assignments for orders: $e');
    }

    return map;
  }

  /// Get orders assigned to a delivery account
  /// Get orders assigned to a delivery account
  ///
  /// By default this returns only non-completed assignments (pending deliveries).
  /// Set [includeCompleted] to true to include completed deliveries as well.
  Future<List<Order>> getDeliveryOrders(String deliveryAccountId, {bool includeCompleted = false}) async {
    try {
      // First get assignments for this delivery account
      final assignmentsResponse = await _supabase
          .from('order_delivery_assignments')
          .select('order_id, completed_at')
          .eq('delivery_account_id', deliveryAccountId);

      if (assignmentsResponse == null || (assignmentsResponse as List).isEmpty) {
        return [];
      }

      // Filter by completion if requested
      final assignmentsList = (assignmentsResponse as List).cast<Map<String, dynamic>>();
      final filtered = assignmentsList.where((a) {
        final completed = a['completed_at'] != null;
        return includeCompleted ? true : !completed;
      }).toList();

      if (filtered.isEmpty) return [];

      final orderIds = filtered.map((a) => a['order_id'] as String).toSet().toList();

      // Then fetch those orders with their items and product details
      final ordersResponse = await _supabase
          .from('orders')
          .select('*, order_items(*, products(*))')
          .in_('id', orderIds)
          .order('created_at', ascending: false);

      return (ordersResponse as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching delivery orders: $e');
      return [];
    }
  }

  /// Mark delivery as completed
  Future<bool> completeDelivery(String orderId) async {
    try {
      await _supabase
          .from('order_delivery_assignments')
          .update({
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'delivery_notes_unread': false, // clear unread on completion
          })
          .eq('order_id', orderId);

      // Update order status to DELIVERED
      await updateOrderStatus(orderId, 'DELIVERED');

      debugPrint('✅ [OrderService] Delivery completed for order: $orderId');
      return true;
    } catch (e) {
      debugPrint('❌ [OrderService] Error completing delivery: $e');
      return false;
    }
  }

  /// Get orders with their delivery assignments for an organization
  Future<List<Map<String, dynamic>>> getOrganizationOrdersWithDelivery(String accountId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(*, products(*)),
            order_delivery_assignments(
              id,
              delivery_account_id,
              assigned_at,
              completed_at,
              delivery_notes,
              delivery_notes_by,
              delivery_notes_updated_at,
              delivery_notes_unread,
              delivery_account:accounts!fk_order_delivery_account(id, name, phone)
            )
          ''')
          .eq('account_id', accountId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      // Fallback for older DB schemas where delivery_notes_unread or metadata columns don't exist
      debugPrint('⚠️ [OrderService] new fields missing, retrying without delivery_notes metadata: $e');
      try {
        final response = await _supabase
            .from('orders')
            .select('''
              *,
              order_items(*, products(*)),
              order_delivery_assignments(
                id,
                delivery_account_id,
                assigned_at,
                completed_at,
                delivery_notes,
                delivery_account:accounts!fk_order_delivery_account(id, name, phone)
              )
            ''')
            .eq('account_id', accountId)
            .order('created_at', ascending: false);

        return (response as List).cast<Map<String, dynamic>>();
      } catch (e2) {
        debugPrint('❌ [OrderService] Error fetching orders with delivery (fallback failed): $e2');
        return [];
      }
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching orders with delivery: $e');
      return [];
    }
  }

  /// Get active orders for current user (customer) that have delivery tracking
  /// Returns orders that are CONFIRMED or IN_TRANSIT with delivery assignments
  Future<List<Map<String, dynamic>>> getCustomerActiveDeliveryOrders() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      // Get orders that are in delivery status (not PENDING, CANCELLED, or DELIVERED)
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(*, products(*)),
            order_delivery_assignments(
              id,
              delivery_account_id,
              assigned_at,
              completed_at,
              delivery_account:accounts!fk_order_delivery_account(id, name, phone)
            )
          ''')
          .eq('customer_id', user.id)
          .in_('status', ['CONFIRMED', 'READY', 'IN_TRANSIT'])
          .order('created_at', ascending: false);

      // Filter to only orders that have delivery assignments
      final ordersWithDelivery = (response as List)
          .cast<Map<String, dynamic>>()
          .where((order) {
            final assignmentsData = order['order_delivery_assignments'];
            List<dynamic>? assignments;
            if (assignmentsData is List) {
              assignments = assignmentsData;
            } else if (assignmentsData is Map) {
              assignments = [assignmentsData];
            }
            return assignments != null && assignments.isNotEmpty;
          })
          .toList();

      debugPrint('📦 [OrderService] Found ${ordersWithDelivery.length} active delivery orders for customer');
      return ordersWithDelivery;
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching customer active deliveries: $e');
      return [];
    }
  }

  /// Get pending orders for current user (customer) that don't have delivery assignments yet
  /// Also checks if the organization has delivery service available
  /// Returns a map with 'orders' and 'orgsWithoutDelivery' lists
  Future<Map<String, dynamic>> getCustomerPendingOrdersStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'orders': [], 'orgsWithoutDelivery': []};
      }

      // Get customer's pending/confirmed orders that don't have delivery assignments
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_delivery_assignments(id)
          ''')
          .eq('customer_id', user.id)
          .in_('status', ['PENDING', 'CONFIRMED', 'READY'])
          .order('created_at', ascending: false);

      final pendingOrders = (response as List).cast<Map<String, dynamic>>();
      
      // Get orders without delivery assignments
      final ordersWithoutDelivery = pendingOrders.where((order) {
        final assignmentsData = order['order_delivery_assignments'];
        List<dynamic>? assignments;
        if (assignmentsData is List) {
          assignments = assignmentsData;
        } else if (assignmentsData is Map) {
          assignments = [assignmentsData];
        }
        return assignments == null || assignments.isEmpty;
      }).toList();

      // Check if any organization doesn't have delivery accounts
      // Get all delivery accounts
      final deliveryAccounts = await getDeliveryAccounts();
      final hasDeliveryService = deliveryAccounts.isNotEmpty;

      // Find orgs that don't have any delivery assigned to their orders
      final orgsWithoutDelivery = <String>[];
      if (!hasDeliveryService && ordersWithoutDelivery.isNotEmpty) {
        // Get org names for these orders
        final accountIds = ordersWithoutDelivery
            .map((o) => o['account_id'] as String?)
            .where((id) => id != null)
            .toSet()
            .toList();
        
        if (accountIds.isNotEmpty) {
          final accountsResponse = await _supabase
              .from('accounts')
              .select('id, name')
              .in_('id', accountIds);
          
          final accounts = (accountsResponse as List).cast<Map<String, dynamic>>();
          orgsWithoutDelivery.addAll(
            accounts.map((a) => a['name'] as String? ?? 'Unknown').toList(),
          );
        }
      }

      debugPrint('📦 [OrderService] Found ${ordersWithoutDelivery.length} pending orders without delivery');
      debugPrint('📦 [OrderService] Orgs without delivery service: $orgsWithoutDelivery');

      return {
        'orders': ordersWithoutDelivery,
        'orgsWithoutDelivery': orgsWithoutDelivery,
        'hasDeliveryService': hasDeliveryService,
      };
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching pending orders status: $e');
      return {'orders': [], 'orgsWithoutDelivery': [], 'hasDeliveryService': true};
    }
  }
}
