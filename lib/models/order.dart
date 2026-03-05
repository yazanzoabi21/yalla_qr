/// Represents an order in the system
class Order {
  final String id;
  final String accountId; // Organization ID
  final String customerId; // User ID from auth.users
  final double totalAmount;
  final String currencyCode; // 'LBP' or 'USD'
  final double?
  totalAmountUsd; // Optional stored USD equivalent recorded at order creation
  final String
  status; // 'PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem>? items; // Optional, populated when fetching with items
  final String? contactName;
  final String? deliveryAddress;
  final String? deliveryPhone;
  final String? notes;

  // New optional delivery fields (may come from DB or be attached at runtime)
  final String? deliveryCityId; // explicit delivery_city_id on order
  final String? cityId; // customer's saved city_id
  final double? deliveryFeeLbp; // delivery fee in LBP (if available)
  final double? deliveryFeeUsd; // delivery fee in USD (if available)

  Order({
    required this.id,
    required this.accountId,
    required this.customerId,
    required this.totalAmount,
    required this.currencyCode,
    this.totalAmountUsd,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    this.contactName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.notes,
    this.deliveryCityId,
    this.cityId,
    this.deliveryFeeLbp,
    this.deliveryFeeUsd,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      customerId: json['customer_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      totalAmountUsd: json['total_amount_usd'] != null
          ? (json['total_amount_usd'] as num).toDouble()
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: json['order_items'] != null
          ? (json['order_items'] as List)
                .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
                .toList()
          : null,
      contactName: json['contact_name'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryPhone: json['delivery_phone'] as String?,
      notes: json['notes'] as String?,

      // optional delivery fields if provided by the server/service
      deliveryCityId: json['delivery_city_id'] as String?,
      cityId: json['city_id'] as String?,
      deliveryFeeLbp: json['delivery_fee_lbp'] != null
          ? (json['delivery_fee_lbp'] as num).toDouble()
          : null,
      deliveryFeeUsd: json['delivery_fee_usd'] != null
          ? (json['delivery_fee_usd'] as num).toDouble()
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
      if (totalAmountUsd != null) 'total_amount_usd': totalAmountUsd,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (contactName != null) 'contact_name': contactName,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryPhone != null) 'delivery_phone': deliveryPhone,
      if (notes != null) 'notes': notes,
      if (deliveryCityId != null) 'delivery_city_id': deliveryCityId,
      if (cityId != null) 'city_id': cityId,
      if (deliveryFeeLbp != null) 'delivery_fee_lbp': deliveryFeeLbp,
      if (deliveryFeeUsd != null) 'delivery_fee_usd': deliveryFeeUsd,
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
        return 'Preparing'; // PENDING is now displayed as Preparing
      case 'PENDING_DELIVERY_CONFIRMATION':
        return 'Pending Confirmation';
      case 'ACCEPTED_BY_DELIVERY':
        return 'Accepted by Delivery';
      case 'CONFIRMED':
        return 'Ready'; // CONFIRMED is now displayed as Ready
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
  final Map<String, dynamic>? product; // Product data when joined

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      product: json['products'] as Map<String, dynamic>?,
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
