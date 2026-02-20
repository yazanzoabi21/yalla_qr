class Account {
  final String id;
  final String? ownerId;
  final String name;
  final String? email;
  final String? phone;
  final String? description;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String role;
  
  // Optional: QR code associated with this account
  final String? qrCode;
  
  // Zone and City
  final String? zoneId;
  final String? cityId;
  
  // Optional: Categories associated with this account (loaded via join)
  final List<String>? categoryIds;

  Account({
    required this.id,
    this.ownerId,
    required this.name,
    this.email,
    this.phone,
    this.description,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.role = 'USER',
    this.qrCode,
    this.categoryIds,
    this.zoneId,
    this.cityId,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String?,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      locationAddress: json['location_address'] as String?,
      locationLat: json['location_lat'] != null
          ? (json['location_lat'] as num).toDouble()
          : null,
      locationLng: json['location_lng'] != null
          ? (json['location_lng'] as num).toDouble()
          : null,
      logoUrl: json['logo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      role: json['role'] as String? ?? 'USER',
      qrCode: json['qr_code'] as String?,
      categoryIds: json['category_ids'] != null
          ? List<String>.from(json['category_ids'])
          : null,
      zoneId: json['zone_id'] as String?,
      cityId: json['city_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'email': email,
      'phone': phone,
      'description': description,
      'location_address': locationAddress,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'logo_url': logoUrl,
      'zone_id': zoneId,
      'city_id': cityId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'role': role,
      'qr_code': qrCode,
      'category_ids': categoryIds,
    };
  }

  Account copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? email,
    String? phone,
    String? description,
    String? locationAddress,
    double? locationLat,
    double? locationLng,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? role,
    String? qrCode,
    List<String>? categoryIds,
    String? zoneId,
    String? cityId,
  }) {
    return Account(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      locationAddress: locationAddress ?? this.locationAddress,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      qrCode: qrCode ?? this.qrCode,
      categoryIds: categoryIds ?? this.categoryIds,
      zoneId: zoneId ?? this.zoneId,
      cityId: cityId ?? this.cityId,
    );
  }
}
