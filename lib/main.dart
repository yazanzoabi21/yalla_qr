import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash_screen.dart';
import 'services/theme_service.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/client/client_categories_screen.dart';
import 'screens/delivery/delivery_home_screen.dart';
import 'screens/super_admin/super_admin_home_screen.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'utils/supabase_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load .env file for dev configuration
    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env file loaded');
    
    await Supabase.initialize(
      url: 'https://fhsqvuyzoptmkpapxyfl.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoc3F2dXl6b3B0bWtwYXB4eWZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyODY5NjcsImV4cCI6MjA2Njg2Mjk2N30._ERJc5TyJr_Q-KL06FjfpR05mtPm5o12m9mqFsfugVs',
    );
    debugPrint(
      'Startup currentSession user: ${Supabase.instance.client.auth.currentUser?.email}',
    );
    await SupabaseSetup.initializeStorage();

    // Initialize cart service
    await CartService().initialize();
    debugPrint('✅ Cart service initialized');

    // Initialize OneSignal with your App ID
    await NotificationService().initialize(
      appId: '7bf37a7f-afd5-4a7d-b5e7-b3a7257392bf',
      enableInAppNotifications: true,
    );
    debugPrint('✅ OneSignal initialized');
    // Initialize theme service (loads saved preference)
    await ThemeService.instance.init();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Request location permission when app is ready with context
    _initializeLocation();
    
    // Set OneSignal external user ID when user logs in
    _setupAuthListener();
  }

  /// Setup auth listener to set OneSignal external user ID
  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((authState) async {
      final user = authState.session?.user;
      
      if (user != null) {
        debugPrint('🔐 [Auth] User logged in: ${user.email}');
        
        // User logged in - set external user ID
        // Player ID will be automatically saved when OneSignal subscription is ready
        // via the subscription listener in NotificationService
        await NotificationService().setExternalUserId(user.id);
        
        // Set user tags based on their role
        try {
          final accounts = await Supabase.instance.client
              .from('accounts')
              .select('role, name')
              .eq('owner_id', user.id);
          
          if (accounts.isNotEmpty) {
            // Get primary account (first one, or ORG if exists)
            var primaryAccount = accounts.first;
            for (var account in accounts) {
              if (account['role'] == 'ORG') {
                primaryAccount = account;
                break;
              }
            }
            
            final role = primaryAccount['role'] as String?;
            final name = primaryAccount['name'] as String?;
            
            await NotificationService().setUserTags({
              'role': role ?? 'USER',
              'user_id': user.id,
              if (name != null) 'name': name,
            });
            
            debugPrint('✅ OneSignal user tags set: role=$role, userId=${user.id}');
          }
        } catch (e) {
          debugPrint('⚠️ Error setting OneSignal tags: $e');
        }
      } else {
        // User logged out - clear external user ID
        await NotificationService().clearExternalUserId();
        debugPrint('✅ OneSignal external user ID cleared');
      }
    });
  }

  /// Initialize location services when app context is available
  Future<void> _initializeLocation() async {
    try {
      // Check if location services are enabled
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      
      if (!isLocationServiceEnabled) {
        debugPrint('📍 [App] Location services are disabled');
        if (mounted) {
          _showLocationDialog(
            'Location Services Disabled',
            'Please enable location services to use delivery features.',
            onEnable: () {
              Geolocator.openLocationSettings();
            },
          );
        }
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        debugPrint('📍 [App] Requesting location permission...');
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ [App] Location permission denied by user');
          if (mounted) {
            _showLocationDialog(
              'Location Permission Needed',
              'This app needs location access to match you with nearby delivery services.',
              onEnable: () {
                _initializeLocation(); // Retry
              },
            );
          }
        } else if (permission == LocationPermission.deniedForever) {
          debugPrint('⚠️ [App] Location permission permanently denied');
          if (mounted) {
            _showLocationDialog(
              'Location Permission Denied',
              'Location permission is permanently denied. Please enable it in app settings.',
              onEnable: () {
                Geolocator.openAppSettings();
              },
            );
          }
        } else {
          debugPrint('✅ [App] Location permission granted');
        }
      } else if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [App] Location permission permanently denied');
        if (mounted) {
          _showLocationDialog(
            'Location Permission Needed',
            'Location permission is required. Please enable it in app settings.',
            onEnable: () {
              Geolocator.openAppSettings();
            },
          );
        }
      } else {
        debugPrint('✅ [App] Location permission already granted');
      }
    } catch (e) {
      debugPrint('❌ [App] Error initializing location: $e');
    }
  }

  /// Show location permission dialog
  void _showLocationDialog(
    String title,
    String message, {
    VoidCallback? onEnable,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onEnable?.call();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Enable'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.modeNotifier,
      builder: (context, mode, _) {
        final lightScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light);
        final darkScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Yalla QR',
          theme: ThemeData.light().copyWith(
            colorScheme: lightScheme,
            scaffoldBackgroundColor: lightScheme.background,
            cardColor: lightScheme.surface,
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.primary,
              foregroundColor: lightScheme.onPrimary,
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: lightScheme.surfaceVariant,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: darkScheme,
            scaffoldBackgroundColor: darkScheme.background,
            cardColor: darkScheme.surface,
            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.surface,
              foregroundColor: darkScheme.onSurface,
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: darkScheme.surfaceVariant,
            ),
          ),
          themeMode: mode,
          home: _showSplash
              ? SplashScreen(
                  onSplashComplete: () {
                    setState(() {
                      _showSplash = false;
                    });
                  },
                )
              : const WelcomeScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
            '/client': (context) => const ClientCategoriesScreen(),
            '/delivery': (context) => const DeliveryHomeScreen(),
            '/super-admin': (context) => const SuperAdminHomeScreen(),
          },
        );
      },
    );
  }
}
