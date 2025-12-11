import 'package:flutter/material.dart';

class Product {
  final String id;
  final String? accountId;
  final String name;
  final String? description;
  final double? priceLbp;
  final double? priceUsd;
  final String? imageUrl;
  final bool inStock;
  final int quantity; // Available stock quantity
  final DateTime createdAt;
  final String? categoryId;

  Product({
    required this.id,
    this.accountId,
    required this.name,
    this.description,
    this.priceLbp,
    this.priceUsd,
    this.imageUrl,
    required this.inStock,
    this.quantity = 0,
    required this.createdAt,
    this.categoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    debugPrint('📝 Creating Product from JSON: ${json['name']}');
    
    return Product(
      id: json['id'] as String,
      accountId: json['account_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      priceLbp: json['price_lbp'] != null ? (json['price_lbp'] as num).toDouble() : null,
      priceUsd: json['price_usd'] != null ? (json['price_usd'] as num).toDouble() : null,
      imageUrl: json['image_url'] as String?,
      inStock: json['in_stock'] as bool? ?? true,
      quantity: json['quantity'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryId: json['category_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'name': name,
      'description': description,
      'price_lbp': priceLbp,
      'price_usd': priceUsd,
      'image_url': imageUrl,
      'in_stock': inStock,
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
      'category_id': categoryId,
    };
  }

  // Helper method for formatted price display
  String get formattedPrice {
    if (priceLbp != null && priceUsd != null) {
      return '${priceLbp!.toStringAsFixed(0)} LBP / \$${priceUsd!.toStringAsFixed(2)}';
    } else if (priceLbp != null) {
      return '${priceLbp!.toStringAsFixed(0)} LBP';
    } else if (priceUsd != null) {
      return '\$${priceUsd!.toStringAsFixed(2)}';
    } else {
      return 'Price not set';
    }
  }

  // Helper method for stock status - considers both inStock flag and quantity
  bool get isAvailable => inStock && quantity > 0;
  
  // Helper method for stock status text
  String get stockStatus => isAvailable ? 'In Stock' : 'Out of Stock';
  
  // Helper method for stock status color
  Color get stockColor => isAvailable ? Colors.green : Colors.red;
}
