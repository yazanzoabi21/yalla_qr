import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static const _sessionKey = 'supabase_session';

  static Future<void> saveSessionJson(String sessionJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_sessionKey, sessionJson);
      
      if (success) {
        debugPrint('✅ Session saved to SharedPreferences successfully');
        
        // Force commit to disk on Android (setString already does this, but let's be explicit)
        await prefs.reload();
        
        // Verify it was saved by reading it back
        final savedSession = prefs.getString(_sessionKey);
        if (savedSession != null) {
          debugPrint('✅ Session verified in storage (length: ${savedSession.length})');
        } else {
          debugPrint('⚠️ WARNING: Session not found after save!');
        }
      } else {
        debugPrint('❌ Failed to save session to SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Error saving session: $e');
      rethrow;
    }
  }

  static Future<String?> getSessionJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final session = prefs.getString(_sessionKey);
      
      if (session != null) {
        debugPrint('✅ Session retrieved from storage (length: ${session.length})');
      } else {
        debugPrint('ℹ️ No session found in storage');
      }
      
      return session;
    } catch (e) {
      debugPrint('❌ Error retrieving session: $e');
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_sessionKey);
      
      if (success) {
        debugPrint('✅ Session cleared from SharedPreferences');
      } else {
        debugPrint('⚠️ Failed to clear session from SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Error clearing session: $e');
    }
  }
}
