import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../client/organization_categories_screen.dart';
import 'org_statistics_screen.dart';

class OrgHomeScreen extends StatefulWidget {
  final Account account;
  final List<Category> categories;

  const OrgHomeScreen({
    super.key,
    required this.account,
    required this.categories,
  });

  @override
  State<OrgHomeScreen> createState() => _OrgHomeScreenState();
}

class _OrgHomeScreenState extends State<OrgHomeScreen> {
  int _currentIndex = 0;
  bool _showStatistics = true;

  @override
  void initState() {
    super.initState();
    _loadLoginContext();
  }

  Future<void> _loadLoginContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ctx = prefs.getString('login_context');
      setState(() {
        _showStatistics = ctx == 'ORG';
      });
    } catch (e) {
      debugPrint('Error loading login context: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If statistics shouldn't be shown (non-ORG users), render a simple scaffold
    // with only the categories screen and no BottomNavigationBar. This avoids
    // the BottomNavigationBar assertion which requires at least two items.
    if (!_showStatistics) {
      return Scaffold(
        body: OrganizationCategoriesScreen(
          account: widget.account,
          categories: widget.categories,
        ),
      );
    }

    // Build the screens for each tab (Statistics only when account is ORG)
    final List<Widget> screens = [
      OrganizationCategoriesScreen(
        account: widget.account,
        categories: widget.categories,
      ),
      OrgStatisticsScreen(account: widget.account),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : theme.colorScheme.surface,
          gradient: LinearGradient(
            colors: isDark
                ? [theme.colorScheme.surface, theme.colorScheme.surfaceVariant]
                : [
                    theme.colorScheme.surface,
                    theme.colorScheme.primary.withOpacity(0.06),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? theme.colorScheme.outline.withOpacity(0.3)
                  : theme.dividerColor,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(isDark ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex.clamp(0, screens.length - 1),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.textTheme.bodyMedium?.color?.withOpacity(
            0.5,
          ),
          selectedFontSize: 14,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
