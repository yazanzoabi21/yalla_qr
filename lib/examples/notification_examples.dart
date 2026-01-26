/// Example implementations for using OneSignal notifications in your app
/// This file shows how to integrate notifications into your existing screens

import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Example 1: Manually send a test notification
/// You can add this to any screen for testing
class NotificationTestButton extends StatelessWidget {
  const NotificationTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Get current user ID (you already have this in your app)
        final userId = 'user-id-here';
        
        // Send test notification
        await NotificationService().sendToUser(
          userId: userId,
          title: 'Test Notification',
          message: 'This is a test push notification from OneSignal!',
          data: {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test notification sent!')),
          );
        }
      },
      child: const Text('Send Test Notification'),
    );
  }
}

/// Example 2: Show OneSignal status in settings
class OneSignalStatusWidget extends StatelessWidget {
  const OneSignalStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    final playerId = notificationService.playerId;
    final isInitialized = notificationService.isInitialized;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Push Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isInitialized ? Icons.check_circle : Icons.error,
                  color: isInitialized ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isInitialized ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: isInitialized ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (playerId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Device ID: ${playerId.substring(0, 8)}...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Example 3: Notification preferences screen
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _orderUpdates = true;
  bool _deliveryTracking = true;
  bool _promotions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Order Updates'),
            subtitle: const Text('Get notified when your order status changes'),
            value: _orderUpdates,
            onChanged: (value) {
              setState(() => _orderUpdates = value);
              _updateNotificationTags();
            },
          ),
          SwitchListTile(
            title: const Text('Delivery Tracking'),
            subtitle: const Text('Real-time updates on your delivery'),
            value: _deliveryTracking,
            onChanged: (value) {
              setState(() => _deliveryTracking = value);
              _updateNotificationTags();
            },
          ),
          SwitchListTile(
            title: const Text('Promotions & Offers'),
            subtitle: const Text('Special deals and discounts'),
            value: _promotions,
            onChanged: (value) {
              setState(() => _promotions = value);
              _updateNotificationTags();
            },
          ),
        ],
      ),
    );
  }

  void _updateNotificationTags() {
    NotificationService().setUserTags({
      'order_updates': _orderUpdates.toString(),
      'delivery_tracking': _deliveryTracking.toString(),
      'promotions': _promotions.toString(),
    });
  }
}

/// Example 4: Handle notification navigation
/// Add this to your main app widget to handle deep linking from notifications
class NotificationNavigationHandler {
  static void handleNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;
    final orderId = data['order_id'] as String?;

    if (type == null) return;

    switch (type) {
      case 'new_order':
        // Navigate to orders screen for ORG
        Navigator.pushNamed(context, '/org/orders');
        break;

      case 'delivery_assignment':
        // Navigate to delivery home for DELIVERY
        Navigator.pushNamed(context, '/delivery/home');
        break;

      case 'order_status':
      case 'delivery_tracking':
        // Navigate to order tracking for USER
        if (orderId != null) {
          Navigator.pushNamed(
            context,
            '/tracking',
            arguments: {'orderId': orderId},
          );
        }
        break;

      default:
        debugPrint('Unknown notification type: $type');
    }
  }
}

/// Example 5: Add notification setup to login flow
/// Call this after successful login
Future<void> setupNotificationsAfterLogin(String userId, String role) async {
  final notificationService = NotificationService();

  // Set external user ID
  await notificationService.setExternalUserId(userId);

  // Set user role tags
  await notificationService.setUserTags({
    'role': role,
    'user_id': userId,
  });

  debugPrint('✅ OneSignal configured for user: $userId ($role)');
}

/// Example 6: Clear notifications on logout
/// Call this when user logs out
Future<void> clearNotificationsOnLogout() async {
  final notificationService = NotificationService();
  await notificationService.clearExternalUserId();
  
  debugPrint('✅ OneSignal user data cleared');
}
