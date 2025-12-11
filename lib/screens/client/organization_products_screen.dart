import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/floating_cart_icon.dart';
import 'organization_category_products_screen.dart';
import 'product_detail_screen.dart';

/// Screen to display an organization's products organized by categories
/// Shows the same design as the category screens (e.g., MealsScreen)
class OrganizationProductsScreen extends StatefulWidget {
  final Account account;
  final Category? specificCategory; // Optional: show only this category's products
  
  const OrganizationProductsScreen({
    super.key,
    required this.account,
    this.specificCategory,
  });

  @override
  State<OrganizationProductsScreen> createState() => _OrganizationProductsScreenState();
}

class _OrganizationProductsScreenState extends State<OrganizationProductsScreen> {
  Map<String, int> productCounts = {};
  List<Category> categories = []; // Changed to list to support multiple categories
  List<Category> subCategories = [];
  List<Category> filteredSubCategories = [];
  Map<String, List<Product>> categoryProducts = {}; // category_id -> products
  bool isLoading = true;
  String? errorMessage;
  final CartService _cartService = CartService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchHints = false;

  @override
  void initState() {
    super.initState();
    _initializeCart();
    _loadData();
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() {
      _showSearchHints = _searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredSubCategories = subCategories;
        _showSearchHints = _searchFocusNode.hasFocus;
      } else {
        _showSearchHints = true; // Keep showing search results when typing
        final lowerQuery = query.toLowerCase();
        filteredSubCategories = subCategories.where((category) {
          // Search in category name and description
          final matchesCategory = category.name.toLowerCase().contains(lowerQuery) ||
              (category.description?.toLowerCase().contains(lowerQuery) ?? false);
          
          // Search in products of this category
          final products = categoryProducts[category.id] ?? [];
          final matchesProducts = products.any((product) => 
            product.name.toLowerCase().contains(lowerQuery) ||
            (product.description?.toLowerCase().contains(lowerQuery) ?? false)
          );
          
          return matchesCategory || matchesProducts;
        }).toList();
      }
    });
  }

  Future<void> _initializeCart() async {
    await _cartService.initialize();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // If a specific category is provided, use only that category
      if (widget.specificCategory != null) {
        categories = [widget.specificCategory!];
      } else {
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
      filteredSubCategories = allSubCategories;

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
      final products = <String, List<Product>>{};
      for (var subCategory in subCategories) {
        // Get products for this child category from this specific organization account
        final categoryProductsList = await ProductService.getProductsByAccountAndCategory(
          widget.account.id,
          subCategory.id,
        );
        counts[subCategory.id] = categoryProductsList.length;
        products[subCategory.id] = categoryProductsList;
      }

      if (mounted) {
        setState(() {
          productCounts = counts;
          categoryProducts = products;
        });
      }
    } catch (e) {
      debugPrint('Failed to load product counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showSearchHints && !_searchFocusNode.hasFocus && _searchController.text.isEmpty,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          // If search is active (has text or focused), clear it and show categories
          if (_searchController.text.isNotEmpty || _showSearchHints || _searchFocusNode.hasFocus) {
            setState(() {
              _searchController.clear();
              _searchFocusNode.unfocus();
              _showSearchHints = false;
              filteredSubCategories = subCategories;
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildBody(),
            ),
            FloatingCartIcon(
              organizationId: widget.account.id,
              organizationName: widget.account.name ?? 'Organization',
            ),
          ],
        ),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
        // Back Button and Title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 28,
                ),
                const SizedBox(width: 8),
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

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search categories...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: categoryColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),

        // Grid View of Sub-Categories
        _showSearchHints
            ? SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () {
                    _searchFocusNode.unfocus();
                  },
                  child: _buildSearchHints(categoryColor),
                ),
              )
            : filteredSubCategories.isEmpty
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
                          _searchController.text.isNotEmpty
                              ? Icons.search_off
                              : Icons.inventory_2_rounded,
                          size: 48,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No categories found'
                            : 'No products yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Try searching with different keywords'
                            : 'This organization hasn\'t added any products',
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
                    final subCategory = filteredSubCategories[index];
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
                  childCount: filteredSubCategories.length,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSearchHints(Color categoryColor) {
    if (_searchController.text.isEmpty) {
      // Show search tips when search is empty
      final sampleCategories = subCategories.take(5).toList();
      
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: categoryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: categoryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Search Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipItem('Search by category name or product name', categoryColor),
                  _buildTipItem('Use keywords from descriptions', categoryColor),
                  _buildTipItem('Tap anywhere to close search hints', categoryColor),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (sampleCategories.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Available Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sampleCategories.map((category) => _buildCategoryHintItem(category)),
            ],
          ],
        ),
      );
    } else {
      // Show matching products when searching
      return _buildSearchResults(categoryColor);
    }
  }

  Widget _buildSearchResults(Color categoryColor) {
    final query = _searchController.text.toLowerCase();
    final results = <Map<String, dynamic>>[];
    
    // Search for products across all categories
    for (var category in subCategories) {
      final products = categoryProducts[category.id] ?? [];
      for (var product in products) {
        if (product.name.toLowerCase().contains(query) ||
            (product.description?.toLowerCase().contains(query) ?? false)) {
          results.add({
            'product': product,
            'category': category,
          });
        }
      }
    }
    
    if (results.isEmpty && filteredSubCategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No results found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Try searching with different keywords',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show matching categories
          if (filteredSubCategories.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  color: categoryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Categories (${filteredSubCategories.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...filteredSubCategories.map((category) => _buildCategoryHintItem(category)),
          ],
          
          // Show matching products
          if (results.isNotEmpty) ...[
            if (filteredSubCategories.isNotEmpty) const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Products (${results.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...results.map((result) => _buildProductHintItem(
              result['product'] as Product,
              result['category'] as Category,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildProductHintItem(Product product, Category category) {
    // Format price
    String priceText = '';
    if (product.priceUsd != null && product.priceUsd! > 0) {
      priceText = '\$${product.priceUsd!.toStringAsFixed(2)}';
    } else if (product.priceLbp != null && product.priceLbp! > 0) {
      priceText = '${product.priceLbp!.toStringAsFixed(0)} L.L.';
    }

    return InkWell(
      onTap: () => _navigateToProductDetailScreen(product, category),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Product Image or Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: product.imageUrl != null ? Colors.transparent : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                image: product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrl == null
                  ? Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.green.shade600,
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (priceText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      priceText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProductDetailScreen(Product product, Category category) {
    // Save current search state
    final currentSearchText = _searchController.text;
    
    // Navigate directly to the product detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          organizationId: widget.account.id,
          organizationName: widget.account.name,
          accentColor: category.color,
          categoryName: category.name,
        ),
      ),
    ).then((_) async {
      // Refresh product counts after returning
      await _loadProductCounts();
      
      // Restore search state
      if (currentSearchText.isNotEmpty) {
        setState(() {
          _searchController.text = currentSearchText;
          _onSearchChanged(currentSearchText);
        });
      }
    });
  }

  Widget _buildTipItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHintItem(Category category) {
    return InkWell(
      onTap: () => _navigateToProductDetail(category),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.description != null && category.description!.isNotEmpty)
                    Text(
                      category.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              '${productCounts[category.id] ?? 0} items',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: category.color,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
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
          accountName: widget.account.name ?? 'Organization',
          category: category,
        ),
      ),
    ).then((_) async {
      // Refresh product counts after returning
      await _loadProductCounts();
    });
  }
}
