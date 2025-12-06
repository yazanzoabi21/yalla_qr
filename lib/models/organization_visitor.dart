class OrganizationVisitor {
  final String id;
  final String userId;
  final String orgId;
  final String qrCodeId;
  final DateTime firstScannedAt;
  final DateTime lastScannedAt;

  OrganizationVisitor({
    required this.id,
    required this.userId,
    required this.orgId,
    required this.qrCodeId,
    required this.firstScannedAt,
    required this.lastScannedAt,
  });

  factory OrganizationVisitor.fromJson(Map<String, dynamic> json) {
    return OrganizationVisitor(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orgId: json['org_id'] as String,
      qrCodeId: json['qr_code_id'] as String,
      firstScannedAt: DateTime.parse(json['first_scanned_at'] as String),
      lastScannedAt: DateTime.parse(json['last_scanned_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'org_id': orgId,
      'qr_code_id': qrCodeId,
      'first_scanned_at': firstScannedAt.toIso8601String(),
      'last_scanned_at': lastScannedAt.toIso8601String(),
    };
  }
}
