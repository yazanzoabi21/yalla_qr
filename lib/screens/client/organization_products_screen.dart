import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/navbar.dart';
import 'organization_category_products_screen.dart';

/// Screen to display an organization's products organized by categories
/// Shows the same design as the category screens (e.g., MealsScreen)
class OrganizationProductsScreen extends StatefulWidget {
  final Account account;
  
  const OrganizationProductsScreen({
    super.key,
    required this.account,
  });

  @override
  State<OrganizationProductsScreen> createState() => _OrganizationProductsScreenState();
}

class _OrganizationProductsScreenState extends State<OrganizationProductsScreen> {
  Map<String, int> productCounts = {};
  List<Category> categories = []; // Changed to list to support multiple categories
  List<Category> subCategories = [];
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

      // Get the categories for this organization via account_categories junction table
      try {
        final categoryRelations = await Supabase.instance.client
            .from('account_categories')
            .select('category_id')
            .eq('account_id', widget.account.id)
            .eq('is_hidden', false);
        
        final categoryIds = (categoryRelations as List)
            .map((item) => item['category_id'] as String)
            .toList();
        
        // Fetch the actual category details
        final categoriesList = <Category>[];
        for (var categoryId in categoryIds) {
          final category = await CategoryService.getCategoryById(categoryId);
          if (category != null) {
            categoriesList.add(category);
          }
        }
        
        categories = categoriesList;
      } catch (e) {
        debugPrint('Failed to fetch categories for account ${widget.account.id}: $e');
      }

      // Get child categories for all parent categories
      final allSubCategories = <Category>[];
      for (var parentCategory in categories) {
        final children = await CategoryService.getChildCategoriesForSpecificAccount(
          parentCategory.id,
          widget.account.id,
        );
        allSubCategories.addAll(children);
      }
      subCategories = allSubCategories;

      // Load product counts for each sub-category
      await _loadProductCounts();

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProductCounts() async {
    if (subCategories.isEmpty) return;

    try {
      final counts = <String, int>{};
      for (var subCategory in subCategories) {
        // Get products for this child category from this specific organization account
        final products = await ProductService.getProductsByAccountAndCategory(
          widget.account.id,
          subCategory.id,
        );
        counts[subCategory.id] = products.length;
      }

      if (mounted) {
        setState(() {
          productCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Failed to load product counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const Navbar(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading products...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
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
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Get category color (use first category if available)
    final primaryCategory = categories.isNotEmpty ? categories.first : null;
    final categoryColor = primaryCategory?.color ?? Colors.blue;

    return CustomScrollView(
      slivers: [
        // Back Button and Title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: categoryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Grid View of Sub-Categories
        subCategories.isEmpty
            ? SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              categoryColor.withValues(alpha: 0.15),
                              categoryColor.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 48,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No products yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This organization hasn\'t added any products',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subCategory = subCategories[index];
                    return GestureDetector(
                      onTap: () => _navigateToProductDetail(subCategory),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: subCategory.color.withValues(alpha: 0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: subCategory.color.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    subCategory.color.withValues(alpha: 0.15),
                                    subCategory.color.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: subCategory.color.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                subCategory.icon,
                                color: subCategory.color,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 14),
                            
                            // Name
                            Text(
                              subCategory.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: 0.3,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            
                            // Description
                            Text(
                              subCategory.description ?? 'No description',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                letterSpacing: 0.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            
                            // Product Count Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    subCategory.color.withValues(alpha: 0.12),
                                    subCategory.color.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: subCategory.color.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_rounded,
                                    size: 11,
                                    color: subCategory.color,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${productCounts[subCategory.id] ?? 0} products',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: subCategory.color,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: subCategories.length,
                ),
              ),
      ],
    );
  }

  void _navigateToProductDetail(Category subCategory) {
    final category = {
      'id': subCategory.id,
      'name': subCategory.name,
      'description': subCategory.description ?? 'No description',
      'color': subCategory.color,
      'icon': subCategory.icon,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrganizationCategoryProductsScreen(
          accountId: widget.account.id,
          category: category,
        ),
      ),
    ).then((_) async {
      // Refresh product counts after returning
      await _loadProductCounts();
    });
  }
}
