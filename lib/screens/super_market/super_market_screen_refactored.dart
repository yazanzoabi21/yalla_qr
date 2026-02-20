import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../widgets/category_header_card.dart';
import '../../widgets/category_grid_view.dart';
import '../../widgets/category_dialog.dart';
import '../../widgets/category_empty_state.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';
import 'super_market_detail_screen.dart';

class SuperMarketScreen extends StatefulWidget {
  const SuperMarketScreen({super.key});

  @override
  State<SuperMarketScreen> createState() => _SuperMarketScreenState();
}

class _SuperMarketScreenState extends State<SuperMarketScreen> {
  List<Category> childCategories = [];
  Map<String, int> productCounts = {};
  Category? superMarketCategory;
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

      // Find the "Super Market" category
      final categories = await CategoryService.getCategoriesForAccount();

      try {
        superMarketCategory = categories.firstWhere(
          (category) => category.name.toLowerCase().trim() == 'super market',
        );
      } catch (e) {
        try {
          superMarketCategory = categories.firstWhere(
            (category) =>
                category.name.toLowerCase().trim().contains('super market'),
          );
        } catch (e2) {
          superMarketCategory = null;
        }
      }

      if (superMarketCategory == null) {
        throw Exception(
          'Category not found. Available categories: ${categories.map((c) => '"${c.name}"').join(', ')}',
        );
      }

      // Load child categories
      childCategories = await CategoryService.getChildCategoriesForAccount(
        superMarketCategory!.id,
      );

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
        final products = await ProductService.getProductsByCategory(
          childCategory.id,
        );
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
      if (superMarketCategory != null) {
        final updated = await CategoryService.getChildCategoriesForAccount(
          superMarketCategory!.id,
        );
        await _loadProductCounts();
        setState(() {
          childCategories = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing categories: $e');
    }
  }

  void _onChildCategoryTap(String categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SuperMarketDetailScreen(
          parentCategoryId: superMarketCategory!.id,
          childCategoryId: categoryId,
        ),
      ),
    ).then((result) {
      _loadProductCounts();
    });
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        parentCategoryId: superMarketCategory!.id,
        title: 'Add New Category',
        actionButtonText: 'Add Category',
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
          Icons.shopping_cart,
          Icons.shopping_bag,
          Icons.store,
          Icons.local_grocery_store,
          Icons.restaurant,
          Icons.local_cafe,
          Icons.cleaning_services,
          Icons.local_pharmacy,
        ],
        onSuccess: () {
          _refreshChildCategories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        category: category,
        parentCategoryId: superMarketCategory!.id,
        title: 'Edit Category',
        actionButtonText: 'Save',
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
          Icons.shopping_cart,
          Icons.shopping_bag,
          Icons.store,
          Icons.local_grocery_store,
          Icons.restaurant,
          Icons.local_cafe,
          Icons.cleaning_services,
          Icons.local_pharmacy,
        ],
        onSuccess: () {
          _refreshChildCategories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category updated successfully!'),
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: Navbar(showMenuButton: false),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Fixed header with back button
                    Row(
                      children: [
                        InkWell(
                          onTap: () =>
                              Navigator.pushReplacementNamed(context, '/home'),
                          borderRadius: BorderRadius.circular(20),
                          child: Icon(
                            Icons.arrow_back,
                            size: 25,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Super Market',
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
                                title: 'Super Market',
                                description:
                                    superMarketCategory?.description ??
                                    'Manage your grocery and retail products',
                                icon: Icons.local_grocery_store,
                                gradientColors: [
                                  Colors.green.shade600,
                                  Colors.green.shade400,
                                  Colors.green.shade300,
                                ],
                              ),
                            ),

                            // Section title and add button
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 32,
                                  bottom: 20,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Categories',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    FloatingActionButton(
                                      onPressed: _showAddCategoryDialog,
                                      backgroundColor: Colors.green.shade500,
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                      ),
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
                                onCategoryTap: _onChildCategoryTap,
                                onEditCategory: _showEditCategoryDialog,
                                backgroundImagePath:
                                    'assets/images/SuperMarket.png',
                                productLabel: 'product',
                              )
                            else
                              const SliverFillRemaining(
                                child: CategoryEmptyState(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'No Categories Yet',
                                  subtitle: 'Create categories to get started',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
