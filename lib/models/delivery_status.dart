enum DeliveryStatusType {
  pending,
  accepted,
  enRoute,
  arriving,
  arrived,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case DeliveryStatusType.pending:
        return 'Pending';
      case DeliveryStatusType.accepted:
        return 'Accepted';
      case DeliveryStatusType.enRoute:
        return 'En Route';
      case DeliveryStatusType.arriving:
        return 'Arriving';
      case DeliveryStatusType.arrived:
        return 'Arrived';
      case DeliveryStatusType.completed:
        return 'Completed';
      case DeliveryStatusType.cancelled:
        return 'Cancelled';
    }
  }

  static DeliveryStatusType fromString(String status) {
    return DeliveryStatusType.values.firstWhere(
      (e) => e.name == status,
      orElse: () => DeliveryStatusType.pending,
    );
  }
}

class DeliveryStatus {
  final String id;
  final String assignmentId;
  final DeliveryStatusType status;
  final DateTime updatedAt;

  DeliveryStatus({
    required this.id,
    required this.assignmentId,
    required this.status,
    required this.updatedAt,
  });

  factory DeliveryStatus.fromJson(Map<String, dynamic> json) {
    return DeliveryStatus(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      status: DeliveryStatusType.fromString(json['status'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'status': status.name,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  DeliveryStatus copyWith({
    String? id,
    String? assignmentId,
    DeliveryStatusType? status,
    DateTime? updatedAt,
  }) {
    return DeliveryStatus(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
