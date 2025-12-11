/// Represents an order in the system
class Order {
  final String id;
  final String accountId; // Organization ID
  final String customerId; // User ID from auth.users
  final double totalAmount;
  final String currencyCode; // 'LBP' or 'USD'
  final String
  status; // 'PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem>? items; // Optional, populated when fetching with items

  Order({
    required this.id,
    required this.accountId,
    required this.customerId,
    required this.totalAmount,
    required this.currencyCode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      customerId: json['customer_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: json['order_items'] != null
          ? (json['order_items'] as List)
                .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'currency_code': currencyCode,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get formatted total amount
  String get formattedTotalAmount {
    if (currencyCode == 'LBP') {
      return '${_formatNumber(totalAmount)} LBP';
    } else {
      return '\$${totalAmount.toStringAsFixed(2)}';
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

  /// Get status color
  static String getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PREPARING':
        return 'Preparing';
      case 'READY':
        return 'Ready';
      case 'DELIVERED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// Represents an item in an order
class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    };
  }

  /// Get total price for this item (price * quantity)
  double get totalPrice => price * quantity;
}
