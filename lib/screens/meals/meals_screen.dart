import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../services/sub_category_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../models/sub_category.dart';
import '../../models/category.dart';
import 'meal_detail_screen.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  List<Map<String, dynamic>> capturedImages = [];
  List<SubCategory> subCategories = [];
  Map<int, int> productCounts = {}; // Store product counts for each sub-category
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

      // Find the "Meals" category first
      final categories = await CategoryService.getCategories();
      
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

      // Load sub-categories for the meals category
      subCategories = await SubCategoryService.getSubCategoriesByCategoryId(mealsCategory!.id.toString());
      
      // Load product counts for each sub-category
      await _loadProductCounts();
      
      // Note: It's okay to have 0 sub-categories, we'll show the empty state
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
      Map<int, int> counts = {};
      for (var subCategory in subCategories) {
        final products = await ProductService.getProductsBySubCategory(subCategory.id);
        counts[subCategory.id] = products.length;
      }
      setState(() {
        productCounts = counts;
      });
    } catch (e) {
      debugPrint('Error loading product counts: $e');
      // If there's an error, we'll just show 0 counts
    }
  }

  Future<void> _refreshSubCategories() async {
    try {
      if (mealsCategory != null) {
        debugPrint("Refreshing sub-categories for category: ${mealsCategory!.name}");
        
        // Load sub-categories for the meals category without showing loading state
        final updatedSubCategories = await SubCategoryService.getSubCategoriesByCategoryId(mealsCategory!.id.toString());
        
        debugPrint("Loaded ${updatedSubCategories.length} sub-categories from database");
        for (var subCat in updatedSubCategories) {
          debugPrint("SubCategory: ${subCat.name}, iconValue: ${subCat.iconValue}, colorValue: ${subCat.colorValue}");
        }
        
        // Force a complete state update
        if (mounted) {
          setState(() {
            subCategories = List.from(updatedSubCategories); // Create new list to force rebuild
          });
          
          // Load product counts for the refreshed sub-categories
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: Navbar(
        categoryId: mealsCategory?.id,
        onSearchReturn: () {
          // Refresh product counts when returning from search
          _loadProductCounts();
        },
      ),
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

    return RefreshIndicator(
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
          sliver: subCategories.isEmpty
              ? SliverToBoxAdapter(
                  child: Container(
                    height: 220,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(40),
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
                            fontSize: 20,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start by adding your first category',
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
                        onTap: () => _navigateToMealDetail(subCategory),
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
                                color: subCategory.color.withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: subCategory.color.withValues(alpha: 0.08),
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
                                      subCategory.color.withValues(alpha: 0.15),
                                      subCategory.color.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: subCategory.color.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
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
                              Text(
                                subCategory.name ?? 'Unknown',
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
                              const SizedBox(height: 4),
                            ],
                          ),
                              ),
                          // Edit button positioned at top right
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _showEditMealDialog(subCategory),
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
                                      color: subCategory.color.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: subCategory.color.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: subCategory.color,
                                ),
                              ),
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
        ),
      ],
      ),
    );
  }

  Future<void> _showDebugInfo() async {
    try {
      final categories = await CategoryService.getCategories();
      final subCategories = await SubCategoryService.getSubCategories();
      
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
                        const Text('Sub-Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...subCategories.map((s) => Text('- ${s.name} (Category ID: ${s.categoryId})')),
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
    Color selectedColor = Colors.deepOrange;
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

                                  // Prepare icon and color values
                                  final values = SubCategoryService.validateAndPrepareValues(
                                    icon: selectedIcon,
                                    color: selectedColor,
                                  );

                                  // Create the new sub-category in the database
                                  debugPrint("Creating sub-category with iconValue: ${values['iconValue']}, colorValue: ${values['colorValue']}");
                                  await SubCategoryService.createSubCategory(
                                    name: nameController.text,
                                    description: descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : 'Custom meal category',
                                    categoryId: mealsCategory!.id.toString(),
                                    colorValue: values['colorValue'],
                                    iconValue: values['iconValue'],
                                  );

                                  // Refresh the sub-categories without showing main loading state
                                  await _refreshSubCategories();

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

  void _showEditMealDialog(SubCategory subCategory) {
    final TextEditingController nameController = TextEditingController(text: subCategory.name);
    final TextEditingController descriptionController = TextEditingController(text: subCategory.description);
    Color selectedColor = subCategory.color;
    IconData selectedIcon = subCategory.icon;

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
                            onPressed: () => _showDeleteConfirmation(dialogContext, subCategory),
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

                                  // Prepare icon and color values
                                  final values = SubCategoryService.validateAndPrepareValues(
                                    icon: selectedIcon,
                                    color: selectedColor,
                                  );

                                  // Update the sub-category in the database
                                  debugPrint("Updating sub-category with iconValue: ${values['iconValue']}, colorValue: ${values['colorValue']}");
                                  await SubCategoryService.updateSubCategory(
                                    id: subCategory.id,
                                    name: nameController.text,
                                    description: descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : 'Custom meal category',
                                    colorValue: values['colorValue'],
                                    iconValue: values['iconValue'],
                                  );

                                  // Refresh the sub-categories without showing main loading state
                                  await _refreshSubCategories();

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

  void _showDeleteConfirmation(BuildContext dialogContext, SubCategory subCategory) {
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
                  _showLoadingDialog(scaffoldContext, subCategory.name ?? 'Category', action: 'Deleting');

                  // Delete the sub-category from the database
                  await SubCategoryService.deleteSubCategory(subCategory.id);

                  // Refresh the sub-categories
                  await _refreshSubCategories();

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

  void _navigateToMealDetail(SubCategory subCategory) {
    // Convert SubCategory to the format expected by MealDetailScreen
    final meal = {
      'id': subCategory.id.toString(),
      'name': subCategory.name ?? 'Unknown',
      'description': subCategory.description ?? 'No description',
      'color': subCategory.color,
      'icon': subCategory.icon,
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
