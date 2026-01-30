import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/search_result.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/search_service.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';
import '../../utils/navigation_helper.dart';
import '../../exceptions/category_not_registered_exception.dart';
import '../meals/meal_detail_screen.dart';
import '../meals/meals_screen.dart';
import '../gym/gym_screen.dart';
import '../client/product_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  final String? categoryId;
  final bool categoriesOnly;
  final String? organizationAccountId; // For client search
  final String? organizationName; // For product detail navigation
  final Color? accentColor; // For product detail navigation

  const SearchResultsScreen({
    super.key,
    this.initialQuery = '',
    this.categoryId,
    this.categoriesOnly = false,
    this.organizationAccountId,
    this.organizationName,
    this.accentColor,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }

    // Add listener for real-time search
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Create new timer for debouncing (300ms)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _results = [];
          _hasSearched = false;
          _errorMessage = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      List<SearchResult> results;
      
      if (widget.organizationAccountId != null) {
        // Client search within organization
        results = await SearchService.searchOrganizationProducts(
          query: query,
          organizationAccountId: widget.organizationAccountId!,
        );
      } else if (widget.categoriesOnly) {
        // Search only categories (for home screen)
        results = await SearchService.searchCategoriesOnly(query);
      } else if (widget.categoryId != null) {
        // Search within specific category
        results = await SearchService.searchInCategory(
          query: query,
          categoryId: widget.categoryId!,
        );
      } else {
        // Global search
        results = await SearchService.globalSearch(query);
      }

      setState(() {
        _results = results;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while searching: ${e.toString()}';
        _isLoading = false;
        _hasSearched = true;
      });
      debugPrint('Search error: $e');
    }
  }

  Future<void> _handleResultTap(SearchResult result) async {
    switch (result.type) {
      case SearchResultType.product:
        // Navigate to product detail (meal detail)
        final product = result.data as Product;
        await _navigateToProductDetail(product);
        break;
        
      case SearchResultType.category:
        // Navigate to category screen
        final category = result.data as Category;
        // Check if this is a child category (navigate to detail) or parent category (navigate to category screen)
        if (category.isChild) {
          await _navigateToCategoryDetail(category);
        } else {
          _navigateToCategoryScreen(category);
        }
        break;
    }
  }

  Future<void> _navigateToProductDetail(Product product) async {
    // For client mode (organization search), navigate to ProductDetailScreen
    if (widget.organizationAccountId != null) {
      if (!mounted) return;
      
      // Try to get category name if product has categoryId
      String? categoryName;
      if (product.categoryId != null) {
        try {
          final categoryData = await Supabase.instance.client
              .from('categories')
              .select('name')
              .eq('id', product.categoryId!)
              .maybeSingle();
          if (categoryData != null) {
            categoryName = categoryData['name'] as String?;
          }
        } catch (e) {
          debugPrint('Failed to fetch category name: $e');
        }
      }
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailScreen(
            product: product,
            organizationId: widget.organizationAccountId!,
            organizationName: widget.organizationName ?? 'Organization',
            accentColor: widget.accentColor ?? Colors.blue,
            categoryName: categoryName,
          ),
        ),
      );
      
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }
    
    // For organization owner mode, navigate to category (MealDetailScreen)
    try {
      // Fetch the category details to get proper name and description
      if (product.categoryId != null) {
        final category = await CategoryService.getCategoryById(product.categoryId!);
        
        if (category == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category not found')),
          );
          return;
        }

        // Create a meal map format that MealDetailScreen expects
        final theme = Theme.of(context);
        final mealMap = {
          'id': category.id,
          'name': category.name,
          'description': category.description ?? '',
          'color': category.color ?? theme.colorScheme.primary,
        };

        if (!mounted) return;
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealDetailScreen(
              meal: mealMap,
              onProductAdded: (addedProduct) {
                // Refresh search results if needed
                if (_searchController.text.isNotEmpty) {
                  _performSearch(_searchController.text);
                }
              },
            ),
          ),
        );
        
        // After returning from detail screen, pop back to refresh the parent screen
        if (!mounted) return;
        Navigator.pop(context, true); // Return true to indicate data was changed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product details not available')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading product: ${e.toString()}')),
      );
    }
  }

  void _navigateToCategoryScreen(Category category) async {
    // Check if user is authenticated
    final authService = AuthService(Supabase.instance.client);
    final isAuthenticated = authService.isAuthenticated();

    if (!isAuthenticated) {
      // User is not logged in, navigate to login with intended destination
      NavigationHelper.navigateToLogin(
        context,
        intendedDestination: category.name.toLowerCase(),
      );
      return;
    }

    // User is authenticated, check if they have access to this specific category
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await authService.validateAccountAccess(currentUser, category.name);
      }
    } on CategoryNotRegisteredException catch (e) {
      // User is logged in but not registered for this category
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navigate to login for this category
      NavigationHelper.navigateToLogin(
        context,
        intendedDestination: category.name.toLowerCase(),
      );
      return;
    } catch (e) {
      // Other errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // User has access, navigate to the appropriate category screen
    Widget targetScreen;
    
    switch (category.name.toLowerCase()) {
      case 'meals':
        targetScreen = const MealsScreen();
        break;
      case 'gym':
        targetScreen = const GymScreen();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.name} screen not implemented yet')),
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  Future<void> _navigateToCategoryDetail(Category category) async {
    try {
      // Create a meal map format that MealDetailScreen expects
      final theme = Theme.of(context);
      final mealMap = {
        'id': category.id,
        'name': category.name,
        'description': category.description ?? '',
        'color': category.color ?? theme.colorScheme.primary,
      };

      if (!mounted) return;
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MealDetailScreen(
            meal: mealMap,
            onProductAdded: (addedProduct) {
              // Refresh search results if needed
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
          ),
        ),
      );
      
      // After returning from detail screen, pop back to refresh the parent screen
      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate data was changed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sub-category: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: widget.categoriesOnly 
                  ? 'Search categories...'
                  : (widget.categoryId != null 
                      ? 'Search in this category...' 
                      : 'Search for products, categories...'),
              hintStyle: TextStyle(color: theme.hintColor, fontSize: 15),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: theme.iconTheme.color?.withOpacity(0.7), size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: theme.iconTheme.color?.withOpacity(0.7), size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _results = [];
                          _hasSearched = false;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: const TextStyle(fontSize: 15),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _performSearch(value.trim());
              }
            },
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                color: theme.disabledColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Oops!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  // use default text color
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _performSearch(_searchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Start Searching',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleLarge?.color?.withOpacity(0.95),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                widget.categoriesOnly
                    ? 'Type something to search for categories'
                    : 'Type something to search for products, categories, or sub-categories',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No Results Found',
                style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                'We couldn\'t find anything matching "${_searchController.text}"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Try different keywords or check spelling',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return _buildResults();
  }

  Widget _buildResults() {
    final theme = Theme.of(context);
    // Group results by type
    final productResults = _results.where((r) => r.type == SearchResultType.product).toList();
    final categoryResults = _results.where((r) => r.type == SearchResultType.category).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search summary
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Found ${_results.length} result${_results.length == 1 ? '' : 's'} for "${_searchController.text}"',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Categories section
        if (categoryResults.isNotEmpty) ...[
          _buildSectionHeader('Categories', categoryResults.length, Icons.category),
          ...categoryResults.map((result) => _buildResultCard(result)),
          const SizedBox(height: 16),
        ],

        // Products section
        if (productResults.isNotEmpty) ...[
          _buildSectionHeader('Products', productResults.length, Icons.shopping_bag),
          ...productResults.map((result) => _buildResultCard(result)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.iconTheme.color?.withOpacity(0.85)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(SearchResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _handleResultTap(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: result.color.withOpacity(isDark ? 0.22 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  result.icon,
                  color: result.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          Text(
                            result.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: result.color.withOpacity(isDark ? 0.28 : 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: result.color,
                            ),
                          ),
                        ),
                        if (result.subtitle != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result.subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (result.description != null && result.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.iconTheme.color?.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
