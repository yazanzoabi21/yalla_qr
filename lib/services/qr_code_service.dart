import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/index.dart';
import 'visitor_tracking_service.dart';

class QRCodeService {
  final SupabaseClient _client;

  QRCodeService(this._client);

  /// Generate a unique QR code string
  String _generateUniqueCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    
    return 'QR-$timestamp-$randomPart';
  }

  /// Create a QR code for an account
  Future<QRCodeModel> createQRCodeForAccount(String accountId) async {
    try {
      // Check if account already has a QR code
      final existingQR = await _client
          .from('qr_codes')
          .select()
          .eq('account_id', accountId)
          .maybeSingle();

      if (existingQR != null) {
        return QRCodeModel.fromJson(existingQR);
      }

      // Generate unique code
      String code;
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 5;

      do {
        code = _generateUniqueCode();
        final existing = await _client
            .from('qr_codes')
            .select()
            .eq('code', code)
            .maybeSingle();
        
        isUnique = existing == null;
        attempts++;
      } while (!isUnique && attempts < maxAttempts);

      if (!isUnique) {
        throw Exception('Failed to generate unique QR code after $maxAttempts attempts');
      }

      // Create QR code
      final qrData = {
        'account_id': accountId,
        'code': code,
        'scan_count': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client
          .from('qr_codes')
          .insert(qrData)
          .select()
          .single();

      return QRCodeModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create QR code: $e');
    }
  }

  /// Get QR code by account ID
  Future<QRCodeModel?> getQRCodeByAccountId(String accountId) async {
    try {
      final response = await _client
          .from('qr_codes')
          .select()
          .eq('account_id', accountId)
          .maybeSingle();

      if (response == null) return null;

      return QRCodeModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get QR code: $e');
    }
  }

  /// Get QR code by code string
  Future<QRCodeModel?> getQRCodeByCode(String code) async {
    try {
      debugPrint('🔍 [QRCodeService.getQRCodeByCode] Searching for code: $code');
      
      final response = await _client
          .from('qr_codes')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ [QRCodeService.getQRCodeByCode] No QR code found for: $code');
        
        // Check if there are ANY QR codes in the database
        final allQRCodes = await _client
            .from('qr_codes')
            .select('code')
            .limit(5);
        
        debugPrint('📊 [QRCodeService.getQRCodeByCode] Sample QR codes in database:');
        if (allQRCodes.isEmpty) {
          debugPrint('   ⚠️ Database has NO QR codes!');
        } else {
          for (var qr in allQRCodes) {
            debugPrint('   - ${qr['code']}');
          }
        }
        
        return null;
      }

      debugPrint('✅ [QRCodeService.getQRCodeByCode] Found QR code: ${response['id']}');
      return QRCodeModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ [QRCodeService.getQRCodeByCode] Error: $e');
      throw Exception('Failed to get QR code: $e');
    }
  }

  /// Get account information from QR code
  Future<Account?> getAccountFromQRCode(String code) async {
    try {
      final response = await _client
          .from('qr_codes')
          .select('account_id, accounts(*)')
          .eq('code', code)
          .maybeSingle();

      if (response == null || response['accounts'] == null) return null;

      return Account.fromJson(response['accounts']);
    } catch (e) {
      throw Exception('Failed to get account from QR code: $e');
    }
  }

  /// Increment scan count for a QR code
  Future<int> incrementScanCount(String qrCodeId) async {
    try {
      final response = await _client
          .rpc('increment_scan_count', params: {'qr_code_id': qrCodeId});

      return response as int;
    } catch (e) {
      // Fallback to manual increment if function doesn't exist
      try {
        final qrCode = await _client
            .from('qr_codes')
            .select('scan_count')
            .eq('id', qrCodeId)
            .single();

        final newCount = (qrCode['scan_count'] as int? ?? 0) + 1;

        await _client
            .from('qr_codes')
            .update({'scan_count': newCount})
            .eq('id', qrCodeId);

        return newCount;
      } catch (fallbackError) {
        throw Exception('Failed to increment scan count: $fallbackError');
      }
    }
  }

  /// Log a QR code scan
  Future<ScanLog> logScan({
    required String qrCodeId,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final scanData = {
        'qr_code_id': qrCodeId,
        'scanned_at': DateTime.now().toUtc().toIso8601String(),
        'location_lat': latitude,
        'location_lng': longitude,
        'device_info': deviceInfo,
      };

      final response = await _client
          .from('scan_logs')
          .insert(scanData)
          .select()
          .single();

      // Increment scan count
      await incrementScanCount(qrCodeId);

      // Track visitor (get org_id from the QR code)
      try {
        debugPrint('🔍 [QRCodeService] Starting visitor tracking for QR code: $qrCodeId');
        
        final qrCodeData = await _client
            .from('qr_codes')
            .select('account_id')
            .eq('id', qrCodeId)
            .single();
        
        debugPrint('🔍 [QRCodeService] QR code data retrieved: $qrCodeData');
        
        final orgId = qrCodeData['account_id'] as String?;
        if (orgId == null) {
          debugPrint('❌ [QRCodeService] No account_id found for QR code: $qrCodeId');
          return response;
        }
        
        debugPrint('🔍 [QRCodeService] Calling VisitorTrackingService with qrCodeId=$qrCodeId, orgId=$orgId');
        
        await VisitorTrackingService.trackVisitor(
          qrCodeId: qrCodeId,
          orgId: orgId,
        );
        
        debugPrint('✅ [QRCodeService] Visitor tracking completed successfully');
      } catch (visitorError) {
        // Don't fail the scan if visitor tracking fails
        debugPrint('❌ [QRCodeService] Failed to track visitor: $visitorError');
        debugPrint('❌ [QRCodeService] Error stack trace: ${StackTrace.current}');
      }

      return ScanLog.fromJson(response);
    } catch (e) {
      throw Exception('Failed to log scan: $e');
    }
  }

  /// Get scan logs for a QR code
  Future<List<ScanLog>> getScanLogs(String qrCodeId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('scan_logs')
          .select()
          .eq('qr_code_id', qrCodeId)
          .order('scanned_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ScanLog.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get scan logs: $e');
    }
  }

  /// Get scan logs for an account (via QR code)
  Future<List<ScanLog>> getScanLogsByAccountId(String accountId, {int limit = 50}) async {
    try {
      // First get the QR code for this account
      final qrCode = await getQRCodeByAccountId(accountId);
      if (qrCode == null) return [];

      return getScanLogs(qrCode.id, limit: limit);
    } catch (e) {
      throw Exception('Failed to get scan logs for account: $e');
    }
  }

  /// Get scan statistics for an account
  Future<Map<String, dynamic>> getScanStatistics(String accountId) async {
    try {
      final qrCode = await getQRCodeByAccountId(accountId);
      if (qrCode == null) {
        return {
          'total_scans': 0,
          'today_scans': 0,
          'week_scans': 0,
          'month_scans': 0,
        };
      }

      final now = DateTime.now().toUtc();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();
      final weekStart = now.subtract(Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1).toUtc();

      // Get today's scans
      final todayScans = await _client
          .from('scan_logs')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('qr_code_id', qrCode.id)
          .gte('scanned_at', todayStart.toIso8601String());

      // Get week's scans
      final weekScans = await _client
          .from('scan_logs')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('qr_code_id', qrCode.id)
          .gte('scanned_at', weekStart.toIso8601String());

      // Get month's scans
      final monthScans = await _client
          .from('scan_logs')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('qr_code_id', qrCode.id)
          .gte('scanned_at', monthStart.toIso8601String());

      return {
        'total_scans': qrCode.scanCount,
        'today_scans': todayScans.count ?? 0,
        'week_scans': weekScans.count ?? 0,
        'month_scans': monthScans.count ?? 0,
        'qr_code': qrCode.code,
        'created_at': qrCode.createdAt.toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get scan statistics: $e');
    }
  }

  /// Delete QR code (will cascade delete scan logs)
  Future<void> deleteQRCode(String qrCodeId) async {
    try {
      await _client
          .from('qr_codes')
          .delete()
          .eq('id', qrCodeId);
    } catch (e) {
      throw Exception('Failed to delete QR code: $e');
    }
  }

  /// Regenerate QR code for an account
  Future<QRCodeModel> regenerateQRCodeForAccount(String accountId) async {
    try {
      // Delete existing QR code
      final existingQR = await getQRCodeByAccountId(accountId);
      if (existingQR != null) {
        await deleteQRCode(existingQR.id);
      }

      // Create new QR code
      return await createQRCodeForAccount(accountId);
    } catch (e) {
      throw Exception('Failed to regenerate QR code: $e');
    }
  }
}
