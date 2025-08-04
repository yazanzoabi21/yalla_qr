import 'package:flutter/material.dart';

class SubCategory {
  final int id;
  final String? name;
  final String? description;
  final String? categoryId;
  final String? colorValue;
  final String? iconValue;
  final DateTime createdAt;

  SubCategory({
    required this.id,
    this.name,
    this.description,
    this.categoryId,
    this.colorValue,
    this.iconValue,
    required this.createdAt,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    debugPrint('📝 Creating SubCategory from JSON: ${json['name']}');
    debugPrint('   - icon_value: ${json['icon_value']}');
    debugPrint('   - color_value: ${json['color_value']}');
    
    return SubCategory(
      id: json['id'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      colorValue: json['color_value'] as String?,
      iconValue: json['icon_value'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'color_value': colorValue,
      'icon_value': iconValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper method to get color based on stored value or subcategory name
  Color get color {
    // If we have a stored color value, use it
    if (colorValue != null && colorValue!.isNotEmpty) {
      try {
        return Color(int.parse(colorValue!));
      } catch (e) {
        // Fall back to name-based color if parsing fails
      }
    }
    
    // Fall back to name-based colors
    switch (name?.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snacks':
        return Colors.purple;
      case 'desserts':
        return Colors.pink;
      case 'drinks':
        return Colors.cyan;
      case 'fish':
      case 'fishes':
        return Colors.teal;
      default:
        return Colors.deepOrange;
    }
  }

  // Helper method to get icon based on stored value or subcategory name
  IconData get icon {
  if (iconValue != null && iconValue!.isNotEmpty) {
    try {
      final cleaned = iconValue!.split('.').first; // Remove .0 if exists
      final codePoint = int.parse(cleaned);
      debugPrint("Parsed icon codePoint: $codePoint");
      return _getIconFromCodePoint(codePoint);
    } catch (e) {
      debugPrint("Failed to parse iconValue: $iconValue — $e");
    }
  }

  // Fallbacks based on name
  switch (name?.toLowerCase()) {
    case 'fish':
    case 'fishes':
      return Icons.set_meal;
    case 'chicken':
      return Icons.restaurant_menu;
    case 'meals':
      return Icons.rice_bowl;
    default:
      return Icons.restaurant;
  }
}

  // Helper method to convert codePoint to IconData
  IconData _getIconFromCodePoint(int codePoint) {
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }
}
