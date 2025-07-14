import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

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

  // Helper method to get color based on category name
  Color get color {
    switch (name.toLowerCase()) {
      case 'meals':
        return const Color(0xFFFF5722); // Deep Orange
      case 'gym':
        return const Color(0xFF009688); // Teal
      default:
        return const Color(0xFF3F51B5); // Indigo
    }
  }
}
