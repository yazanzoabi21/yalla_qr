class DeliveryLocationHistory {
  final String id;
  final String assignmentId;
  final double latitude;
  final double longitude;
  final double? speed;
  final DateTime recordedAt;

  DeliveryLocationHistory({
    required this.id,
    required this.assignmentId,
    required this.latitude,
    required this.longitude,
    this.speed,
    required this.recordedAt,
  });

  factory DeliveryLocationHistory.fromJson(Map<String, dynamic> json) {
    return DeliveryLocationHistory(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }

  DeliveryLocationHistory copyWith({
    String? id,
    String? assignmentId,
    double? latitude,
    double? longitude,
    double? speed,
    DateTime? recordedAt,
  }) {
    return DeliveryLocationHistory(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
