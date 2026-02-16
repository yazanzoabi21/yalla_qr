class OrgStatistics {
  final String id;
  final String accountId;
  final int totalQrCodes;
  final int totalScans;
  final int uniqueVisitors;
  final int totalProducts;
  final int productsInStock;
  final int productsOutOfStock;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double totalRevenueLbp;
  final double totalRevenueUsd;
  final int totalDeliveries;
  final int activeDeliveries;
  final int completedDeliveries;
  final int ordersToday;
  final int ordersThisWeek;
  final int ordersThisMonth;
  final int scansToday;
  final int scansThisWeek;
  final int scansThisMonth;
  final DateTime? lastUpdatedAt;
  final DateTime? createdAt;

  OrgStatistics({
    required this.id,
    required this.accountId,
    this.totalQrCodes = 0,
    this.totalScans = 0,
    this.uniqueVisitors = 0,
    this.totalProducts = 0,
    this.productsInStock = 0,
    this.productsOutOfStock = 0,
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.totalRevenueLbp = 0,
    this.totalRevenueUsd = 0,
    this.totalDeliveries = 0,
    this.activeDeliveries = 0,
    this.completedDeliveries = 0,
    this.ordersToday = 0,
    this.ordersThisWeek = 0,
    this.ordersThisMonth = 0,
    this.scansToday = 0,
    this.scansThisWeek = 0,
    this.scansThisMonth = 0,
    this.lastUpdatedAt,
    this.createdAt,
  });

  factory OrgStatistics.fromJson(Map<String, dynamic> json) {
    return OrgStatistics(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      totalQrCodes: json['total_qr_codes'] as int? ?? 0,
      totalScans: json['total_scans'] as int? ?? 0,
      uniqueVisitors: json['unique_visitors'] as int? ?? 0,
      totalProducts: json['total_products'] as int? ?? 0,
      productsInStock: json['products_in_stock'] as int? ?? 0,
      productsOutOfStock: json['products_out_of_stock'] as int? ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      pendingOrders: json['pending_orders'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? 0,
      cancelledOrders: json['cancelled_orders'] as int? ?? 0,
      totalRevenueLbp: (json['total_revenue_lbp'] is num)
          ? (json['total_revenue_lbp'] as num).toDouble()
          : 0.0,
      totalRevenueUsd: (json['total_revenue_usd'] is num)
          ? (json['total_revenue_usd'] as num).toDouble()
          : 0.0,
      totalDeliveries: json['total_deliveries'] as int? ?? 0,
      activeDeliveries: json['active_deliveries'] as int? ?? 0,
      completedDeliveries: json['completed_deliveries'] as int? ?? 0,
      ordersToday: json['orders_today'] as int? ?? 0,
      ordersThisWeek: json['orders_this_week'] as int? ?? 0,
      ordersThisMonth: json['orders_this_month'] as int? ?? 0,
      scansToday: json['scans_today'] as int? ?? 0,
      scansThisWeek: json['scans_this_week'] as int? ?? 0,
      scansThisMonth: json['scans_this_month'] as int? ?? 0,
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.parse(json['last_updated_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'total_qr_codes': totalQrCodes,
      'total_scans': totalScans,
      'unique_visitors': uniqueVisitors,
      'total_products': totalProducts,
      'products_in_stock': productsInStock,
      'products_out_of_stock': productsOutOfStock,
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'completed_orders': completedOrders,
      'cancelled_orders': cancelledOrders,
      'total_revenue_lbp': totalRevenueLbp,
      'total_revenue_usd': totalRevenueUsd,
      'total_deliveries': totalDeliveries,
      'active_deliveries': activeDeliveries,
      'completed_deliveries': completedDeliveries,
      'orders_today': ordersToday,
      'orders_this_week': ordersThisWeek,
      'orders_this_month': ordersThisMonth,
      'scans_today': scansToday,
      'scans_this_week': scansThisWeek,
      'scans_this_month': scansThisMonth,
      'last_updated_at': lastUpdatedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  OrgStatistics copyWith({
    String? id,
    String? accountId,
    int? totalQrCodes,
    int? totalScans,
    int? uniqueVisitors,
    int? totalProducts,
    int? productsInStock,
    int? productsOutOfStock,
    int? totalOrders,
    int? pendingOrders,
    int? completedOrders,
    int? cancelledOrders,
    double? totalRevenueLbp,
    double? totalRevenueUsd,
    int? totalDeliveries,
    int? activeDeliveries,
    int? completedDeliveries,
    int? ordersToday,
    int? ordersThisWeek,
    int? ordersThisMonth,
    int? scansToday,
    int? scansThisWeek,
    int? scansThisMonth,
    DateTime? lastUpdatedAt,
    DateTime? createdAt,
  }) {
    return OrgStatistics(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      totalQrCodes: totalQrCodes ?? this.totalQrCodes,
      totalScans: totalScans ?? this.totalScans,
      uniqueVisitors: uniqueVisitors ?? this.uniqueVisitors,
      totalProducts: totalProducts ?? this.totalProducts,
      productsInStock: productsInStock ?? this.productsInStock,
      productsOutOfStock: productsOutOfStock ?? this.productsOutOfStock,
      totalOrders: totalOrders ?? this.totalOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      totalRevenueLbp: totalRevenueLbp ?? this.totalRevenueLbp,
      totalRevenueUsd: totalRevenueUsd ?? this.totalRevenueUsd,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      activeDeliveries: activeDeliveries ?? this.activeDeliveries,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      ordersToday: ordersToday ?? this.ordersToday,
      ordersThisWeek: ordersThisWeek ?? this.ordersThisWeek,
      ordersThisMonth: ordersThisMonth ?? this.ordersThisMonth,
      scansToday: scansToday ?? this.scansToday,
      scansThisWeek: scansThisWeek ?? this.scansThisWeek,
      scansThisMonth: scansThisMonth ?? this.scansThisMonth,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
