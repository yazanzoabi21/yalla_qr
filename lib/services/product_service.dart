import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user's account ID
  static Future<String?> _getCurrentAccountId({String? categoryId}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user found');
        return null;
      }

      final query = _supabase
          .from('accounts')
          .select('id')
          .eq('owner_id', user.id);

      // If a category is specified, narrow to that account
      if (categoryId != null) {
        query.eq('category_id', categoryId);
      }

      final response = await query.maybeSingle();

      if (response != null) {
        final accountId = response['id'] as String;
        debugPrint('✅ Found account ID: $accountId for user: ${user.id}');
        return accountId;
      } else {
        debugPrint('⚠️ No account found for user: ${user.id}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting account ID: $e');
      return null;
    }
  }

  /// Fetch all products from the database
  static Future<List<Product>> getProducts() async {
    try {
      debugPrint('🔍 Fetching all products for current account...');

      final accountId = await _getCurrentAccountId();
      if (accountId == null) {
        debugPrint('⚠️ No account context; returning empty products list');
        return [];
      }

      final response = await _supabase
          .from('products')
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, sub_category, account_id')
          .eq('account_id', accountId)
          .order('name', ascending: true);

      debugPrint('Fetched ${response.length} products');
      return (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch products: $e');
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get products by sub-category ID
  static Future<List<Product>> getProductsBySubCategory(int subCategoryId) async {
    try {
      debugPrint('🔍 Fetching products for sub-category: $subCategoryId');
      final accountId = await _getCurrentAccountId();
      if (accountId == null) {
        debugPrint('⚠️ No account context; returning empty products list');
        return [];
      }

      final response = await _supabase
          .from('products')
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, sub_category, account_id')
          .eq('sub_category', subCategoryId)
          .eq('account_id', accountId)
          .order('name', ascending: true);

      debugPrint('Fetched ${response.length} products for sub-category $subCategoryId');
      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      // Debug log the products we're getting
      for (var product in products) {
        debugPrint('   - ${product.name}: ${product.formattedPrice}, stock: ${product.stockStatus}');
      }

      return products;
    } catch (e) {
      debugPrint('Failed to fetch products for sub-category $subCategoryId: $e');
      throw Exception('Failed to fetch products for sub-category $subCategoryId: $e');
    }
  }

  /// Create a new product
  static Future<Product> createProduct({
    required String name,
    String? description,
    double? priceLbp,
    double? priceUsd,
    String? imageUrl,
    bool inStock = true,
    required int subCategoryId,
    String? accountId,
  }) async {
    try {
      debugPrint('🔄 Creating new product: $name for sub-category: $subCategoryId');
      debugPrint('📝 Product data: name=$name, sub_category=$subCategoryId, price_lbp=$priceLbp, price_usd=$priceUsd');
      
      // Get current account ID if not provided
      final currentAccountId = accountId ?? await _getCurrentAccountId();
      debugPrint('📝 Using account ID: $currentAccountId');
      
      if (currentAccountId == null) {
        throw Exception('Unable to create product: No account found for current user. Please ensure you are logged in and have an account set up.');
      }
      
      final response = await _supabase
          .from('products')
          .insert({
            'name': name,
            'description': description,
            'price_lbp': priceLbp,
            'price_usd': priceUsd,
            'image_url': imageUrl,
            'in_stock': inStock,
            'sub_category': subCategoryId,
            'account_id': currentAccountId,
          })
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, sub_category, account_id')
          .single();

      debugPrint('Product created successfully with ID: ${response['id']}');
      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to create product: $e');
      throw Exception('Failed to create product: $e');
    }
  }

  /// Update an existing product
  static Future<Product> updateProduct({
    required String productId,
    String? name,
    String? description,
    double? priceLbp,
    double? priceUsd,
    String? imageUrl,
    bool? inStock,
    int? subCategoryId,
  }) async {
    try {
      debugPrint('🔄 Updating product: $productId');
      
      Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (priceLbp != null) updateData['price_lbp'] = priceLbp;
      if (priceUsd != null) updateData['price_usd'] = priceUsd;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (inStock != null) updateData['in_stock'] = inStock;
      if (subCategoryId != null) updateData['sub_category'] = subCategoryId;

      final response = await _supabase
          .from('products')
          .update(updateData)
          .eq('id', productId)
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, sub_category')
          .single();

      debugPrint('Product updated successfully');
      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to update product: $e');
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete a product
  static Future<void> deleteProduct(String productId) async {
    try {
      debugPrint('🔄 Deleting product: $productId');
      
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId);

      debugPrint('Product deleted successfully');
    } catch (e) {
      debugPrint('Failed to delete product: $e');
      throw Exception('Failed to delete product: $e');
    }
  }

  /// Toggle product stock status
  static Future<Product> toggleProductStock(String productId) async {
    try {
      debugPrint('🔄 Toggling stock status for product: $productId');
      
      // First get the current product to know its current stock status
      final currentResponse = await _supabase
          .from('products')
          .select('in_stock')
          .eq('id', productId)
          .single();
      
      final currentStock = currentResponse['in_stock'] as bool;
      final newStock = !currentStock;
      
      final response = await _supabase
          .from('products')
          .update({'in_stock': newStock})
          .eq('id', productId)
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, sub_category')
          .single();

      debugPrint('Product stock status toggled to: $newStock');
      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to toggle product stock: $e');
      throw Exception('Failed to toggle product stock: $e');
    }
  }

  /// Search products by name or description
  static Future<List<Product>> searchProducts(String query, {int? subCategoryId}) async {
    try {
      debugPrint('Searching products with query: "$query"');
      // Restrict to current account products
      final accountId = await _getCurrentAccountId();
      if (accountId == null) {
        debugPrint('⚠️ No account context; returning empty search results');
        return [];
      }

      var queryBuilder = _supabase
          .from('products')
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, sub_category')
          .eq('account_id', accountId);
      
      if (subCategoryId != null) {
        queryBuilder = queryBuilder.eq('sub_category', subCategoryId);
      }
      
      final response = await queryBuilder
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .order('name', ascending: true);

      debugPrint('Found ${response.length} products matching "$query"');
      return (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to search products: $e');
      throw Exception('Failed to search products: $e');
    }
  }
}
