import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
// import 'package:logging/logging.dart';

class CategoryService {
  // static final _log = Logger('CategoryService');
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all categories from the database
  static Future<List<Category>> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Get a specific category by ID
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

  /// Get a specific category by name
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

  /// Create a new category (if needed for admin functionality)
  static Future<Category> createCategory({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .insert({'name': name, 'description': description})
          .select()
          .single();

      return Category.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }
}
