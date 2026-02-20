import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../widgets/category_header_card.dart';
import '../../widgets/category_grid_view.dart';
import '../../widgets/category_dialog.dart';
import '../../widgets/category_empty_state.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';
import 'electronics_detail_screen.dart';

class ElectronicsScreen extends StatefulWidget {
  const ElectronicsScreen({super.key});

  @override
  State<ElectronicsScreen> createState() => _ElectronicsScreenState();
}

class _ElectronicsScreenState extends State<ElectronicsScreen> {
  List<Category> childCategories = [];
  Map<String, int> productCounts = {};
  Category? electronicsCategory;
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

      // Find the "Electronics" category
      final categories = await CategoryService.getCategoriesForAccount();

      try {
        electronicsCategory = categories.firstWhere(
          (category) => category.name.toLowerCase().trim() == 'electronics',
        );
      } catch (e) {
        try {
          electronicsCategory = categories.firstWhere(
            (category) =>
                category.name.toLowerCase().trim().contains('electronics'),
          );
        } catch (e2) {
          electronicsCategory = null;
        }
      }

      if (electronicsCategory == null) {
        throw Exception(
          'Category not found. Available categories: ${categories.map((c) => '"${c.name}"').join(', ')}',
        );
      }

      // Load child categories
      childCategories = await CategoryService.getChildCategoriesForAccount(
        electronicsCategory!.id,
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
      if (electronicsCategory != null) {
        final updated = await CategoryService.getChildCategoriesForAccount(
          electronicsCategory!.id,
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
        builder: (context) => ElectronicsDetailScreen(
          parentCategoryId: electronicsCategory!.id,
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
        parentCategoryId: electronicsCategory!.id,
        title: 'Add New Category',
        actionButtonText: 'Add Category',
        defaultColors: [
          Colors.indigo,
          Colors.blue,
          Colors.teal,
          Colors.grey,
          Colors.deepPurple,
        ],
        defaultIcons: [
          Icons.devices,
          Icons.phone_android,
          Icons.headset,
          Icons.videogame_asset,
          Icons.tv,
          Icons.watch,
          Icons.electrical_services,
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
        parentCategoryId: electronicsCategory!.id,
        title: 'Edit Category',
        actionButtonText: 'Save',
        defaultColors: [
          Colors.indigo,
          Colors.blue,
          Colors.teal,
          Colors.grey,
          Colors.deepPurple,
        ],
        defaultIcons: [
          Icons.devices,
          Icons.phone_android,
          Icons.headset,
          Icons.videogame_asset,
          Icons.tv,
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
                          'Electronics',
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
                                title: 'Electronics',
                                description:
                                    electronicsCategory?.description ??
                                    'Manage your electronics categories',
                                icon: Icons.devices,
                                gradientColors: [
                                  Colors.indigo.shade600,
                                  Colors.blue.shade400,
                                  Colors.blue.shade300,
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
                                      'Electronics Categories',
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
                                      backgroundColor: Colors.indigo.shade500,
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
                                onCategoryTap: (categoryId) =>
                                    _onChildCategoryTap(categoryId),
                                onEditCategory: _showEditCategoryDialog,
                                productLabel: 'item',
                              )
                            else
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: CategoryEmptyState(
                                  icon: Icons.devices,
                                  title: 'No Electronics Yet',
                                  subtitle: 'Create electronics categories to get started',
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
