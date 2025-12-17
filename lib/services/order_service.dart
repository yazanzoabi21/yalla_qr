import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/cart.dart';
// import '../models/cart_item.dart'; // not required here
import '../models/order_delivery_assignment.dart';

/// Service for managing orders
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
  Future<List<Map<String, dynamic>>> getDeliveryAccounts() async {
    try {
      final response = await _supabase
          .from('accounts')
          .select('id, name, phone, email')
          .eq('role', 'DELIVERY')
          .order('name');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ [OrderService] Error fetching delivery accounts: $e');
      return [];
    }
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

      // Then fetch those orders with their items
      final ordersResponse = await _supabase
          .from('orders')
          .select('*, order_items(*)')
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
            order_items(*),
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
              order_items(*),
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
}
