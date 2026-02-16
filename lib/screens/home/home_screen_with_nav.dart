import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../org/org_statistics_screen.dart';
import 'home_screen.dart';

/// Wrapper for HomeScreen that adds bottom navigation for organization owners
/// Allows switching between Home (categories) and Statistics tabs
class HomeScreenWithNav extends StatefulWidget {
  const HomeScreenWithNav({super.key});

  @override
  State<HomeScreenWithNav> createState() => _HomeScreenWithNavState();
}

class _HomeScreenWithNavState extends State<HomeScreenWithNav> {
  int _currentIndex = 0;
  Account? _orgAccount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrgAccount();
  }

  Future<void> _loadOrgAccount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('accounts')
          .select()
          .eq('owner_id', user.id)
          .eq('role', 'ORG')
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _orgAccount = Account.fromJson(response);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading org account: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If no org account found, just show regular HomeScreen without nav
    if (_orgAccount == null) {
      return const HomeScreen();
    }

    // Build the screens for each tab
    final List<Widget> screens = [
      const HomeScreen(),
      OrgStatisticsScreen(
        account: _orgAccount!,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.cardColor,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          selectedFontSize: 14,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 26),
              activeIcon: Icon(Icons.home, size: 26),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined, size: 26),
              activeIcon: Icon(Icons.analytics, size: 26),
              label: 'Statistics',
            ),
          ],
        ),
      ),
    );
  }
}
