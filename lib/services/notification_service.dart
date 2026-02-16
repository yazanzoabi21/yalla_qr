import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for managing OneSignal push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isInitialized = false;
  String? _playerId; // OneSignal player ID (device ID)

  /// Initialize OneSignal with your App ID
  /// Call this in main.dart before runApp()
  Future<void> initialize({
    required String appId,
    bool enableInAppNotifications = true,
  }) async {
    if (_isInitialized) {
      debugPrint('?? [NotificationService] Already initialized');
      return;
    }

    try {
      debugPrint('?? [NotificationService] Initializing OneSignal...');

      // Initialize OneSignal
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);

      // Request notification permission
      final hasPermission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('?? [NotificationService] Permission granted: $hasPermission');

      // Explicitly opt-in
      await OneSignal.User.pushSubscription.optIn();
      debugPrint('?? [NotificationService] push subscription opted-in');

      // Log current subscription state
      debugPrint('?? [NotificationService] optedIn: ${OneSignal.User.pushSubscription.optedIn}');
      debugPrint('?? [NotificationService] push token: ${OneSignal.User.pushSubscription.token}');

      // Fetch current subscription once and persist if available
      final sub = OneSignal.User.pushSubscription;
      var subId = sub.id;
      debugPrint('?? [NotificationService] current subscription id: $subId');
      if (subId == null || subId.isEmpty) {
        debugPrint('?? [NotificationService] No subscription id from pushSubscription; will rely on subscription listener and polling');
      }

      if (subId != null && subId.isNotEmpty) {
        _playerId = subId;
        await _updatePlayerIdInDatabase();
      }

      // Listen to push subscription changes (single observer)
      // This will fire again when OneSignal backend responds with subscription ID
      OneSignal.User.pushSubscription.addObserver((state) async {
        final timestamp = DateTime.now().toIso8601String();
        final id = state.current.id;
        if (id != null && id.isNotEmpty) {
          _playerId = id;
          await _updatePlayerIdInDatabase();
        } else if (state.current.optedIn) {
          _pollForPlayerId();
        }
      });

      // Listen to foreground notifications
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {

        if (enableInAppNotifications) {
          event.notification.display();
        }
      });

      // Listen to notification clicks
      OneSignal.Notifications.addClickListener((event) {

        _handleNotificationClick(event.notification);
      });

      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Update player ID in database for the current user
  /// Saves the OneSignal player ID to the user_player_ids table
  /// Supports multiple devices per user - each device has unique player_id
  Future<void> _updatePlayerIdInDatabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || _playerId == null) {
        return;
      }

      final deviceType = _getDeviceType();

      // 1. Update user_player_ids table (new structure - supports multiple devices)
      try {
        await _supabase
            .from('user_player_ids')
            .upsert(
              {
                'user_id': user.id,
                'player_id': _playerId,
                'device_type': deviceType,
                'is_active': true,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              onConflict: 'player_id',
              ignoreDuplicates: false, // Always update if exists
            );
        
        // Log all active devices for this user (for debugging)
        try {
          final userDevices = await _supabase
              .from('user_player_ids')
              .select('player_id, device_type, created_at')
              .eq('user_id', user.id)
              .eq('is_active', true)
              .order('created_at', ascending: false);
          
          for (var i = 0; i < userDevices.length; i++) {
            final device = userDevices[i];
          }
        } catch (queryError) {
        }
      } catch (upsertError) {
        
        // Fallback: try direct insert (will fail if duplicate)
        try {
          await _supabase
              .from('user_player_ids')
              .insert({
                'user_id': user.id,
                'player_id': _playerId,
                'device_type': deviceType,
                'is_active': true,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              });
        } catch (insertError) {
          // Don't rethrow - continue to accounts table update
        }
      }

      // 2. CRITICAL: Update accounts table (legacy structure - for backward compatibility)
      // This is the FIX for notifications not working when sent from app!
      // Many parts of the app (and edge functions) read from accounts.onesignal_player_id
      try {
        final updateResult = await _supabase
            .from('accounts')
            .update({
              'onesignal_player_id': _playerId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('owner_id', user.id)
            .select();
        
        if (updateResult.isEmpty) {
        } else {
        }
      } catch (accountError) {
        debugPrint('❌ [NotificationService] Error updating accounts table: $accountError');
        debugPrint('   Notifications sent via app may not work!');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [NotificationService] Fatal error updating player ID: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
  }

  /// Get device type based on platform
  String _getDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Poll for player ID if not immediately available (some devices are slow)
  /// Tries up to 30 times with 2 second intervals (1 minute total)
  Future<void> _pollForPlayerId() async {
    for (int attempt = 1; attempt <= 30; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      var playerId = OneSignal.User.pushSubscription.id;
      var token = OneSignal.User.pushSubscription.token;
      
      if (playerId != null && playerId.isNotEmpty) {
        _playerId = playerId;
        await _updatePlayerIdInDatabase();
        return; // Success, stop polling
      }
    }
  }

  /// Set external user ID (typically your user ID from Supabase)
  /// This allows you to target specific users
  Future<void> setExternalUserId(String userId) async {
    try {
      debugPrint('🔔 [NotificationService] Setting external user ID: $userId');
      OneSignal.login(userId);

      // Ensure push permission is granted (important for some devices)
      final hasPermission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 [NotificationService] Push permission: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('⚠️ [NotificationService] Push permission not granted - subscription may not work');
      }

      // Ensure opt-in (some devices need this)
      await OneSignal.User.pushSubscription.optIn();
      
      // Wait a bit for OneSignal to process
      await Future.delayed(const Duration(milliseconds: 500));

      // Try to get player ID immediately if available
      var currentPlayerId = OneSignal.User.pushSubscription.id;
      if (currentPlayerId == null || currentPlayerId.isEmpty) {
        debugPrint('⚠️ [NotificationService] No player ID available from pushSubscription after setExternalUserId; waiting for subscription listener/poll');
      }
      if (currentPlayerId != null && currentPlayerId.isNotEmpty) {
        _playerId = currentPlayerId;
        debugPrint('🔔 [NotificationService] Got player ID from OneSignal: $_playerId');
        await _updatePlayerIdInDatabase();
      } else {
        debugPrint('⚠️ [NotificationService] No player ID available yet - will save when subscription listener triggers');
      }

      debugPrint('✅ [NotificationService] External user ID set');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error setting external user ID: $e');
    }
  }

  /// Enable or disable push notifications for this device
  Future<void> setPushEnabled(bool enabled) async {
    try {
      if (enabled) {
        final hasPermission = await OneSignal.Notifications.requestPermission(true);
        debugPrint('🔔 [NotificationService] Push permission: $hasPermission');
        await OneSignal.User.pushSubscription.optIn();
        debugPrint('✅ [NotificationService] Push subscription opted-in');
      } else {
        await OneSignal.User.pushSubscription.optOut();
        debugPrint('🚫 [NotificationService] Push subscription opted-out');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Error setting push enabled=$enabled: $e');
    }
  }

  /// Force update player ID in database (call this after login)
  Future<void> forceUpdatePlayerIdInDatabase() async {
    try {
      debugPrint('🔔 [NotificationService] Force updating player ID...');
      
      // Get latest player ID from OneSignal
      var currentPlayerId = OneSignal.User.pushSubscription.id;
      if (currentPlayerId == null || currentPlayerId.isEmpty) {
        debugPrint('⚠️ [NotificationService] No player ID available from pushSubscription in forceUpdate');
      }
      if (currentPlayerId != null && currentPlayerId.isNotEmpty) {
        _playerId = currentPlayerId;
        debugPrint('🔔 [NotificationService] Current OneSignal player ID: $_playerId');
      } else {
        debugPrint('⚠️ [NotificationService] No OneSignal player ID available');
        return;
      }

      await _updatePlayerIdInDatabase();
    } catch (e) {
      debugPrint('❌ [NotificationService] Error force updating player ID: $e');
    }
  }

  /// Clear external user ID (call on logout)
  Future<void> clearExternalUserId() async {
    try {
      debugPrint('?? [NotificationService] Clearing external user ID');
      OneSignal.logout();
      debugPrint('? [NotificationService] External user ID cleared');
    } catch (e) {
      debugPrint('? [NotificationService] Error clearing external user ID: $e');
    }
  }

  /// Add tags to categorize users (e.g., role: 'ORG', 'USER', 'DELIVERY')
  Future<void> setUserTags(Map<String, String> tags) async {
    try {
      debugPrint('?? [NotificationService] Setting user tags: $tags');

      await OneSignal.User.addTags(tags);

      debugPrint('? [NotificationService] User tags set');
    } catch (e) {
      debugPrint('? [NotificationService] Error setting user tags: $e');
    }
  }

  /// Handle notification click
  void _handleNotificationClick(OSNotification notification) {
    final data = notification.additionalData;

    if (data != null) {
      final type = data['type'] as String?;
      final orderId = data['order_id'] as String?;

      debugPrint('?? [NotificationService] Notification type: $type');
      debugPrint('?? [NotificationService] Order ID: $orderId');

      // TODO: Navigate to appropriate screen based on notification type
    }
  }

  /// Send notification to a specific user (by external user ID)
  /// Uses Supabase Edge Function to securely call OneSignal REST API
  /// Falls back to direct OneSignal API if edge function not deployed
  Future<void> sendToUser({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('🔔 [NotificationService] Sending notification to user: $userId');
      debugPrint('   Title: $title');
      debugPrint('   Message: $message');

      // Try Supabase Edge Function first (secure, recommended)
      try {
        final response = await _supabase.functions.invoke(
          'send-notification',
          body: {
            'type': 'user',
            'userId': userId,
            'title': title,
            'message': message,
            if (data != null) 'data': data,
          },
        );

        final status = response.status ?? 500;
        if (status >= 200 && status < 300) {
          debugPrint('✅ [NotificationService] Notification sent via Edge Function');
          debugPrint('   Response: ${response.data}');
          return;
        } else {
          debugPrint('⚠️ [NotificationService] Edge Function failed (status $status)');
          debugPrint('   Will try direct OneSignal API as fallback...');
        }
      } catch (edgeFunctionError) {
        debugPrint('⚠️ [NotificationService] Edge Function error: $edgeFunctionError');
        debugPrint('   Will try direct OneSignal API as fallback...');
      }

      // Fallback: Call OneSignal API directly (requires REST API key in .env)
      await _sendDirectToOneSignal(
        type: 'user',
        userId: userId,
        title: title,
        message: message,
        data: data,
      );
    } catch (e) {
      debugPrint('❌ [NotificationService] Error sending notification: $e');
      rethrow;
    }
  }

  /// Send notification to users with specific tags (e.g., role: 'DELIVERY')
  /// Uses Supabase Edge Function to securely call OneSignal REST API
  /// Falls back to direct OneSignal API if edge function not deployed
  Future<void> sendToTag({
    required String tagKey,
    required String tagValue,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('🔔 [NotificationService] Sending notification to tag: $tagKey=$tagValue');
      debugPrint('   Title: $title');
      debugPrint('   Message: $message');

      // Try Supabase Edge Function first (secure, recommended)
      try {
        final response = await _supabase.functions.invoke(
          'send-notification',
          body: {
            'type': 'tag',
            'tagKey': tagKey,
            'tagValue': tagValue,
            'title': title,
            'message': message,
            if (data != null) 'data': data,
          },
        );

        final status = response.status ?? 500;
        if (status >= 200 && status < 300) {
          debugPrint('✅ [NotificationService] Notification sent via Edge Function');
          debugPrint('   Response: ${response.data}');
          return;
        } else {
          debugPrint('⚠️ [NotificationService] Edge Function failed (status $status)');
          debugPrint('   Will try direct OneSignal API as fallback...');
        }
      } catch (edgeFunctionError) {
        debugPrint('⚠️ [NotificationService] Edge Function error: $edgeFunctionError');
        debugPrint('   Will try direct OneSignal API as fallback...');
      }

      // Fallback: Call OneSignal API directly
      await _sendDirectToOneSignal(
        type: 'tag',
        tagKey: tagKey,
        tagValue: tagValue,
        title: title,
        message: message,
        data: data,
      );
    } catch (e) {
      debugPrint('❌ [NotificationService] Error sending notification to tag: $e');
      rethrow;
    }
  }

  /// Send notification when USER creates an order (not implemented - backend recommended)
  Future<void> notifyOrgNewOrder({
    required String orgAccountId,
    required String orderNumber,
    required String customerName,
    required double totalAmount,
    String? currency,
  }) async {
    try {
      debugPrint('🔔 [NotificationService] notifyOrgNewOrder called for org: $orgAccountId');

      // Lookup org owner user id
      final resp = await _supabase
          .from('accounts')
          .select('owner_id')
          .eq('id', orgAccountId)
          .maybeSingle();

      if (resp == null) {
        debugPrint('⚠️ [NotificationService] No account found for orgAccountId=$orgAccountId');
        return;
      }

      final ownerId = resp['owner_id'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        debugPrint('⚠️ [NotificationService] Account has no owner_id: $orgAccountId');
        return;
      }

      final title = 'New Order: #$orderNumber';
      final message = '$customerName placed an order totalling \$${totalAmount.toStringAsFixed(2)}${currency != null ? ' $currency' : ''}';

      await sendToUser(
        userId: ownerId,
        title: title,
        message: message,
        data: {
          'type': 'new_order',
          'order_number': orderNumber,
          'org_account_id': orgAccountId,
        },
      );

      debugPrint('   ✅ Organization notified about new order');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error in notifyOrgNewOrder: $e');
    }
  }

  /// Send notification when ORG assigns order to DELIVERY (not implemented - backend recommended)
  Future<void> notifyDeliveryAssignment({
    required String deliveryAccountId,
    required String orderNumber,
    required String pickupAddress,
    required String deliveryAddress,
  }) async {
    try {
      debugPrint('🔔 [NotificationService] notifyDeliveryAssignment for delivery account: $deliveryAccountId');

      // Lookup delivery account owner (delivery person user id)
      final resp = await _supabase
          .from('accounts')
          .select('owner_id')
          .eq('id', deliveryAccountId)
          .maybeSingle();

      if (resp == null) {
        debugPrint('⚠️ [NotificationService] No account found for deliveryAccountId=$deliveryAccountId');
        return;
      }

      final deliveryUserId = resp['owner_id'] as String?;
      if (deliveryUserId == null || deliveryUserId.isEmpty) {
        debugPrint('⚠️ [NotificationService] Delivery account has no owner_id: $deliveryAccountId');
        return;
      }

      final title = 'Delivery Assigned: #$orderNumber';
      final message = 'Pickup: $pickupAddress → Deliver to: $deliveryAddress';

      await sendToUser(
        userId: deliveryUserId,
        title: title,
        message: message,
        data: {
          'type': 'delivery_assignment',
          'order_number': orderNumber,
          'pickup_address': pickupAddress,
          'delivery_address': deliveryAddress,
        },
      );

      debugPrint('   ✅ Delivery person notified about assignment');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error in notifyDeliveryAssignment: $e');
    }
  }

  /// Send notification when order status changes (to USER) (not implemented - backend recommended)
  Future<void> notifyUserOrderStatus({
    required String userAccountId,
    required String orderNumber,
    required String status,
    String? additionalInfo,
  }) async {
    debugPrint('?? [NotificationService] notifyUserOrderStatus should be handled by backend');
  }

  /// Send notification when delivery status changes (to USER) (not implemented - backend recommended)
  Future<void> notifyUserDeliveryTracking({
    required String userAccountId,
    required String orderNumber,
    required String deliveryStatus,
    double? estimatedMinutes,
  }) async {
    debugPrint('?? [NotificationService] notifyUserDeliveryTracking should be handled by backend');
  }

  /// Get player ID for the current device
  String? get playerId => _playerId;

  /// Check if OneSignal is initialized
  bool get isInitialized => _isInitialized;

  /// Direct OneSignal API call (fallback when edge function not deployed)
  /// ⚠️ WARNING: This exposes REST API key in client - use only for development!
  /// In production, always use Supabase Edge Function instead.
  Future<void> _sendDirectToOneSignal({
    required String type,
    String? userId,
    String? tagKey,
    String? tagValue,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final apiKey = await dotenv.env['ONESIGNAL_REST_API_KEY'];
      final appId = await dotenv.env['ONESIGNAL_APP_ID'];

      if (apiKey == null || appId == null) {
        throw Exception('OneSignal credentials not found in .env file');
      }

      debugPrint('📡 [NotificationService] Calling OneSignal API directly (FALLBACK)');
      debugPrint('   ⚠️ This is insecure - deploy edge function for production!');

      // Build OneSignal payload
      final Map<String, dynamic> payload = {
        'app_id': appId,
        'headings': {'en': title},
        'contents': {'en': message},
      };

      if (data != null) {
        payload['data'] = data;
      }

      // Set target based on type
      if (type == 'user' && userId != null) {
        payload['include_external_user_ids'] = [userId];
      } else if (type == 'tag' && tagKey != null && tagValue != null) {
        payload['filters'] = [
          {
            'field': 'tag',
            'key': tagKey,
            'relation': '=',
            'value': tagValue,
          }
        ];
      } else {
        throw Exception('Invalid notification target parameters');
      }

      debugPrint('   Payload: ${jsonEncode(payload)}');

      // Call OneSignal REST API
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $apiKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = jsonDecode(response.body);
        final recipients = result['recipients'] ?? 0;
        
        debugPrint('✅ [NotificationService] Notification sent directly to OneSignal');
        debugPrint('   Recipients: $recipients');
        debugPrint('   Response: ${response.body}');

        if (recipients == 0) {
          debugPrint('⚠️ [NotificationService] 0 recipients - possible reasons:');
          debugPrint('   - User not logged in with setExternalUserId()');
          debugPrint('   - Device not subscribed to push notifications');
          debugPrint('   - Player ID not synced to database');
        }
      } else {
        debugPrint('❌ [NotificationService] OneSignal API error');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
        throw Exception('OneSignal API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Direct OneSignal call failed: $e');
      rethrow;
    }
  }

  /// Enable or disable ALL notifications for this device
  /// When disabled, device opts out of OneSignal push subscription
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      if (enabled) {
        final hasPermission = await OneSignal.Notifications.requestPermission(true);
        debugPrint('🔔 [NotificationService] Push permission: $hasPermission');
        await OneSignal.User.pushSubscription.optIn();
        debugPrint('✅ [NotificationService] Notifications enabled - push subscription opted-in');
      } else {
        await OneSignal.User.pushSubscription.optOut();
        debugPrint('🚫 [NotificationService] Notifications disabled - push subscription opted-out');
      }
      
      // Save preference to database
      await _saveNotificationPreference(enabled);
    } catch (e) {
      debugPrint('❌ [NotificationService] Error setting notifications enabled=$enabled: $e');
      rethrow;
    }
  }

  /// Save notification preference to database
  Future<void> _saveNotificationPreference(bool enabled) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('accounts')
          .update({'notifications_enabled': enabled})
          .eq('owner_id', user.id);
      
      debugPrint('� [NotificationService] Notification preference saved: $enabled');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Could not save preference: $e');
    }
  }
}
