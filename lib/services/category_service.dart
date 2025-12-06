import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user's ORG account ID
  static Future<String?> _getCurrentAccountId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [CategoryService] No authenticated user found');
        return null;
      }

      debugPrint('🔍 [CategoryService] Looking for ORG account with owner_id: ${user.id}');

      // Get ORG account for the user
      final orgAccount = await _supabase
          .from('accounts')
          .select('id, name, role')
          .eq('owner_id', user.id)
          .eq('role', 'ORG')
          .maybeSingle();

      if (orgAccount == null) {
        debugPrint('❌ [CategoryService] No ORG account found for user: ${user.id}');
        return null;
      }

      debugPrint('✅ [CategoryService] Found ORG account: ${orgAccount['name']} (${orgAccount['id']})');
      return orgAccount['id'] as String;
    } catch (e) {
      debugPrint('❌ [CategoryService] Error getting account: $e');
      return null;
    }
  }

  /// Fetch all categories; set parentOnly to true to return only root categories.
  static Future<List<Category>> getCategories({bool parentOnly = false}) async {
    try {
      var query = _supabase.from('categories').select('*');
      if (parentOnly) {
        // Supabase filter for NULL parent_id (root categories)
        query = query.filter('parent_id', 'is', null);
      }
      final response = await query.order('name', ascending: true);
      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Fetch categories for current user's account; set parentOnly to true to return only root categories.
  static Future<List<Category>> getCategoriesForAccount({bool parentOnly = false}) async {
    try {
      final accountId = await _getCurrentAccountId();
      if (accountId == null) {
        debugPrint('⚠️ [CategoryService] No account ID, returning empty categories list');
        return [];
      }

      // Get category IDs linked to this account via account_categories
      final categoryRelations = await _supabase
          .from('account_categories')
          .select('category_id')
          .eq('account_id', accountId)
          .eq('is_hidden', false);

      final categoryIds = (categoryRelations as List)
          .map((item) => item['category_id'] as String)
          .toList();

      if (categoryIds.isEmpty) {
        debugPrint('⚠️ [CategoryService] No categories linked to account');
        return [];
      }

      // Fetch the actual category details
      var query = _supabase
          .from('categories')
          .select('*')
          .in_('id', categoryIds);
      
      if (parentOnly) {
        query = query.filter('parent_id', 'is', null);
      }
      
      final response = await query.order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories for account: $e');
    }
  }

  /// Fetch child categories for a specific parent category.
  static Future<List<Category>> getChildCategories(String parentId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('parent_id', parentId)
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch child categories: $e');
    }
  }

  /// Fetch child categories for a specific parent category, filtered by current user's account.
  static Future<List<Category>> getChildCategoriesForAccount(String parentId) async {
    try {
      final accountId = await _getCurrentAccountId();
      if (accountId == null) {
        debugPrint('⚠️ [CategoryService] No account ID, returning empty child categories list');
        return [];
      }

      // Get category IDs linked to this account via account_categories
      final categoryRelations = await _supabase
          .from('account_categories')
          .select('category_id')
          .eq('account_id', accountId)
          .eq('is_hidden', false);

      final categoryIds = (categoryRelations as List)
          .map((item) => item['category_id'] as String)
          .toList();

      if (categoryIds.isEmpty) {
        debugPrint('⚠️ [CategoryService] No categories linked to account');
        return [];
      }

      // Fetch child categories that are in the account's category list
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('parent_id', parentId)
          .in_('id', categoryIds)
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch child categories for account: $e');
    }
  }

  /// Fetch child categories for a specific parent category, filtered by a specific account ID.
  static Future<List<Category>> getChildCategoriesForSpecificAccount(
    String parentId,
    String accountId,
  ) async {
    try {
      // Get category IDs linked to this account via account_categories
      final categoryRelations = await _supabase
          .from('account_categories')
          .select('category_id')
          .eq('account_id', accountId)
          .eq('is_hidden', false);

      final categoryIds = (categoryRelations as List)
          .map((item) => item['category_id'] as String)
          .toList();

      if (categoryIds.isEmpty) {
        debugPrint('⚠️ [CategoryService] No categories linked to account $accountId');
        return [];
      }

      // Fetch child categories that are in the account's category list
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('parent_id', parentId)
          .in_('id', categoryIds)
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch child categories for specific account: $e');
    }
  }

  /// Fetch all parent categories (categories without parent_id).
  static Future<List<Category>> getParentCategories() async {
    return getCategories(parentOnly: true);
  }

  /// Fetch parent categories for current user's account.
  static Future<List<Category>> getParentCategoriesForAccount() async {
    return getCategoriesForAccount(parentOnly: true);
  }

  /// Get a specific category by ID.
  static Future<Category?> getCategoryById(String id) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Category.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch category: $e');
    }
  }

  /// Get a specific category by name.
  static Future<Category?> getCategoryByName(String name) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('name', name)
          .maybeSingle();

      if (response == null) return null;
      return Category.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch category: $e');
    }
  }

  /// Create a new category (optionally as a child by providing parentId).
  static Future<Category> createCategory({
    required String name,
    String? description,
    String? parentId,
    int? iconCode,
    String? colorValue,
  }) async {
    try {
      final data = {
        'name': name,
        'description': description,
        if (parentId != null) 'parent_id': parentId,
        if (iconCode != null) 'icon_code': iconCode,
        if (colorValue != null) 'color_value': colorValue,
      };

      final response = await _supabase
          .from('categories')
          .insert(data)
          .select()
          .single();

      return Category.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  /// Create a new category and link it to the current user's account.
  static Future<Category> createCategoryForAccount({
    required String name,
    String? description,
    String? parentId,
    int? iconCode,
    String? colorValue,
  }) async {
    try {
      final accountId = await _getCurrentAccountId();
      if (accountId == null) {
        throw Exception('No account found for current user');
      }

      // Create the category
      final data = {
        'name': name,
        'description': description,
        if (parentId != null) 'parent_id': parentId,
        if (iconCode != null) 'icon_code': iconCode,
        if (colorValue != null) 'color_value': colorValue,
      };

      final response = await _supabase
          .from('categories')
          .insert(data)
          .select()
          .single();

      final category = Category.fromJson(response as Map<String, dynamic>);

      // Link the category to the account via account_categories
      await _supabase.from('account_categories').insert({
        'account_id': accountId,
        'category_id': category.id,
        'is_hidden': false,
      });

      debugPrint('✅ [CategoryService] Created category "${category.name}" and linked to account $accountId');

      return category;
    } catch (e) {
      throw Exception('Failed to create category for account: $e');
    }
  }

  /// Update a category.
  static Future<Category> updateCategory({
    required String id,
    String? name,
    String? description,
    String? parentId,
    int? iconCode,
    String? colorValue,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (parentId != null) data['parent_id'] = parentId;
      if (iconCode != null) data['icon_code'] = iconCode;
      if (colorValue != null) data['color_value'] = colorValue;

      final response = await _supabase
          .from('categories')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return Category.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// Delete a category.
  static Future<void> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }
}
