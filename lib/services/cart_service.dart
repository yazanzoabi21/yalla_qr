import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

/// Service to manage shopping cart state across the app
/// Maintains separate carts for each organization (identified by accountId)
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // Map of organizationId to Cart
  final Map<String, Cart> _carts = {};

  static const String _storageKey = 'shopping_carts';

  /// Initialize and load carts from persistent storage
  Future<void> initialize() async {
    await _loadCarts();
  }

  /// Get cart for a specific organization
  Cart getCart(String organizationId, String organizationName) {
    if (!_carts.containsKey(organizationId)) {
      _carts[organizationId] = Cart(
        organizationId: organizationId,
        organizationName: organizationName,
      );
    }
    return _carts[organizationId]!;
  }

  /// Add product to cart with category information
  bool addToCart(
    String organizationId, 
    String organizationName, 
    Product product, 
    {int quantity = 1,
    String? categoryName,
    Color? categoryColor}
  ) {
    final cart = getCart(organizationId, organizationName);

    final existingItem = cart.getCartItem(product.id);
    final maxAvailable = product.quantity; // 0 means unknown/out of stock handled via inStock

    if (maxAvailable != null && maxAvailable > 0) {
      final currentQty = existingItem?.quantity ?? 0;
      if (currentQty >= maxAvailable) {
        // cannot add more
        return false;
      }

      final canAdd = (maxAvailable - currentQty);
      final toAdd = quantity <= canAdd ? quantity : canAdd;

      if (existingItem != null) {
        existingItem.quantity += toAdd;
      } else {
        cart.items.add(CartItem(
          product: product,
          quantity: toAdd,
          categoryName: categoryName,
          categoryColor: categoryColor,
        ));
      }
    } else {
      // No stock limit info, add normally
      if (existingItem != null) {
        existingItem.quantity += quantity;
      } else {
        cart.items.add(CartItem(
          product: product,
          quantity: quantity,
          categoryName: categoryName,
          categoryColor: categoryColor,
        ));
      }
    }

    _saveCarts();
    notifyListeners();
    debugPrint('✅ Added ${product.name} to cart for org: $organizationName');
    return true;
  }

  /// Remove product from cart completely
  void removeFromCart(String organizationId, Product product) {
    final cart = _carts[organizationId];
    if (cart != null) {
      cart.items.removeWhere((item) => item.product.id == product.id);
      _saveCarts();
      notifyListeners();
      debugPrint('🗑️ Removed ${product.name} from cart');
    }
  }

  /// Update quantity of a product in cart
  void updateQuantity(String organizationId, String productId, int quantity) {
    final cart = _carts[organizationId];
    if (cart != null) {
      final item = cart.getCartItem(productId);
      if (item != null) {
        if (quantity <= 0) {
          // Remove item if quantity is 0 or negative
          cart.items.removeWhere((item) => item.product.id == productId);
        } else {
          item.quantity = quantity;
        }
        _saveCarts();
        notifyListeners();
      }
    }
  }

  /// Increase quantity by 1
  bool incrementQuantity(String organizationId, String productId) {
    final cart = _carts[organizationId];
    if (cart != null) {
      final item = cart.getCartItem(productId);
      if (item != null) {
        final max = item.product.quantity;
        if (max != null && max > 0 && item.quantity >= max) {
          return false;
        }
        item.quantity++;
        _saveCarts();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Decrease quantity by 1
  void decrementQuantity(String organizationId, String productId) {
    final cart = _carts[organizationId];
    if (cart != null) {
      final item = cart.getCartItem(productId);
      if (item != null) {
        if (item.quantity > 1) {
          item.quantity--;
        } else {
          // Remove if quantity would be 0
          cart.items.removeWhere((item) => item.product.id == productId);
        }
        _saveCarts();
        notifyListeners();
      }
    }
  }

  /// Clear all items from a specific cart
  void clearCart(String organizationId) {
    final cart = _carts[organizationId];
    if (cart != null) {
      cart.items.clear();
      _saveCarts();
      notifyListeners();
      debugPrint('🧹 Cleared cart for org: ${cart.organizationName}');
    }
  }

  /// Check if product is in cart
  bool isInCart(String organizationId, String productId) {
    final cart = _carts[organizationId];
    return cart?.containsProduct(productId) ?? false;
  }

  /// Get quantity of product in cart
  int getProductQuantity(String organizationId, String productId) {
    final cart = _carts[organizationId];
    return cart?.getProductQuantity(productId) ?? 0;
  }

  /// Get total items count for a specific organization
  int getTotalItems(String organizationId) {
    final cart = _carts[organizationId];
    return cart?.totalItems ?? 0;
  }

  /// Get total items count across ALL organizations
  int getTotalItemsAllOrganizations() {
    int total = 0;
    for (var cart in _carts.values) {
      total += cart.totalItems;
    }
    return total;
  }

  /// Get all carts with items
  List<Cart> getAllCartsWithItems() {
    return _carts.values.where((cart) => cart.items.isNotEmpty).toList();
  }

  /// Save carts to persistent storage
  Future<void> _saveCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartsJson = _carts.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_storageKey, jsonEncode(cartsJson));
    } catch (e) {
      debugPrint('❌ Error saving carts: $e');
    }
  }

  /// Load carts from persistent storage
  Future<void> _loadCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartsString = prefs.getString(_storageKey);
      
      if (cartsString != null) {
        final cartsJson = jsonDecode(cartsString) as Map<String, dynamic>;
        _carts.clear();
        
        cartsJson.forEach((key, value) {
          _carts[key] = Cart.fromJson(value as Map<String, dynamic>);
        });
        
        debugPrint('📦 Loaded ${_carts.length} carts from storage');
      }
    } catch (e) {
      debugPrint('❌ Error loading carts: $e');
    }
  }

  /// Get all carts (for debugging or admin purposes)
  Map<String, Cart> getAllCarts() => Map.unmodifiable(_carts);

  /// Clear all items from all carts
  void clearAllCarts() {
    for (var cart in _carts.values) {
      cart.items.clear();
    }
    _saveCarts();
    notifyListeners();
    debugPrint('🧹 Cleared all carts');
  }
}
