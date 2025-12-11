import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';

/// Service for managing orders
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create an order from a cart
  Future<Order?> createOrderFromCart(Cart cart) async {
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
      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'account_id': cart.organizationId,
            'customer_id': user.id,
            'total_amount': totalAmount,
            'currency_code': currencyCode,
            'status': 'PENDING',
          })
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
  Future<List<Order>> createOrdersFromCarts(List<Cart> carts) async {
    final orders = <Order>[];

    for (var cart in carts) {
      if (cart.items.isNotEmpty) {
        final order = await createOrderFromCart(cart);
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
}
