import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_category.dart';

class AccountCategoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Add a category to an account
  Future<AccountCategory> addCategoryToAccount({
    required String accountId,
    required String categoryId,
    bool isHidden = false,
  }) async {
    try {
      final response = await _supabase
          .from('account_categories')
          .insert({
            'account_id': accountId,
            'category_id': categoryId,
            'is_hidden': isHidden,
          })
          .select()
          .single();

      return AccountCategory.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add category to account: $e');
    }
  }

  /// Remove a category from an account
  Future<void> removeCategoryFromAccount({
    required String accountId,
    required String categoryId,
  }) async {
    try {
      await _supabase
          .from('account_categories')
          .delete()
          .eq('account_id', accountId)
          .eq('category_id', categoryId);
    } catch (e) {
      throw Exception('Failed to remove category from account: $e');
    }
  }

  /// Get all categories for an account
  Future<List<String>> getCategoriesForAccount(String accountId) async {
    try {
      final response = await _supabase
          .from('account_categories')
          .select('category_id')
          .eq('account_id', accountId)
          .eq('is_hidden', false);

      return (response as List)
          .map((item) => item['category_id'] as String)
          .toList();
    } catch (e) {
      throw Exception('Failed to get categories for account: $e');
    }
  }

  /// Get all accounts for a category
  Future<List<String>> getAccountsForCategory(String categoryId) async {
    try {
      final response = await _supabase
          .from('account_categories')
          .select('account_id')
          .eq('category_id', categoryId)
          .eq('is_hidden', false);

      return (response as List)
          .map((item) => item['account_id'] as String)
          .toList();
    } catch (e) {
      throw Exception('Failed to get accounts for category: $e');
    }
  }

  /// Toggle hidden status for an account-category relationship
  Future<void> toggleHiddenStatus({
    required String accountId,
    required String categoryId,
    required bool isHidden,
  }) async {
    try {
      await _supabase
          .from('account_categories')
          .update({'is_hidden': isHidden})
          .eq('account_id', accountId)
          .eq('category_id', categoryId);
    } catch (e) {
      throw Exception('Failed to toggle hidden status: $e');
    }
  }

  /// Get all account-category relationships for an account
  Future<List<AccountCategory>> getAccountCategoryRelations(
      String accountId) async {
    try {
      final response = await _supabase
          .from('account_categories')
          .select()
          .eq('account_id', accountId);

      return (response as List)
          .map((item) => AccountCategory.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get account-category relations: $e');
    }
  }

  /// Bulk add categories to an account
  Future<void> addCategoriesToAccount({
    required String accountId,
    required List<String> categoryIds,
    bool isHidden = false,
  }) async {
    try {
      final records = categoryIds.map((categoryId) => {
            'account_id': accountId,
            'category_id': categoryId,
            'is_hidden': isHidden,
          }).toList();

      await _supabase.from('account_categories').insert(records);
    } catch (e) {
      throw Exception('Failed to add categories to account: $e');
    }
  }

  /// Bulk remove categories from an account
  Future<void> removeCategoriesFromAccount({
    required String accountId,
    required List<String> categoryIds,
  }) async {
    try {
      await _supabase
          .from('account_categories')
          .delete()
          .eq('account_id', accountId)
          .in_('category_id', categoryIds);
    } catch (e) {
      throw Exception('Failed to remove categories from account: $e');
    }
  }

  /// Replace all categories for an account
  Future<void> replaceAccountCategories({
    required String accountId,
    required List<String> categoryIds,
    bool isHidden = false,
  }) async {
    try {
      // First, remove all existing categories
      await _supabase
          .from('account_categories')
          .delete()
          .eq('account_id', accountId);

      // Then, add the new categories
      if (categoryIds.isNotEmpty) {
        await addCategoriesToAccount(
          accountId: accountId,
          categoryIds: categoryIds,
          isHidden: isHidden,
        );
      }
    } catch (e) {
      throw Exception('Failed to replace account categories: $e');
    }
  }
}
