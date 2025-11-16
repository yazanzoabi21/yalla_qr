import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/search/search_results_screen.dart';
import '../services/auth_service.dart';
import 'dart:async';
import '../utils/navigation_helper.dart';
import '../services/secure_storage_service.dart';

class Navbar extends StatefulWidget implements PreferredSizeWidget {
  final bool showLoginButton;

  const Navbar({super.key, this.showLoginButton = false});

  @override
  State<Navbar> createState() => _NavbarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}

class _NavbarState extends State<Navbar> {
  bool _isAuthenticated = false;
  late final AuthService _authService;
  late final StreamSubscription<AuthState> _authSubscription;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authService = AuthService(Supabase.instance.client);
    _checkAuthenticationStatus();

    // Listen to auth state changes with proper subscription management
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _isAuthenticated = data.session != null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _checkAuthenticationStatus() {
    setState(() {
      _isAuthenticated = _authService.isAuthenticated();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // IconButton(
            //   icon: const Icon(Icons.arrow_back, color: Colors.grey),
            //   onPressed: () {
            //     Navigator.pop(context);
            //   },
            // ),
            Expanded(
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
                onTap: () {
                  // Navigate to search screen when tapping the search field
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchResultsScreen(
                        initialQuery: _searchController.text,
                        categoryId: _getCurrentCategoryId(context),
                      ),
                    ),
                  );
                },
                readOnly: true, // Make it read-only so it only acts as a button
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.grey),
              onSelected: (String value) {
                _handleMenuSelection(context, value);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'contact',
                  child: ListTile(
                    leading: Icon(Icons.contact_support),
                    title: Text('Contact'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'feedback',
                  child: ListTile(
                    leading: Icon(Icons.feedback),
                    title: Text('Feedback'),
                  ),
                ),
                if (_isAuthenticated) ...[
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                    ),
                  ),
                ],
                const PopupMenuItem<String>(
                  value: 'about',
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('About'),
                  ),
                ),
                if (_isAuthenticated) ...[
                  const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ] else if (widget.showLoginButton) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'login',
                    child: ListTile(
                      leading: Icon(Icons.login),
                      title: Text('Login'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) async {
    switch (value) {
      case 'contact':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact selected')));
        break;
      case 'feedback':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Feedback selected')));
        break;
      case 'settings':
        if (_isAuthenticated) {
          String? currentCategory = _getCurrentCategory(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsScreen(categoryName: currentCategory),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to access settings')),
          );
        }
        break;
      case 'about':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('About selected')));
        break;
      case 'login':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        break;
      case 'logout':
        try {
          // Determine the current category from the current route
          String? currentCategory = _getCurrentCategory(context);
          
          debugPrint('🚪 Logging out user...');
          
          // Use the enhanced logout with complete session clearing
          await _authService.signOut();
          // Clear session flag from secure storage
          await SecureStorageService.clearSession();
          
          debugPrint('✅ Session cleared from storage');
          
          // Verify logout was successful
          final sessionAfterLogout = _authService.getCurrentSession();
          if (sessionAfterLogout != null) {
            debugPrint('⚠️ Session still exists, forcing auth reset');
            await _authService.forceAuthReset();
          }
          
          // Force update the authentication status
          setState(() {
            _isAuthenticated = false;
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Successfully logged out'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Add a small delay to ensure logout is complete
            await Future.delayed(const Duration(milliseconds: 500));

            // Navigate to login screen with the current category as intended destination
            if (!mounted) return;
            if (context.mounted) {
              NavigationHelper.navigateToLogin(context, intendedDestination: currentCategory);
            }
          }
        } catch (e) {
          // Try force reset as a last resort
          try {
            await _authService.forceAuthReset();
            setState(() {
              _isAuthenticated = false;
            });
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Force logout successful'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
              
              // Still try to preserve the category context even in error case
              String? currentCategory = _getCurrentCategory(context);
              if (!mounted) return;
              if (context.mounted) {
                NavigationHelper.navigateToLogin(context, intendedDestination: currentCategory);
              }
            }
          } catch (forceError) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to logout: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        break;
    }
  }

  /// Determine the current category based on the current route
  String? _getCurrentCategory(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route?.settings.name != null) {
      final routeName = route!.settings.name!;
      
      // Extract category from route name
      switch (routeName) {
        case '/meals':
          return 'meals';
        case '/gym':
          return 'gym';
        case '/home':
        case '/login':
          return null; // These are not category-specific
        default:
          // Fallback for route names that contain category info
          if (routeName.contains('meals') || routeName.contains('Meals')) {
            return 'meals';
          } else if (routeName.contains('gym') || routeName.contains('Gym')) {
            return 'gym';
          }
          break;
      }
    }
    
    return null; // Unknown category, will go to home
  }

  /// Get the current category ID for search filtering
  String? _getCurrentCategoryId(BuildContext context) {
    final categoryName = _getCurrentCategory(context);
    // You may need to map category names to IDs from your database
    // For now, we'll return the name as it might match the ID
    return categoryName;
  }
}
