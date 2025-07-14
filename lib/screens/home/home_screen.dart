import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_item.dart';
import '../../widgets/navbar.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../utils/navigation_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? lastClicked;
  List<Category> categories = [];
  bool isLoadingCategories = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadLastClicked();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      setState(() {
        isLoadingCategories = true;
        errorMessage = null;
      });

      final fetchedCategories = await CategoryService.getCategories();

      if (!mounted) return;

      setState(() {
        categories = fetchedCategories;
        isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load categories: ${e.toString()}';
        isLoadingCategories = false;
      });
    }
  }

  Future<void> loadLastClicked() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTitle = prefs.getString('lastClicked');

    if (!mounted) return;
    if (savedTitle != null) {
      setState(() {
        lastClicked = savedTitle;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Last Clicked: $savedTitle')));
    }
  }

  Future<void> updateLastClicked(String title) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastClicked', title);

    if (!mounted) return;
    setState(() {
      lastClicked = title;
    });

    String categoryName = title.toLowerCase();

    // Only require authentication for actual categories (not "Coming Soon")
    if (categoryName != 'coming soon') {
      // Navigate to login screen for categories - login/signup will handle direct navigation to category
      NavigationHelper.navigateToLogin(context, intendedDestination: categoryName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: const Navbar(),
      body: Padding(padding: const EdgeInsets.all(12.0), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (isLoadingCategories) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading categories...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadCategories,
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.6, // Makes cards taller (width/height ratio)
        children: _buildGridItems(),
      ),
    );
  }

  List<Widget> _buildGridItems() {
    List<Widget> items = [];

    // Add database categories first
    for (Category category in categories) {
      items.add(
        HomeItem(
          title: category.name,
          color: category.color,
          imagePath: category.imagePath,
          lastClicked: lastClicked,
          onTap: updateLastClicked,
        ),
      );
    }

    // Fill remaining slots with "Coming Soon" cards to maintain the 2x4 grid
    final totalSlots = 8;
    final remainingSlots = totalSlots - categories.length;

    final List<Color> comingSoonColors = [
      Colors.indigo,
      Colors.amber,
      Colors.pink,
      Colors.lime,
      Colors.cyan,
      Colors.brown,
    ];

    for (int i = 0; i < remainingSlots && i < comingSoonColors.length; i++) {
      items.add(
        HomeItem(
          title: 'Coming Soon',
          color: comingSoonColors[i],
          lastClicked: lastClicked,
          onTap: updateLastClicked,
        ),
      );
    }

    return items;
  }
}
