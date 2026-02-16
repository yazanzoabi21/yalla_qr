import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _orderUpdates = true;
  bool _promotions = false;
  bool _loading = true;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notif_enabled') ?? true;
      _orderUpdates = prefs.getBool('notif_order_updates') ?? true;
      _promotions = prefs.getBool('notif_promotions') ?? false;
      _loading = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', enabled);
    setState(() => _notificationsEnabled = enabled);
    await _notificationService.setNotificationsEnabled(enabled);
  }

  Future<void> _savePrefsAndTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_order_updates', _orderUpdates);
    await prefs.setBool('notif_promotions', _promotions);

    await _notificationService.setUserTags({
      'order_updates': _orderUpdates.toString(),
      'promotions': _promotions.toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerId = _notificationService.playerId;
    final isInitialized = _notificationService.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        // if (playerId != null) ...[
                        //   const SizedBox(height: 8),
                        //   Text(
                        //     'Device ID: ${playerId.substring(0, 8)}... ',
                        //     style: Theme.of(context).textTheme.bodySmall,
                        //   ),
                        // ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Notifications'),
                        subtitle: const Text('Turn all notifications on or off'),
                        value: _notificationsEnabled,
                        onChanged: (value) async {
                          await _setNotificationsEnabled(value);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Order Updates'),
                        subtitle: const Text(
                          'Get notified when your order status changes',
                        ),
                        value: _orderUpdates,
                        onChanged: !_notificationsEnabled
                            ? null
                            : (value) async {
                                setState(() => _orderUpdates = value);
                                await _savePrefsAndTags();
                              },
                      ),
                      SwitchListTile(
                        title: const Text('Promotions & Offers'),
                        subtitle: const Text('Deals and discounts'),
                        value: _promotions,
                        onChanged: !_notificationsEnabled
                            ? null
                            : (value) async {
                                setState(() => _promotions = value);
                                await _savePrefsAndTags();
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
