import 'package:flutter/material.dart';
import 'product.dart';

/// Represents a single item in the shopping cart
class CartItem {
  final Product product;
  int quantity;
  final String? categoryName;
  final Color? categoryColor;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.categoryName,
    this.categoryColor,
  });

  /// Total price for this cart item (price × quantity)
  double? get totalPriceLbp => product.priceLbp != null ? product.priceLbp! * quantity : null;
  double? get totalPriceUsd => product.priceUsd != null ? product.priceUsd! * quantity : null;

  /// Formatted total price string
  String get formattedTotalPrice {
    if (totalPriceLbp != null && totalPriceUsd != null) {
      return '${totalPriceLbp!.toStringAsFixed(0)} LBP / \$${totalPriceUsd!.toStringAsFixed(2)}';
    } else if (totalPriceLbp != null) {
      return '${totalPriceLbp!.toStringAsFixed(0)} LBP';
    } else if (totalPriceUsd != null) {
      return '\$${totalPriceUsd!.toStringAsFixed(2)}';
    } else {
      return 'Price not set';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'categoryName': categoryName,
      'categoryColor': categoryColor?.value,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      categoryName: json['categoryName'] as String?,
      categoryColor: json['categoryColor'] != null 
          ? Color(json['categoryColor'] as int)
          : null,
    );
  }
}
