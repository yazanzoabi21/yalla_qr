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
        debugPrint('⚠️ [ProductService] No authenticated user found');
        return null;
      }

      debugPrint('🔍 [ProductService] Looking for account with owner_id: ${user.id}');
      if (categoryId != null) {
        debugPrint('   📁 Filtering by category_id: $categoryId');
      }

      // Get all accounts for the user
      final allAccounts = await _supabase
          .from('accounts')
          .select('id, name, owner_id, role')
          .eq('owner_id', user.id);
      
      if (allAccounts.isEmpty) {
        debugPrint('❌ [ProductService] No accounts found for user: ${user.id}');
        return null;
      }

      debugPrint('📊 [ProductService] User has ${allAccounts.length} total accounts:');
      for (var acc in allAccounts) {
        debugPrint('   - ${acc['name']} (role: ${acc['role']})');
      }

      // Strategy for finding the right account:
      // 1. If categoryId is specified, look for account with that category in account_categories
      // 2. If no match, fall back to ORG account
      // 3. If no ORG account, use any available account
      
      dynamic selectedAccount;
      
      if (categoryId != null) {
        // Try to find account that has access to this category via account_categories
        for (var acc in allAccounts) {
          final hasCategory = await _supabase
              .from('account_categories')
              .select('id')
              .eq('account_id', acc['id'])
              .eq('category_id', categoryId)
              .maybeSingle();
          
          if (hasCategory != null) {
            selectedAccount = acc;
            debugPrint('✅ [ProductService] Found account with access to category: ${selectedAccount['name']}');
            break;
          }
        }
        
        if (selectedAccount == null) {
          debugPrint('⚠️ [ProductService] No account found with access to category_id: $categoryId');
        }
      }
      
      // If no account found yet, try to find ORG account
      if (selectedAccount == null) {
        try {
          selectedAccount = allAccounts.firstWhere(
            (acc) => acc['role'] == 'ORG'
          );
          debugPrint('✅ [ProductService] Using ORG account: ${selectedAccount['name']}');
        } catch (e) {
          debugPrint('⚠️ [ProductService] No ORG account found');
        }
      }
      
      // If still no account, use the first available one
      if (selectedAccount == null) {
        selectedAccount = allAccounts.first;
        debugPrint('✅ [ProductService] Using first available account: ${selectedAccount['name']}');
      }

      final accountId = selectedAccount['id'] as String;
      return accountId;
    } catch (e) {
      debugPrint('❌ [ProductService] Error getting account ID: $e');
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
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id, account_id')
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

  /// Get products by category ID
  static Future<List<Product>> getProductsByCategory(
    String categoryId,
  ) async {
    try {
      debugPrint('🔍 Fetching products for category: $categoryId');
      
      final accountId = await _getCurrentAccountId(categoryId: categoryId);
      if (accountId == null) {
        debugPrint('⚠️ No account context; returning empty products list');
        return [];
      }

      final response = await _supabase
          .from('products')
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id, account_id')
          .eq('category_id', categoryId)
          .eq('account_id', accountId)
          .order('name', ascending: true);

      debugPrint('Fetched ${response.length} products for category $categoryId');
      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      // Debug log the products we're getting
      for (var product in products) {
        debugPrint('   - ${product.name}: ${product.formattedPrice}, stock: ${product.stockStatus}');
      }

      return products;
    } catch (e) {
      debugPrint('Failed to fetch products for category $categoryId: $e');
      throw Exception('Failed to fetch products for category $categoryId: $e');
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
    required String categoryId,
    String? accountId,
  }) async {
    try {
      debugPrint('🔄 Creating new product: $name for category: $categoryId');
      debugPrint('📝 Product data: name=$name, category_id=$categoryId, price_lbp=$priceLbp, price_usd=$priceUsd');
      
      // Get current account ID if not provided
      final currentAccountId = accountId ?? await _getCurrentAccountId(categoryId: categoryId);
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
            'quantity': inStock ? 1 : 0,
            'category_id': categoryId,
            'account_id': currentAccountId,
          })
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id, account_id')
          .single();

      debugPrint('Product created successfully with ID: ${response['id']}');
      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to create product: $e');
      throw Exception('Failed to create product: $e');
    }
  }

  /// Update product quantity (stock)
  static Future<Product> updateProductQuantity({
    required String productId,
    required int quantity,
  }) async {
    try {
      debugPrint('📦 Updating product quantity: $productId to $quantity');
      
      final response = await _supabase
          .from('products')
          .update({
            'quantity': quantity,
            'in_stock': quantity > 0,
          })
          .eq('id', productId)
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id')
          .single();

      debugPrint('✅ Product quantity updated successfully');
      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Failed to update product quantity: $e');
      throw Exception('Failed to update product quantity: $e');
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
    String? categoryId,
    int? quantity,
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
      if (categoryId != null) updateData['category_id'] = categoryId;
      if (quantity != null) {
        updateData['quantity'] = quantity;
        updateData['in_stock'] = quantity > 0;
      }

      final response = await _supabase
          .from('products')
          .update(updateData)
          .eq('id', productId)
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id')
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
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, category_id')
          .single();

      debugPrint('Product stock status toggled to: $newStock');
      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to toggle product stock: $e');
      throw Exception('Failed to toggle product stock: $e');
    }
  }

  /// Search products by name or description
  static Future<List<Product>> searchProducts(String query, {String? categoryId}) async {
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
          .select('id, account_id, name, description, price_lbp, price_usd, image_url, in_stock, created_at, category_id')
          .eq('account_id', accountId);
      
      if (categoryId != null) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
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

  /// Get products by account ID and category (for viewing other organizations' products)
  static Future<List<Product>> getProductsByAccountAndCategory(
    String accountId,
    String categoryId,
  ) async {
    try {
      debugPrint('🔍 Fetching products for account: $accountId, category: $categoryId');
      
      final response = await _supabase
          .from('products')
          .select('id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id, account_id')
          .eq('account_id', accountId)
          .eq('category_id', categoryId)
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
}
