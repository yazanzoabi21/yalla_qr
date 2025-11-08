class ScanLog {
  final String id;
  final String? qrCodeId;
  final DateTime scannedAt;
  final double? locationLat;
  final double? locationLng;
  final Map<String, dynamic>? deviceInfo;

  ScanLog({
    required this.id,
    this.qrCodeId,
    required this.scannedAt,
    this.locationLat,
    this.locationLng,
    this.deviceInfo,
  });

  factory ScanLog.fromJson(Map<String, dynamic> json) {
    return ScanLog(
      id: json['id'] as String,
      qrCodeId: json['qr_code_id'] as String?,
      scannedAt: DateTime.parse(json['scanned_at'] as String),
      locationLat: json['location_lat'] != null
          ? (json['location_lat'] as num).toDouble()
          : null,
      locationLng: json['location_lng'] != null
          ? (json['location_lng'] as num).toDouble()
          : null,
      deviceInfo: json['device_info'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'qr_code_id': qrCodeId,
      'scanned_at': scannedAt.toIso8601String(),
      'location_lat': locationLat,
      'location_lng': locationLng,
      'device_info': deviceInfo,
    };
  }
}
