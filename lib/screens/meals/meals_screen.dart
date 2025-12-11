import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
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
  List<Map<String, dynamic>> capturedImages = [];
  List<Category> childCategories = [];
  Map<String, int> productCounts = {}; // Store product counts for each child category
  Category? mealsCategory;
  bool isLoading = true;
  String? errorMessage;
  BuildContext? _loadingContext; // Global variable to store loading dialog context

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

      // Find the "Meals" category first - using account-filtered categories
      final categories = await CategoryService.getCategoriesForAccount();
      
      // Try to find the "Meals" category (case-insensitive and trim whitespace)
      try {
        mealsCategory = categories.firstWhere((category) => 
          category.name.toLowerCase().trim() == 'meals'
        );
      } catch (e) {
        // If exact match fails, try partial match
        try {
          mealsCategory = categories.firstWhere((category) => 
            category.name.toLowerCase().trim().contains('meal')
          );
        } catch (e2) {
          mealsCategory = null;
        }
      }
      
      if (mealsCategory == null) {
        // If "Meals" not found, let's see what categories we have
        throw Exception('Category not found. Available categories: ${categories.map((c) => '"${c.name}"').join(', ')}');
      }

      // Load child categories for the meals category - using account-filtered method
      childCategories = await CategoryService.getChildCategoriesForAccount(mealsCategory!.id);
      
      // Load product counts for each child category
      await _loadProductCounts();
      
      // Note: It's okay to have 0 child categories, we'll show the empty state
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
      // If there's an error, we'll just show 0 counts
    }
  }

  Future<void> _refreshChildCategories() async {
    try {
      if (mealsCategory != null) {
        debugPrint("Refreshing child categories for category: ${mealsCategory!.name}");
        
        // Load child categories for the meals category without showing loading state - using account-filtered method
        final updatedChildCategories = await CategoryService.getChildCategoriesForAccount(mealsCategory!.id);
        
        debugPrint("Loaded ${updatedChildCategories.length} child categories from database");
        for (var cat in updatedChildCategories) {
          debugPrint("Child Category: ${cat.name}");
        }
        
        // Force a complete state update
        if (mounted) {
          setState(() {
            childCategories = List.from(updatedChildCategories); // Create new list to force rebuild
          });
          
          // Load product counts for the refreshed child categories
          await _loadProductCounts();
          
          debugPrint("UI state updated with refreshed sub-categories");
          
          // Small delay to ensure UI updates
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      // If refresh fails, just keep the current state
      debugPrint('Failed to refresh sub-categories: $e');
    }
  }

  void _showLoadingDialog(BuildContext scaffoldContext, String categoryName, {String action = 'Creating'}) {
    showDialog(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (context) {
        _loadingContext = context;
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
              const SizedBox(height: 16),
              Text('$action $categoryName...'),
              const SizedBox(height: 8),
              const Text(
                'This may take a few seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  void _closeLoadingDialog() {
    if (_loadingContext != null && mounted && Navigator.canPop(_loadingContext!)) {
      Navigator.of(_loadingContext!).pop();
      _loadingContext = null;
    }
  }

  /// Generate a vibrant random color for new categories
  Color _generateRandomColor() {
    final random = Random();
    // Generate vibrant colors by ensuring high saturation and value
    final hue = random.nextDouble() * 360; // 0-360 degrees
    final saturation = 0.6 + random.nextDouble() * 0.4; // 60-100%
    final value = 0.7 + random.nextDouble() * 0.3; // 70-100%
    
    return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: Navbar(
        categoryId: mealsCategory?.id,
        showMenuButton: false, // Hide menu in sub-category
        onSearchReturn: () {
          // Refresh product counts when returning from search
          _loadProductCounts();
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
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
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            ),
            SizedBox(height: 16),
            Text(
              'Loading categories...',
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
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
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
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showDebugInfo,
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug Info'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
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
            // IconButton(
            //   icon: const Icon(Icons.arrow_back, size: 20),
            //   onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            //   padding: const EdgeInsets.all(4),
            //   constraints: const BoxConstraints(),
            // ),
            InkWell(
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              borderRadius: BorderRadius.circular(20),
              child: Icon(
                Icons.arrow_back,
                size: 25,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(width: 12),
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
            onRefresh: _refreshData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
          // Header Section as Sliver
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepOrange,
                    Colors.orange.shade400,
                    Colors.orange.shade300
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant_menu, color: Colors.white, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'Meals Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage your daily meal plans and nutrition',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Section title and add button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.3,
                  ),
                ),
                GestureDetector(
                  onTap: _showAddMealDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Grid View as Sliver
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 32),
          sliver: childCategories.isEmpty
              ? SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.deepOrange.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                          spreadRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.deepOrange.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepOrange.withValues(alpha: 0.1),
                                Colors.deepOrange.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 48,
                            color: Colors.deepOrange.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No categories found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,  
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Start by adding your first category',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                      final childCategory = childCategories[index];
                      final isHidden = childCategory.isHidden;
                      return Opacity(
                        opacity: isHidden ? 0.4 : 1.0,
                        child: GestureDetector(
                          onTap: isHidden ? null : () => _navigateToMealDetail(childCategory),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 45,
                                offset: const Offset(0, 20),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: childCategory.color.withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.deepOrange.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8, right: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      childCategory.color.withValues(alpha: 0.15),
                                      childCategory.color.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: childCategory.color.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: childCategory.color.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  childCategory.icon,
                                  color: childCategory.color,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                childCategory.name,
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
                              Center(
                                child: Text(
                                  childCategory.description ?? 'No description',
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
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      childCategory.color.withValues(alpha: 0.12),
                                      childCategory.color.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: childCategory.color.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      size: 11,
                                      color: childCategory.color,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${productCounts[childCategory.id] ?? 0} products',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: childCategory.color,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                              ),
                          // Edit button positioned at top right
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _showEditMealDialog(childCategory),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Colors.deepOrange.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.deepOrange.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          ),
                        ],
                          ),
                        ),
                      ),
                    );
                  },
                    childCount: childCategories.length,
                  ),
                ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDebugInfo() async {
    try {
      final categories = await CategoryService.getCategoriesForAccount();
      final childCats = mealsCategory != null
          ? await CategoryService.getChildCategoriesForAccount(mealsCategory!.id)
          : <Category>[];

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debug Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Categories found: ${categories.length}'),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...categories.map((c) => Text('- ${c.name} (ID: ${c.id})')),
                        const SizedBox(height: 16),
                        Text('Child categories under "${mealsCategory?.name ?? 'Unknown'}":', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ...childCats.map((s) => Text('- ${s.name} (Parent ID: ${s.parentId ?? 'none'})')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    // Reload data from the database
    await _loadData();
    
    // Show feedback to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories refreshed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddMealDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    Color selectedColor = _generateRandomColor(); // Generate random color
    IconData selectedIcon = Icons.restaurant;

    final List<Color> colors = [
      Colors.deepOrange, Colors.green, Colors.blue, Colors.purple,
      Colors.red, Colors.teal, Colors.pink, Colors.indigo
    ];

    final List<IconData> icons = [
      Icons.restaurant, Icons.breakfast_dining, Icons.lunch_dining,
      Icons.dinner_dining, Icons.local_pizza, Icons.cake,
      Icons.coffee, Icons.icecream, Icons.fastfood,
      Icons.set_meal, Icons.restaurant_menu, Icons.egg_alt,
      Icons.bakery_dining, Icons.rice_bowl, Icons.soup_kitchen,
      Icons.phishing, Icons.tsunami, Icons.waves
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                      'Add New Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                                color: selectedColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Fishes, Snacks, Desserts',
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        hintText: 'Brief description of this category',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Color Selection
                    const Text(
                      'Choose Color:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: colors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selectedColor == color
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Icon Selection
                    const Text(
                      'Choose Icon:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: icons.map((icon) {
                        bool isSelected = selectedIcon.codePoint == icon.codePoint;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: selectedColor, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? selectedColor
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () {
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isNotEmpty && mealsCategory != null) {
                                // Store context before async operations
                                final scaffoldContext = context;
                                final messenger = ScaffoldMessenger.of(scaffoldContext);
                                
                                try {
                                  // Close the dialog first
                                  if (Navigator.canPop(dialogContext)) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  
                                  // Show loading dialog
                                  _showLoadingDialog(scaffoldContext, nameController.text);

                                  // Create the new child category in the database and link to account
                                  await CategoryService.createCategoryForAccount(
                                    name: nameController.text,
                                    description: descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : 'Custom meal category',
                                    parentId: mealsCategory!.id,
                                    iconCode: selectedIcon.codePoint,
                                    colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                                  );

                                  // Refresh the child categories without showing main loading state
                                  await _refreshChildCategories();

                                  // Close loading dialog safely
                                  _closeLoadingDialog();

                                  // Show success message
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${nameController.text} category added successfully!'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Close loading dialog safely
                                  _closeLoadingDialog();
                                  
                                  // Show error message
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add category: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Show validation error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a category name'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedColor,
                            ),
                            child: const Text(
                              'Add Category',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              )
              );
          },
        );
      },
    );
  }

  void _showEditMealDialog(Category childCategory) {
    final TextEditingController nameController = TextEditingController(text: childCategory.name);
    final TextEditingController descriptionController = TextEditingController(text: childCategory.description ?? '');
    Color selectedColor = childCategory.color;
    IconData selectedIcon = childCategory.icon;

    final List<Color> colors = [
      Colors.deepOrange, Colors.green, Colors.blue, Colors.purple,
      Colors.red, Colors.teal, Colors.pink, Colors.indigo
    ];

    final List<IconData> icons = [
      Icons.restaurant, Icons.breakfast_dining, Icons.lunch_dining,
      Icons.dinner_dining, Icons.local_pizza, Icons.cake,
      Icons.coffee, Icons.icecream, Icons.fastfood,
      Icons.set_meal, Icons.restaurant_menu, Icons.egg_alt,
      Icons.bakery_dining, Icons.rice_bowl, Icons.soup_kitchen,
      Icons.phishing, Icons.tsunami, Icons.waves
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                      'Edit ${nameController.text} Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: selectedColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Fishes, Snacks, Desserts',
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        hintText: 'Brief description of this category',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Color Selection
                    const Text(
                      'Choose Color:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: colors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selectedColor == color
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Icon Selection
                    const Text(
                      'Choose Icon:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: icons.map((icon) {
                        bool isSelected = selectedIcon.codePoint == icon.codePoint;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: selectedColor, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? selectedColor
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextButton(
                            onPressed: () {
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextButton(
                            onPressed: () => _showDeleteConfirmation(dialogContext, childCategory),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isNotEmpty) {
                                // Store context before async operations
                                final scaffoldContext = context;
                                final messenger = ScaffoldMessenger.of(scaffoldContext);
                                
                                try {
                                  // Close the dialog first
                                  if (Navigator.canPop(dialogContext)) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  
                                  // Show loading dialog
                                  _showLoadingDialog(scaffoldContext, nameController.text, action: 'Updating');

                                  // Update the child category in the database
                                  await CategoryService.updateCategory(
                                    id: childCategory.id,
                                    name: nameController.text,
                                    description: descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : 'Custom meal category',
                                    parentId: mealsCategory?.id,
                                    iconCode: selectedIcon.codePoint,
                                    colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                                  );

                                  // Refresh the child categories without showing main loading state
                                  await _refreshChildCategories();

                                  // Close loading dialog safely
                                  _closeLoadingDialog();

                                  // Show success message
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${nameController.text} category updated successfully!'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Close loading dialog safely
                                  _closeLoadingDialog();
                                  
                                  // Show error message
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update category: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Show validation error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a category name'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedColor,
                            ),
                            child: const Text(
                              'Update',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              )
              );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext dialogContext, Category subCategory) {
    showDialog(
      context: context,
      builder: (BuildContext confirmContext) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Are you sure you want to delete "${subCategory.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(confirmContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Close both dialogs
                  Navigator.of(confirmContext).pop();
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.of(dialogContext).pop();
                  }
                  
                  // Show loading dialog
                  final scaffoldContext = context;
                  _showLoadingDialog(scaffoldContext, subCategory.name, action: 'Deleting');

                  // Delete the child category from the database
                  await CategoryService.deleteCategory(subCategory.id);

                  // Refresh the child categories
                  await _refreshChildCategories();

                  // Close loading dialog
                  _closeLoadingDialog();

                  // Show success message
                  if (scaffoldContext.mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: Text('${subCategory.name} deleted successfully!'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  // Close loading dialog safely
                  _closeLoadingDialog();
                  
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete category: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToMealDetail(Category childCategory) {
    // Convert child category to the format expected by MealDetailScreen
    final meal = {
      'id': childCategory.id,
      'name': childCategory.name,
      'description': childCategory.description ?? 'No description',
      'category_id': mealsCategory?.id,
      'color': childCategory.color, // Add color from category
      'icon': childCategory.icon, // Add icon from category
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealDetailScreen(
          meal: meal,
          onProductAdded: (product) {}, // No-op, handled by DB now
        ),
      ),
    ).then((_) async {
      // After returning from detail screen, refresh product counts
      await _loadProductCounts();
    });
  }
}
