class DeliveryLiveLocation {
  final String id;
  final String assignmentId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final DateTime updatedAt;

  DeliveryLiveLocation({
    required this.id,
    required this.assignmentId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    required this.updatedAt,
  });

  factory DeliveryLiveLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLiveLocation(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'heading': heading,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  DeliveryLiveLocation copyWith({
    String? id,
    String? assignmentId,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    DateTime? updatedAt,
  }) {
    return DeliveryLiveLocation(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
