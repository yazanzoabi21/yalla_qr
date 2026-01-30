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
        debugPrint('🔔 [NotificationService] Push subscription changed at $timestamp');
        debugPrint('   optedIn: ${state.current.optedIn}');
        debugPrint('   token: ${state.current.token}');
        final id = state.current.id;
        debugPrint('   id: $id');
        if (id != null && id.isNotEmpty) {
          _playerId = id;
          debugPrint('✅ [NotificationService] Player ID received from OneSignal backend!');
          await _updatePlayerIdInDatabase();
        } else if (state.current.optedIn) {
          // ID not available yet, but user is opted in - poll for it
          debugPrint('⏳ [NotificationService] Subscription opted in but no ID yet');
          debugPrint('   Waiting for OneSignal backend response...');
          _pollForPlayerId();
        }
      });

      debugPrint('?? [NotificationService] Player ID: $_playerId');

      // Listen to foreground notifications
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('?? [NotificationService] Foreground notification received');
        debugPrint('   Title: ${event.notification.title}');
        debugPrint('   Body: ${event.notification.body}');

        if (enableInAppNotifications) {
          event.notification.display();
        }
      });

      // Listen to notification clicks
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('?? [NotificationService] Notification clicked');
        debugPrint('   Data: ${event.notification.additionalData}');

        _handleNotificationClick(event.notification);
      });

      _isInitialized = true;
      debugPrint('? [NotificationService] OneSignal initialized successfully');
    } catch (e) {
      debugPrint('? [NotificationService] Initialization error: $e');
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
        debugPrint('⚠️ [NotificationService] Cannot update: user=${user?.id}, playerId=$_playerId');
        return;
      }

      debugPrint('🔔 [NotificationService] Saving player ID for user: ${user.id}');
      debugPrint('   Player ID: $_playerId');

      final deviceType = _getDeviceType();
      debugPrint('   Device Type: $deviceType');

      // Use upsert with onConflict to handle both insert and update
      // This will insert if new, or update existing record if player_id already exists
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

        debugPrint('✅ [NotificationService] Player ID saved successfully');
        
        // Log all active devices for this user (for debugging)
        try {
          final userDevices = await _supabase
              .from('user_player_ids')
              .select('player_id, device_type, created_at')
              .eq('user_id', user.id)
              .eq('is_active', true)
              .order('created_at', ascending: false);
          
          debugPrint('📱 [NotificationService] Total active devices: ${userDevices.length}');
          for (var i = 0; i < userDevices.length; i++) {
            final device = userDevices[i];
            debugPrint('   Device ${i + 1}: ${device['device_type']} - ${device['player_id']?.substring(0, 8)}...');
          }
        } catch (queryError) {
          debugPrint('⚠️ [NotificationService] Could not query user devices: $queryError');
        }
      } catch (upsertError) {
        debugPrint('❌ [NotificationService] Upsert failed: $upsertError');
        debugPrint('   This might be an RLS policy issue. Trying direct insert...');
        
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
          debugPrint('✅ [NotificationService] Fallback insert succeeded');
        } catch (insertError) {
          debugPrint('❌ [NotificationService] Fallback insert also failed: $insertError');
          rethrow;
        }
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
      // If pushSubscription hasn't populated yet, continue polling until listener or SDK populates it
      // debugPrint('⏳ [NotificationService] Poll attempt $attempt/30:');
      debugPrint('   Player ID: ${playerId ?? "null"}');
      debugPrint('   Token available: ${token != null && token.isNotEmpty}');
      
      if (playerId != null && playerId.isNotEmpty) {
        _playerId = playerId;
        debugPrint('✅ [NotificationService] Player ID acquired after $attempt attempts (${attempt * 2} seconds)');
        await _updatePlayerIdInDatabase();
        return; // Success, stop polling
      }
    }
    
    debugPrint('❌ [NotificationService] Failed to get player ID after 30 attempts (60 seconds)');
    debugPrint('   This device may have network issues or OneSignal backend delays');
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

      // Call Supabase Edge Function to send notification
      // This is the CORRECT way - backend sends to OneSignal, not client
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
        debugPrint('✅ [NotificationService] Notification sent successfully');
        debugPrint('   Response: ${response.data}');
      } else {
        debugPrint('❌ [NotificationService] Failed to send notification');
        debugPrint('   Status: $status');
        debugPrint('   Error: ${response.data}');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Error sending notification: $e');
      rethrow;
    }
  }

  /// Send notification to users with specific tags (e.g., role: 'DELIVERY')
  /// Uses Supabase Edge Function to securely call OneSignal REST API
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

      // Call Supabase Edge Function to send notification
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
        debugPrint('✅ [NotificationService] Notification sent to tag successfully');
        debugPrint('   Response: ${response.data}');
      } else {
        debugPrint('❌ [NotificationService] Failed to send notification to tag');
        debugPrint('   Status: $status');
        debugPrint('   Error: ${response.data}');
      }
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
      final message = '$customerName placed an order totalling ${totalAmount.toStringAsFixed(2)}${currency != null ? ' $currency' : ''}';

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
}
