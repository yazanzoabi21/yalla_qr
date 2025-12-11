import 'cart_item.dart';
import 'product.dart';

/// Represents a shopping cart for a specific organization
class Cart {
  final String organizationId;
  final String organizationName;
  final List<CartItem> items;

  Cart({
    required this.organizationId,
    required this.organizationName,
    List<CartItem>? items,
  }) : items = items ?? [];

  /// Total number of items in cart
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Total price in LBP
  double? get totalPriceLbp {
    double? total;
    for (var item in items) {
      if (item.totalPriceLbp != null) {
        total = (total ?? 0) + item.totalPriceLbp!;
      }
    }
    return total;
  }

  /// Total price in USD
  double? get totalPriceUsd {
    double? total;
    for (var item in items) {
      if (item.totalPriceUsd != null) {
        total = (total ?? 0) + item.totalPriceUsd!;
      }
    }
    return total;
  }

  /// Formatted total price string
  String get formattedTotalPrice {
    if (totalPriceLbp != null && totalPriceUsd != null) {
      return '${_formatNumber(totalPriceLbp!)} LBP / \$${totalPriceUsd!.toStringAsFixed(2)}';
    } else if (totalPriceLbp != null) {
      return '${_formatNumber(totalPriceLbp!)} LBP';
    } else if (totalPriceUsd != null) {
      return '\$${totalPriceUsd!.toStringAsFixed(2)}';
    } else {
      return '0';
    }
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

  /// Check if a product is in the cart
  bool containsProduct(String productId) {
    return items.any((item) => item.product.id == productId);
  }

  /// Get quantity of a specific product
  int getProductQuantity(String productId) {
    final item = items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => CartItem(product: Product(
        id: '',
        name: '',
        createdAt: DateTime.now(),
        inStock: false,
      ), quantity: 0),
    );
    return item.quantity;
  }

  /// Get cart item for a specific product
  CartItem? getCartItem(String productId) {
    try {
      return items.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'organizationName': organizationName,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      organizationId: json['organizationId'] as String,
      organizationName: json['organizationName'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
