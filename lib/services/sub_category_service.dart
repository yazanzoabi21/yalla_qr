import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/sub_category.dart';

class SubCategoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all sub-categories from the database
  static Future<List<SubCategory>> getSubCategories() async {
    try {
      debugPrint('🔍 Fetching all sub-categories...');
      final response = await _supabase
          .from('sub_category')
          .select('id, name, description, category_id, created_at, icon_value, color_value')
          .order('name', ascending: true);

      debugPrint('Fetched ${response.length} sub-categories');
      return (response as List)
          .map((json) => SubCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch sub-categories: $e');
      throw Exception('Failed to fetch sub-categories: $e');
    }
  }

  /// Get sub-categories by category ID
  static Future<List<SubCategory>> getSubCategoriesByCategoryId(String categoryId) async {
    try {
      debugPrint('🔍 Fetching sub-categories for category: $categoryId');
      final response = await _supabase
          .from('sub_category')
          .select('id, name, description, category_id, created_at, icon_value, color_value')
          .eq('category_id', categoryId)
          .order('name', ascending: true);

      debugPrint('✅ Fetched ${response.length} sub-categories for category $categoryId');
      final subCategories = (response as List)
          .map((json) => SubCategory.fromJson(json as Map<String, dynamic>))
          .toList();

      // Debug log the values we're getting
      for (var subCat in subCategories) {
        debugPrint('   - ${subCat.name}: iconValue="${subCat.iconValue}", colorValue="${subCat.colorValue}"');
      }

      return subCategories;
    } catch (e) {
      debugPrint('Failed to fetch sub-categories for category $categoryId: $e');
      throw Exception('Failed to fetch sub-categories for category $categoryId: $e');
    }
  }

  /// Get a specific sub-category by ID
  static Future<SubCategory?> getSubCategoryById(int id) async {
    try {
      debugPrint('Fetching sub-category by ID: $id');
      final response = await _supabase
          .from('sub_category')
          .select('id, name, description, category_id, created_at, icon_value, color_value')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        debugPrint('Sub-category with ID $id not found');
        return null;
      }

      debugPrint('Found sub-category: ${response['name']}');
      return SubCategory.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to fetch sub-category $id: $e');
      throw Exception('Failed to fetch sub-category: $e');
    }
  }

  /// Create a new sub-category
  static Future<SubCategory> createSubCategory({
    required String name,
    String? description,
    required String categoryId,
    String? colorValue,
    String? iconValue,
  }) async {
    try {
      debugPrint('Creating sub-category: $name');
      debugPrint('   - categoryId: $categoryId');
      debugPrint('   - iconValue: $iconValue');
      debugPrint('   - colorValue: $colorValue');

      final insertData = {
        'name': name,
        'description': description,
        'category_id': categoryId,
        'color_value': colorValue,
        'icon_value': iconValue,
      };

      final response = await _supabase
          .from('sub_category')
          .insert(insertData)
          .select('id, name, description, category_id, created_at, icon_value, color_value')
          .single()
          .timeout(const Duration(seconds: 10));

      debugPrint('Created sub-category successfully: ${response['name']} (ID: ${response['id']})');
      return SubCategory.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to create sub-category: $e');
      if (e.toString().contains('42501') || e.toString().contains('row-level security')) {
        throw Exception('Permission denied. Please check database security settings.');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out. Please try again.');
      }
      throw Exception('Failed to create sub-category: $e');
    }
  }

  /// Update an existing sub-category
  static Future<SubCategory> updateSubCategory({
    required int id,
    String? name,
    String? description,
    String? categoryId,
    String? colorValue,
    String? iconValue,
  }) async {
    try {
      debugPrint('Updating sub-category ID: $id');
      
      final Map<String, dynamic> updateData = {};
      if (name != null) {
        updateData['name'] = name;
        debugPrint('   - name: $name');
      }
      if (description != null) {
        updateData['description'] = description;
        debugPrint('   - description: $description');
      }
      if (categoryId != null) {
        updateData['category_id'] = categoryId;
        debugPrint('   - category_id: $categoryId');
      }
      if (colorValue != null) {
        updateData['color_value'] = colorValue;
        debugPrint('   - color_value: $colorValue');
      }
      if (iconValue != null) {
        updateData['icon_value'] = iconValue;
        debugPrint('   - icon_value: $iconValue');
      }

      final response = await _supabase
          .from('sub_category')
          .update(updateData)
          .eq('id', id)
          .select('id, name, description, category_id, created_at, icon_value, color_value')
          .single();

      debugPrint('Updated sub-category successfully: ${response['name']}');
      return SubCategory.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to update sub-category $id: $e');
      throw Exception('Failed to update sub-category: $e');
    }
  }

  /// Delete a sub-category
  static Future<void> deleteSubCategory(int id) async {
    try {
      debugPrint('Deleting sub-category ID: $id');
      await _supabase.from('sub_category').delete().eq('id', id);
      debugPrint('Deleted sub-category successfully');
    } catch (e) {
      debugPrint('Failed to delete sub-category $id: $e');
      throw Exception('Failed to delete sub-category: $e');
    }
  }

  /// Validate icon and color values before saving
  static Map<String, String?> validateAndPrepareValues({
    required IconData? icon,
    required Color? color,
  }) {
    String? iconValue;
    String? colorValue;

    if (icon != null) {
      iconValue = icon.codePoint.toString();
      debugPrint('Prepared iconValue: $iconValue (from codePoint: ${icon.codePoint})');
    }

    if (color != null) {
      colorValue = color.value.toString();
    }

    return {
      'iconValue': iconValue,
      'colorValue': colorValue,
    };
  }
}
