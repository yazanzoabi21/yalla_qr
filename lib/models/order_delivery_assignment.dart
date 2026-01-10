/// Represents a delivery assignment for an order
class OrderDeliveryAssignment {
  final String id;
  final String orderId;
  final String deliveryAccountId;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? deliveryNotes; // Notes from delivery driver to ORG
  final bool? deliveryNotesUnread; // Whether ORG has read the note
  
  // Optional joined data
  final String? deliveryAccountName;
  final String? deliveryAccountPhone;

  OrderDeliveryAssignment({
    required this.id,
    required this.orderId,
    required this.deliveryAccountId,
    required this.assignedAt,
    this.completedAt,
    this.deliveryNotes,
    this.deliveryNotesUnread,
    this.deliveryAccountName,
    this.deliveryAccountPhone,
  });

  factory OrderDeliveryAssignment.fromJson(Map<String, dynamic> json) {
    // Handle nested account data if present
    String? deliveryName;
    String? deliveryPhone;
    
    if (json['delivery_account'] != null) {
      final account = json['delivery_account'] as Map<String, dynamic>;
      deliveryName = account['name'] as String?;
      deliveryPhone = account['phone'] as String?;
    }
    
    // Safely parse required fields with fallbacks
    final id = json['id'] as String? ?? '';
    final orderId = json['order_id'] as String? ?? '';
    final deliveryAccountId = json['delivery_account_id'] as String? ?? '';
    final assignedAtStr = json['assigned_at'] as String?;
    
    return OrderDeliveryAssignment(
      id: id,
      orderId: orderId,
      deliveryAccountId: deliveryAccountId,
      assignedAt: assignedAtStr != null 
          ? DateTime.parse(assignedAtStr)
          : DateTime.now(),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      deliveryNotes: json['delivery_notes'] as String?,
      deliveryNotesUnread: json['delivery_notes_unread'] as bool?,
      deliveryAccountName: deliveryName,
      deliveryAccountPhone: deliveryPhone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'delivery_account_id': deliveryAccountId,
      'assigned_at': assignedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'delivery_notes': deliveryNotes,
      'delivery_notes_unread': deliveryNotesUnread,
    };
  }

  /// Check if this assignment is completed
  bool get isCompleted => completedAt != null;
}
