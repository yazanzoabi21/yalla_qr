class AccountCategory {
  final String id;
  final String accountId;
  final String categoryId;
  final bool isHidden;
  final DateTime createdAt;

  AccountCategory({
    required this.id,
    required this.accountId,
    required this.categoryId,
    this.isHidden = false,
    required this.createdAt,
  });

  factory AccountCategory.fromJson(Map<String, dynamic> json) {
    return AccountCategory(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      categoryId: json['category_id'] as String,
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'is_hidden': isHidden,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AccountCategory copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    bool? isHidden,
    DateTime? createdAt,
  }) {
    return AccountCategory(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
