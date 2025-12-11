import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/search_result.dart';
import '../models/product.dart';
import 'product_service.dart';
import 'category_service.dart';

class SearchService {
  /// Perform a global search across all entities
  static Future<List<SearchResult>> globalSearch(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    debugPrint('🔍 Starting global search for: "$query"');
    
    try {
      // Search in parallel for better performance
      final results = await Future.wait([
        _searchProducts(query),
        _searchCategories(query),
      ]);

      // Flatten the results
      final allResults = <SearchResult>[];
      for (var resultList in results) {
        allResults.addAll(resultList);
      }

      // Sort by relevance score (higher first)
      allResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      debugPrint('✅ Found ${allResults.length} total results');
      debugPrint('   - Products: ${results[0].length}');
      debugPrint('   - Categories: ${results[1].length}');

      return allResults;
    } catch (e) {
      debugPrint('❌ Error in global search: $e');
      rethrow;
    }
  }

  /// Search only categories (for home screen)
  static Future<List<SearchResult>> searchCategoriesOnly(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    debugPrint('🔍 Starting category-only search for: "$query"');
    
    try {
      final results = await _searchCategories(query);
      debugPrint('✅ Found ${results.length} categories');
      return results;
    } catch (e) {
      debugPrint('❌ Error in category search: $e');
      rethrow;
    }
  }

  /// Search products within a specific organization (for client pages)
  static Future<List<SearchResult>> searchOrganizationProducts({
    required String query,
    required String organizationAccountId,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    debugPrint('🔍 Searching organization products for: "$query" in org: $organizationAccountId');
    
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('account_id', organizationAccountId)
          .or('name.ilike.%$query%,description.ilike.%$query%');

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Found ${products.length} organization products');

      return products.map((product) {
        final score = _calculateRelevanceScore(
          query: query,
          title: product.name,
          description: product.description,
        );
        return SearchResult.fromProduct(product, relevanceScore: score);
      }).toList()
        ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    } catch (e) {
      debugPrint('❌ Error searching organization products: $e');
      rethrow;
    }
  }

  /// Search products with relevance scoring
  static Future<List<SearchResult>> _searchProducts(String query) async {
    try {
      final products = await ProductService.searchProducts(query);
      
      return products.map((product) {
        final score = _calculateRelevanceScore(
          query: query,
          title: product.name,
          description: product.description,
        );
        return SearchResult.fromProduct(product, relevanceScore: score);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Error searching products: $e');
      return [];
    }
  }

  /// Search categories with relevance scoring
  static Future<List<SearchResult>> _searchCategories(String query) async {
    try {
      final categories = await CategoryService.getCategories();
      
      // Filter categories that match the query
      final matchingCategories = categories.where((category) {
        return _matchesQuery(query, category.name) ||
               (category.description != null && _matchesQuery(query, category.description!));
      }).toList();

      return matchingCategories.map((category) {
        final score = _calculateRelevanceScore(
          query: query,
          title: category.name,
          description: category.description,
        );
        return SearchResult.fromCategory(category, relevanceScore: score);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Error searching categories: $e');
      return [];
    }
  }



  /// Check if a text matches the query (case-insensitive)
  static bool _matchesQuery(String query, String text) {
    final lowerQuery = query.toLowerCase().trim();
    final lowerText = text.toLowerCase().trim();
    
    // Check for exact match
    if (lowerText.contains(lowerQuery)) {
      return true;
    }
    
    // Check for word-by-word match
    final queryWords = lowerQuery.split(' ');
    for (var word in queryWords) {
      if (word.isNotEmpty && lowerText.contains(word)) {
        return true;
      }
    }
    
    // Check for fuzzy match (characters in order)
    return _fuzzyMatch(lowerQuery, lowerText);
  }

  /// Simple fuzzy matching - checks if all characters in query appear in text in order
  static bool _fuzzyMatch(String query, String text) {
    int textIndex = 0;
    
    for (int i = 0; i < query.length; i++) {
      final char = query[i];
      if (char == ' ') continue; // Skip spaces
      
      // Find the character in the remaining text
      bool found = false;
      for (int j = textIndex; j < text.length; j++) {
        if (text[j] == char) {
          textIndex = j + 1;
          found = true;
          break;
        }
      }
      
      if (!found) {
        return false;
      }
    }
    
    return true;
  }

  /// Calculate relevance score for a search result
  /// Score is between 0.0 and 2.0
  static double _calculateRelevanceScore({
    required String query,
    required String title,
    String? description,
  }) {
    final lowerQuery = query.toLowerCase().trim();
    final lowerTitle = title.toLowerCase().trim();
    final lowerDescription = description?.toLowerCase().trim() ?? '';

    double score = 0.0;

    // Exact match in title - highest score
    if (lowerTitle == lowerQuery) {
      score += 2.0;
    }
    // Title starts with query
    else if (lowerTitle.startsWith(lowerQuery)) {
      score += 1.5;
    }
    // Title contains query
    else if (lowerTitle.contains(lowerQuery)) {
      score += 1.2;
    }
    // Word match in title
    else {
      final queryWords = lowerQuery.split(' ');
      int wordMatches = 0;
      for (var word in queryWords) {
        if (word.isNotEmpty && lowerTitle.contains(word)) {
          wordMatches++;
        }
      }
      if (wordMatches > 0) {
        score += 0.8 * (wordMatches / queryWords.length);
      }
    }

    // Description matches add bonus points
    if (description != null && description.isNotEmpty) {
      if (lowerDescription.contains(lowerQuery)) {
        score += 0.3;
      } else {
        final queryWords = lowerQuery.split(' ');
        int wordMatches = 0;
        for (var word in queryWords) {
          if (word.isNotEmpty && lowerDescription.contains(word)) {
            wordMatches++;
          }
        }
        if (wordMatches > 0) {
          score += 0.2 * (wordMatches / queryWords.length);
        }
      }
    }

    // Ensure score is at least 0.1 if there's any match
    if (score == 0.0 && _fuzzyMatch(lowerQuery, lowerTitle)) {
      score = 0.1;
    }

    return score;
  }

  /// Search within a specific category (includes child categories and products)
  static Future<List<SearchResult>> searchInCategory({
    required String query,
    required String categoryId,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    debugPrint('🔍 Searching in category: $categoryId for: "$query"');

    try {
      // Get child categories for this category
      final childCategories = await CategoryService.getChildCategories(categoryId);
      
      final results = <SearchResult>[];

      // Search products in category and each child category
      final products = await ProductService.getProductsByCategory(categoryId);
      
      // Filter products that match the query
      final matchingProducts = products.where((product) {
        return _matchesQuery(query, product.name) ||
               (product.description != null && _matchesQuery(query, product.description!));
      }).toList();

      for (var product in matchingProducts) {
        final score = _calculateRelevanceScore(
          query: query,
          title: product.name,
          description: product.description,
        );
        results.add(SearchResult.fromProduct(product, relevanceScore: score));
      }

      // Also add matching child categories
      final matchingChildCategories = childCategories.where((category) {
        return _matchesQuery(query, category.name) ||
               (category.description != null && _matchesQuery(query, category.description!));
      }).toList();

      for (var category in matchingChildCategories) {
        final score = _calculateRelevanceScore(
          query: query,
          title: category.name,
          description: category.description,
        );
        results.add(SearchResult.fromCategory(category, relevanceScore: score));
      }

      // Sort by relevance
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      debugPrint('✅ Found ${results.length} results in category');
      return results;
    } catch (e) {
      debugPrint('❌ Error searching in category: $e');
      rethrow;
    }
  }
}
