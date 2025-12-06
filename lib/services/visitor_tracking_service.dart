import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/organization_visitor.dart';

class VisitorTrackingService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Track a visitor when they scan a QR code
  /// Pass the scanned QR code STRING (e.g., "QR-1763288336356-SSBSII69")
  /// This will look up the QR code record and track the visitor
  static Future<void> trackVisitorByCode({
    required String scannedCode,
  }) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        debugPrint('❌ Cannot track visitor: User not logged in');
        return;
      }

      debugPrint('📊 Looking up QR code: $scannedCode');

      // Get the user's account ID (not auth user ID)
      final accountResponse = await _supabase
          .from('accounts')
          .select('id')
          .eq('owner_id', authUserId)
          .maybeSingle();
      
      if (accountResponse == null) {
        debugPrint('❌ No account found for auth user: $authUserId');
        return;
      }
      
      final accountId = accountResponse['id'] as String;
      debugPrint('✅ Found account ID: $accountId');

      // Look up the QR code by its code string to get the UUID and org_id
      final qrCodeData = await _supabase
          .from('qr_codes')
          .select('id, account_id')
          .eq('code', scannedCode)
          .maybeSingle();

      if (qrCodeData == null) {
        debugPrint('❌ QR code not found: $scannedCode');
        return;
      }

      final qrCodeId = qrCodeData['id'] as String;
      final orgId = qrCodeData['account_id'] as String;

      debugPrint('📊 Tracking visitor: accountId=$accountId, org=$orgId, qr=$qrCodeId');

      // Check if visitor record already exists (using account ID, not auth user ID)
      final existing = await _supabase
          .from('organization_visitors')
          .select()
          .eq('user_id', accountId)
          .eq('org_id', orgId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record with new scan time
        debugPrint('🔄 Updating existing visitor record');
        await _supabase
            .from('organization_visitors')
            .update({
              'last_scanned_at': DateTime.now().toIso8601String(),
              'qr_code_id': qrCodeId, // Update to latest QR code used
            })
            .eq('user_id', accountId)
            .eq('org_id', orgId);
        
        debugPrint('✅ Visitor record updated');
      } else {
        // Create new visitor record (using account ID, not auth user ID)
        debugPrint('➕ Creating new visitor record');
        await _supabase.from('organization_visitors').insert({
          'user_id': accountId,  // Use account ID instead of auth user ID
          'org_id': orgId,
          'qr_code_id': qrCodeId,
        });
        
        debugPrint('✅ New visitor record created');
      }
    } catch (e) {
      debugPrint('❌ Error tracking visitor: $e');
      // Don't throw - tracking failures shouldn't break the scan flow
    }
  }

  /// Track a visitor when you already have the QR code UUID and org UUID
  static Future<void> trackVisitor({
    required String qrCodeId,
    required String orgId,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🎯 [VisitorTracking] trackVisitor() called');
      debugPrint('   📋 Input parameters:');
      debugPrint('      - qrCodeId: $qrCodeId');
      debugPrint('      - orgId: $orgId');
      
      final authUserId = _supabase.auth.currentUser?.id;
      debugPrint('   👤 Auth user ID: ${authUserId ?? "NOT LOGGED IN"}');
      
      if (authUserId == null) {
        debugPrint('❌ [VisitorTracking] Cannot track visitor: User not logged in');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return;
      }

      // Get the user's account ID (not auth user ID)
      debugPrint('   🔍 Looking up user account ID...');
      final accountResponse = await _supabase
          .from('accounts')
          .select('id')
          .eq('owner_id', authUserId)
          .maybeSingle();
      
      if (accountResponse == null) {
        debugPrint('❌ [VisitorTracking] No account found for auth user: $authUserId');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return;
      }
      
      final accountId = accountResponse['id'] as String;
      debugPrint('   ✅ Found account ID: $accountId');
      debugPrint('   🔍 Checking for existing visitor record...');

      // Check if visitor record already exists (using account ID, not auth user ID)
      final existing = await _supabase
          .from('organization_visitors')
          .select()
          .eq('user_id', accountId)
          .eq('org_id', orgId)
          .maybeSingle();

      debugPrint('   📊 Existing record: ${existing != null ? "FOUND (ID: ${existing['id']})" : "NOT FOUND"}');

      if (existing != null) {
        // Update existing record with new scan time
        debugPrint('   🔄 [VisitorTracking] Updating existing visitor record...');
        debugPrint('      - Record ID: ${existing['id']}');
        
        final updateData = {
          'last_scanned_at': DateTime.now().toIso8601String(),
          'qr_code_id': qrCodeId,
        };
        debugPrint('      - Update data: $updateData');
        
        final updateResult = await _supabase
            .from('organization_visitors')
            .update(updateData)
            .eq('user_id', accountId)
            .eq('org_id', orgId)
            .select();
        
        debugPrint('   ✅ [VisitorTracking] Visitor record updated successfully');
        debugPrint('      - Updated record: $updateResult');
      } else {
        // Create new visitor record (using account ID, not auth user ID)
        debugPrint('   ➕ [VisitorTracking] Creating new visitor record...');
        
        final insertData = {
          'user_id': accountId,  // Use account ID instead of auth user ID
          'org_id': orgId,
          'qr_code_id': qrCodeId,
        };
        debugPrint('      - Insert data: $insertData');
        
        final insertResult = await _supabase
            .from('organization_visitors')
            .insert(insertData)
            .select();
        
        debugPrint('   ✅ [VisitorTracking] New visitor record created successfully');
        debugPrint('      - New record: $insertResult');
      }
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ [VisitorTracking] ERROR tracking visitor!');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   Error message: $e');
      debugPrint('   Stack trace: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // Don't throw - tracking failures shouldn't break the scan flow
    }
  }

  /// Get all visitors for an organization
  static Future<List<OrganizationVisitor>> getOrganizationVisitors(
    String orgId,
  ) async {
    try {
      debugPrint('📊 Fetching visitors for org: $orgId');
      
      final response = await _supabase
          .from('organization_visitors')
          .select()
          .eq('org_id', orgId)
          .order('last_scanned_at', ascending: false);

      final visitors = (response as List)
          .map((json) => OrganizationVisitor.fromJson(json))
          .toList();

      debugPrint('✅ Found ${visitors.length} visitors');
      return visitors;
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
      return [];
    }
  }

  /// Get visitor count for an organization
  static Future<int> getVisitorCount(String orgId) async {
    try {
      final response = await _supabase
          .from('organization_visitors')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('org_id', orgId);

      return response.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting visitor count: $e');
      return 0;
    }
  }

  /// Get recent visitors for an organization (last 10)
  static Future<List<OrganizationVisitor>> getRecentVisitors(
    String orgId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('organization_visitors')
          .select()
          .eq('org_id', orgId)
          .order('last_scanned_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => OrganizationVisitor.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching recent visitors: $e');
      return [];
    }
  }
}
