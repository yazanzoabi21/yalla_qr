class QRCodeModel {
  final String id;
  final String? accountId;
  final String code;
  final int scanCount;
  final DateTime createdAt;

  QRCodeModel({
    required this.id,
    this.accountId,
    required this.code,
    required this.scanCount,
    required this.createdAt,
  });

  factory QRCodeModel.fromJson(Map<String, dynamic> json) {
    return QRCodeModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String?,
      code: json['code'] as String,
      scanCount: json['scan_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'code': code,
      'scan_count': scanCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  QRCodeModel copyWith({
    String? id,
    String? accountId,
    String? code,
    int? scanCount,
    DateTime? createdAt,
  }) {
    return QRCodeModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      code: code ?? this.code,
      scanCount: scanCount ?? this.scanCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
