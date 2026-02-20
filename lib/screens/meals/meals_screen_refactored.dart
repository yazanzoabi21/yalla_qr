import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../widgets/category_header_card.dart';
import '../../widgets/category_grid_view.dart';
import '../../widgets/category_dialog.dart';
import '../../widgets/category_empty_state.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';
import 'meal_detail_screen.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  List<Category> childCategories = [];
  Map<String, int> productCounts = {};
  Category? mealsCategory;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Find the "Meals" category
      final categories = await CategoryService.getCategoriesForAccount();
      
      try {
        mealsCategory = categories.firstWhere((category) => 
          category.name.toLowerCase().trim() == 'meals'
        );
      } catch (e) {
        try {
          mealsCategory = categories.firstWhere((category) => 
            category.name.toLowerCase().trim().contains('meals')
          );
        } catch (e2) {
          mealsCategory = null;
        }
      }
      
      if (mealsCategory == null) {
        throw Exception('Category not found. Available categories: ${categories.map((c) => '"${c.name}"').join(', ')}');
      }

      // Load child categories
      childCategories = await CategoryService.getChildCategoriesForAccount(mealsCategory!.id);
      
      // Load product counts
      await _loadProductCounts();
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadProductCounts() async {
    try {
      Map<String, int> counts = {};
      for (var childCategory in childCategories) {
        final products = await ProductService.getProductsByCategory(childCategory.id);
        counts[childCategory.id] = products.length;
      }
      setState(() {
        productCounts = counts;
      });
    } catch (e) {
      debugPrint('Error loading product counts: $e');
    }
  }

  Future<void> _refreshChildCategories() async {
    try {
      if (mealsCategory != null) {
        final updated = await CategoryService.getChildCategoriesForAccount(mealsCategory!.id);
        await _loadProductCounts();
        setState(() {
          childCategories = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing categories: $e');
    }
  }

  void _navigateToMealDetail(Category childCategory) {
    final meal = {
      'id': childCategory.id,
      'name': childCategory.name,
      'description': childCategory.description ?? 'No description',
      'category_id': mealsCategory?.id,
      'color': childCategory.color,
      'icon': childCategory.icon,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealDetailScreen(
          meal: meal,
          onProductAdded: (product) {},
        ),
      ),
    ).then((_) async {
      await _loadProductCounts();
    });
  }

  void _showAddMealDialog() {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        parentCategoryId: mealsCategory!.id,
        title: 'Add New Meal',
        actionButtonText: 'Add Meal',
        defaultColors: [
          Colors.deepOrange,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.red,
          Colors.teal,
          Colors.pink,
          Colors.indigo,
        ],
        defaultIcons: [
          Icons.restaurant,
          Icons.breakfast_dining,
          Icons.lunch_dining,
          Icons.dinner_dining,
          Icons.local_pizza,
          Icons.cake,
          Icons.coffee,
          Icons.icecream,
          Icons.fastfood,
          Icons.set_meal,
          Icons.restaurant_menu,
          Icons.egg_alt,
          Icons.bakery_dining,
          Icons.rice_bowl,
          Icons.soup_kitchen,
          Icons.ramen_dining,
          Icons.tapas,
          Icons.wine_bar,
          Icons.local_bar,
          Icons.local_cafe,
          Icons.emoji_food_beverage,
          Icons.outdoor_grill,
          Icons.kitchen,
          Icons.microwave,
          Icons.blender,
          Icons.dining,
          Icons.brunch_dining,
          Icons.nightlife,
          Icons.food_bank,
          Icons.local_dining,
        ],
        onSuccess: () {
          _refreshChildCategories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showEditMealDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        category: category,
        parentCategoryId: mealsCategory!.id,
        title: 'Edit Meal',
        actionButtonText: 'Save Changes',
        defaultColors: [
          Colors.deepOrange,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.red,
          Colors.teal,
          Colors.pink,
          Colors.indigo,
        ],
        defaultIcons: [
          Icons.restaurant,
          Icons.breakfast_dining,
          Icons.lunch_dining,
          Icons.dinner_dining,
          Icons.local_pizza,
          Icons.cake,
          Icons.coffee,
          Icons.icecream,
        ],
        onSuccess: () {
          _refreshChildCategories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: Navbar(
          showMenuButton: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading meals...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Fixed header with back button
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              borderRadius: BorderRadius.circular(20),
              child: Icon(
                Icons.arrow_back,
                size: 25,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Meals',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Scrollable content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Section using CategoryHeaderCard
                SliverToBoxAdapter(
                  child: CategoryHeaderCard(
                    title: 'Meals',
                    description: mealsCategory?.description ?? 'Manage your meal categories',
                    icon: Icons.restaurant,
                    gradientColors: [
                      Colors.deepOrange.shade600,
                      Colors.deepOrange.shade400,
                      Colors.deepOrange.shade300,
                    ],
                  ),
                ),

                // Section title and add button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32, bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Meal Categories',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        FloatingActionButton(
                          onPressed: _showAddMealDialog,
                          backgroundColor: Colors.deepOrange.shade500,
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid of child categories using CategoryGridView
                if (childCategories.isNotEmpty)
                  CategoryGridView(
                    categories: childCategories,
                    productCounts: productCounts,
                    onCategoryTap: (categoryId) {
                      final category = childCategories.firstWhere((c) => c.id == categoryId);
                      _navigateToMealDetail(category);
                    },
                    onEditCategory: _showEditMealDialog,
                    productLabel: 'product',
                  )
                else
                  const SliverFillRemaining(
                    child: CategoryEmptyState(
                      icon: Icons.restaurant_menu_outlined,
                      title: 'No Meals Yet',
                      subtitle: 'Create meal categories to get started',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
