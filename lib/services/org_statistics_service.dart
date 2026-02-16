import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/org_statistics.dart';

class OrgStatisticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch statistics for a specific organization account
  Future<OrgStatistics?> getStatistics(String accountId) async {
    try {
      debugPrint('📊 Fetching statistics for account: $accountId');

      final response = await _supabase
          .from('org_statistics')
          .select()
          .eq('account_id', accountId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No statistics found for account: $accountId');
        return null;
      }

      final statistics = OrgStatistics.fromJson(response);
      debugPrint('✅ Statistics fetched successfully');
      return statistics;
    } catch (e) {
      debugPrint('❌ Error fetching statistics: $e');
      rethrow;
    }
  }

  /// Refresh/update statistics for a specific organization account
  /// This calls the Supabase function to recalculate all statistics
  Future<void> refreshStatistics(String accountId) async {
    try {
      debugPrint('🔄 Refreshing statistics for account: $accountId');

      await _supabase.rpc('update_org_statistics', params: {
        'p_account_id': accountId,
      });

      debugPrint('✅ Statistics refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing statistics: $e');
      rethrow;
    }
  }

  /// Fetch and refresh statistics in one call
  Future<OrgStatistics?> getRefreshedStatistics(String accountId) async {
    try {
      // First refresh the statistics
      await refreshStatistics(accountId);
      
      // Then fetch and return the updated statistics
      return await getStatistics(accountId);
    } catch (e) {
      debugPrint('❌ Error getting refreshed statistics: $e');
      rethrow;
    }
  }

  /// Stream statistics updates for real-time updates
  Stream<OrgStatistics?> watchStatistics(String accountId) {
    return _supabase
        .from('org_statistics')
        .stream(primaryKey: ['id'])
        .eq('account_id', accountId)
        .map((data) {
          if (data.isEmpty) return null;
          return OrgStatistics.fromJson(data.first);
        });
  }

  /// Check if statistics exist for an account
  Future<bool> hasStatistics(String accountId) async {
    try {
      final response = await _supabase
          .from('org_statistics')
          .select('id')
          .eq('account_id', accountId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking statistics existence: $e');
      return false;
    }
  }

  /// Create initial statistics entry for a new organization
  Future<OrgStatistics?> createStatistics(String accountId) async {
    try {
      debugPrint('➕ Creating statistics for account: $accountId');

      // First refresh to calculate initial values
      await refreshStatistics(accountId);
      
      // Then fetch and return the created statistics
      return await getStatistics(accountId);
    } catch (e) {
      debugPrint('❌ Error creating statistics: $e');
      rethrow;
    }
  }
}
