import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final String? parentId; // New field for hierarchical categories
  final int? iconCode; // IconData codePoint from database
  final String? colorValue; // Hex color string from database

  Category({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.parentId,
    this.iconCode,
    this.colorValue,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      parentId: json['parent_id'] as String?,
      iconCode: json['icon_code'] as int?,
      colorValue: json['color_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'parent_id': parentId,
      'icon_code': iconCode,
      'color_value': colorValue,
    };
  }

  // Check if this is a parent category (no parent_id)
  bool get isParent => parentId == null;

  // Check if this is a child category (has parent_id)
  bool get isChild => parentId != null;

  // Helper method to get image path based on category name
  String? get imagePath {
    switch (name.toLowerCase()) {
      case 'meals':
        return 'assets/images/Meals.png';
      case 'gym':
        return 'assets/images/GYM.png';
      default:
        return null;
    }
  }

  // Helper method to get color from database or fallback to default
  Color get color {
    if (colorValue != null) {
      try {
        // Parse hex string like '0xFFFF5722' to Color
        final hexString = colorValue!.replaceAll('0x', '');
        final intValue = int.parse(hexString, radix: 16);
        return Color(intValue);
      } catch (e) {
        // Fallback if parsing fails
        return const Color(0xFF3F51B5); // Indigo
      }
    }
    
    // Fallback to hardcoded colors for backward compatibility
    switch (name.toLowerCase()) {
      case 'meals':
        return const Color(0xFFFF5722); // Deep Orange
      case 'gym':
        return const Color(0xFF009688); // Teal
      default:
        return const Color(0xFF3F51B5); // Indigo
    }
  }

  // Helper method to get icon from database or fallback to default
  IconData get icon {
    if (iconCode != null) {
      try {
        return IconData(iconCode!, fontFamily: 'MaterialIcons');
      } catch (e) {
        // Fallback if icon code is invalid
        return Icons.category;
      }
    }
    
    // Fallback to hardcoded icons for backward compatibility
    switch (name.toLowerCase()) {
      case 'meals':
        return Icons.restaurant;
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.category;
    }
  }
}
