import 'package:flutter/material.dart';
import 'product.dart';
import 'category.dart';
import 'sub_category.dart';

/// Enum for different types of search results
enum SearchResultType {
  product,
  category,
  subCategory,
}

/// Unified search result model that can represent different types of results
class SearchResult {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final SearchResultType type;
  final dynamic data; // Can be Product, Category, or SubCategory
  final double relevanceScore;

  SearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    required this.type,
    required this.data,
    this.relevanceScore = 1.0,
  });

  /// Create SearchResult from Product
  factory SearchResult.fromProduct(Product product, {double relevanceScore = 1.0}) {
    return SearchResult(
      id: product.id,
      title: product.name,
      subtitle: product.formattedPrice,
      description: product.description,
      type: SearchResultType.product,
      data: product,
      relevanceScore: relevanceScore,
    );
  }

  /// Create SearchResult from Category
  factory SearchResult.fromCategory(Category category, {double relevanceScore = 1.0}) {
    return SearchResult(
      id: category.id,
      title: category.name,
      subtitle: 'Category',
      description: category.description,
      type: SearchResultType.category,
      data: category,
      relevanceScore: relevanceScore,
    );
  }

  /// Create SearchResult from SubCategory
  factory SearchResult.fromSubCategory(SubCategory subCategory, {double relevanceScore = 1.0}) {
    return SearchResult(
      id: subCategory.id.toString(),
      title: subCategory.name ?? 'Unnamed',
      subtitle: 'Sub-Category',
      description: subCategory.description,
      type: SearchResultType.subCategory,
      data: subCategory,
      relevanceScore: relevanceScore,
    );
  }

  /// Get icon for the search result type
  IconData get icon {
    switch (type) {
      case SearchResultType.product:
        return Icons.shopping_bag;
      case SearchResultType.category:
        return Icons.category;
      case SearchResultType.subCategory:
        final subCat = data as SubCategory;
        return subCat.icon;
    }
  }

  /// Get color for the search result type
  Color get color {
    switch (type) {
      case SearchResultType.product:
        return Colors.blue;
      case SearchResultType.category:
        final cat = data as Category;
        return cat.color;
      case SearchResultType.subCategory:
        final subCat = data as SubCategory;
        return subCat.color;
    }
  }

  /// Get type label for display
  String get typeLabel {
    switch (type) {
      case SearchResultType.product:
        return 'Product';
      case SearchResultType.category:
        return 'Category';
      case SearchResultType.subCategory:
        return 'Sub-Category';
    }
  }
}
