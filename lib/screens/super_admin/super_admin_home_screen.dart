import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'platform_statistics_screen.dart';
import 'account_categories_control_screen.dart';
import '../auth/welcome_screen.dart';
import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';

class SuperAdminHomeScreen extends StatefulWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  State<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends State<SuperAdminHomeScreen> {
  bool _isAuthorized = false;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 1; // Start with Account Categories Control

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
          _error = 'Please login to access this page.';
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final loginContext = prefs.getString('login_context');
      if (loginContext == 'SUPER_ADMIN') {
        setState(() {
          _isAuthorized = true;
          _isLoading = false;
        });
        return;
      }

      final accounts = await Supabase.instance.client
          .from('accounts')
          .select('role')
          .eq('owner_id', user.id);

      final hasSuperAdmin = (accounts as List)
          .any((acc) => acc['role'] == 'SUPER ADMIN');

      setState(() {
        _isAuthorized = hasSuperAdmin;
        _isLoading = false;
        _error = hasSuperAdmin ? null : 'Access denied.';
      });
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
        _error = 'Failed to verify access.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Super Admin Console'),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Super Admin Console'),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Access denied.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final headerTextColor = isDark ? theme.colorScheme.onSurface : Colors.white;

    final List<Widget> screens = [
      const PlatformStatisticsScreen(),
      const AccountCategoriesControlScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Super Admin Console',
          style: TextStyle(
            color: headerTextColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark 
            ? theme.colorScheme.surfaceVariant 
            : theme.colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.red,
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              // Show a simple loading indicator while logging out
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final auth = AuthService(Supabase.instance.client);
                await auth.signOut();
                await SecureStorageService.clearSession();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('login_context');
                await prefs.remove('last_scanned_qr');
              } catch (e) {
                // ignore errors but log
                debugPrint('Error during super-admin logout: $e');
              } finally {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // close loading
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_rounded),
            label: 'Platform Statistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_rounded),
            label: 'Account Categories',
          ),
        ],
      ),
    );
  }
}
