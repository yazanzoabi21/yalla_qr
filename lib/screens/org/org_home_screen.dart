import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build the screens for each tab
    final List<Widget> screens = [
      OrganizationCategoriesScreen(
        account: widget.account,
        categories: widget.categories,
      ),
      OrgStatisticsScreen(
        account: widget.account,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : theme.colorScheme.surface,
          gradient: LinearGradient(
            colors: isDark
                ? [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceVariant,
                  ]
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
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
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
