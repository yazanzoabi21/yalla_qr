import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';
import 'category_detail_screen.dart';

/// Reusable generic category screen that works for any parent category
/// Can be used for Meals, Gym, Super Market, or any other parent category
class CategoryScreen extends StatefulWidget {
  final String parentCategoryName;
  final Color headerColor;
  final IconData headerIcon;
  final String? headerDescription;

  const CategoryScreen({
    super.key,
    required this.parentCategoryName,
    required this.headerColor,
    required this.headerIcon,
    this.headerDescription,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Category> childCategories = [];
  Map<String, int> productCounts = {};
  Category? parentCategory;
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

      // Find the parent category
      final categories = await CategoryService.getCategoriesForAccount();
      
      try {
        parentCategory = categories.firstWhere((category) => 
          category.name.toLowerCase().trim() == widget.parentCategoryName.toLowerCase().trim()
        );
      } catch (e) {
        try {
          parentCategory = categories.firstWhere((category) => 
            category.name.toLowerCase().trim().contains(widget.parentCategoryName.toLowerCase().trim())
          );
        } catch (e2) {
          parentCategory = null;
        }
      }
      
      if (parentCategory == null) {
        throw Exception('Category not found. Available categories: ${categories.map((c) => '"${c.name}"').join(', ')}');
      }

      // Load child categories
      childCategories = await CategoryService.getChildCategoriesForAccount(parentCategory!.id);
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
      if (parentCategory != null) {
        final updated = await CategoryService.getChildCategoriesForAccount(parentCategory!.id);
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
        builder: (context) => CategoryDetailScreen(
          parentCategoryId: parentCategory!.id,
          childCategoryId: categoryId,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _refreshChildCategories();
      }
    });
  }

  void _showAddCategoryDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    
    Color selectedColor = widget.headerColor;
    IconData selectedIcon = Icons.category;
    
    final List<Color> colors = [
      Colors.deepOrange,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    
    final List<IconData> icons = [
      Icons.restaurant,
      Icons.delete,
      Icons.store,
      Icons.bed,
      Icons.wine_bar,
      Icons.sports_basketball,
      Icons.local_cafe,
      Icons.cake,
      Icons.diamond,
      Icons.shopping_bag,
      Icons.kitchen,
      Icons.lunch_dining,
      Icons.local_dining,
      Icons.local_offer,
      Icons.local_shipping,
      Icons.local_movies,
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
                          hintText: 'Enter category name',
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
                                    ? selectedColor.withOpacity(0.2)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: selectedColor, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? selectedColor : Colors.grey,
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
                                if (nameController.text.isNotEmpty && parentCategory != null) {
                                  final scaffoldContext = context;
                                  final messenger = ScaffoldMessenger.of(scaffoldContext);
                                  
                                  try {
                                    if (Navigator.canPop(dialogContext)) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                    
                                    await CategoryService.createCategoryForAccount(
                                      name: nameController.text,
                                      description: descriptionController.text.isNotEmpty
                                          ? descriptionController.text
                                          : 'Custom category',
                                      parentId: parentCategory!.id,
                                      iconCode: selectedIcon.codePoint,
                                      colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                                    );

                                    await _refreshChildCategories();

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
              ),
            );
          },
        );
      },
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFF43A047),
      const Color(0xFFD81B60),
      const Color(0xFF3949AB),
      const Color(0xFFF4511E),
      const Color(0xFF00897B),
      const Color(0xFF5E35B1),
      const Color(0xFFFFB300),
      const Color(0xFFD32F2F),
      const Color(0xFF1976D2),
      const Color(0xFF388E3C),
      const Color(0xFFC2185B),
      const Color(0xFF7B1FA2),
      const Color(0xFF0288D1),
      const Color(0xFFF57C00),
      const Color(0xFF689F38),
    ];
    final colorIndex = (index.hashCode.abs()) % colors.length;
    return colors[colorIndex];
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
        backgroundColor: const Color(0xFFEFF0F3),
        appBar: Navbar(
          showMenuButton: false,
        ),
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
                            Text(
                              widget.parentCategoryName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadData,
                            child: CustomScrollView(
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          widget.headerColor.withOpacity(0.8),
                                          widget.headerColor.withOpacity(0.6),
                                          widget.headerColor.withOpacity(0.4),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.headerColor.withOpacity(0.25),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(widget.headerIcon, color: Colors.white, size: 36),
                                        const SizedBox(height: 12),
                                        Text(
                                          widget.parentCategoryName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (widget.headerDescription != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            widget.headerDescription!,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

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
                                          ),
                                        ),
                                        FloatingActionButton(
                                          onPressed: _showAddCategoryDialog,
                                          backgroundColor: widget.headerColor,
                                          child: const Icon(Icons.add, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (childCategories.isNotEmpty)
                                  SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.9,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final category = childCategories[index];
                                        final productCount = productCounts[category.id] ?? 0;
                                        final color = _getColorForIndex(index);

                                        return GestureDetector(
                                          onTap: () => _onChildCategoryTap(category.id),
                                          child: Card(
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    color.withOpacity(0.85),
                                                    color.withOpacity(0.65),
                                                  ],
                                                ),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: Opacity(
                                                      opacity: 0.08,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.all(16),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.all(10),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.95),
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Icon(
                                                                category.icon,
                                                                color: color,
                                                                size: 24,
                                                              ),
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.all(8),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.2),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Icon(
                                                                Icons.edit,
                                                                color: Colors.white,
                                                                size: 18,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              category.name,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 4,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.95),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                '🛒 $productCount products',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: color,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
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
                                  )
                                else
                                  SliverFillRemaining(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 80,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No Categories Yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Create categories to get started',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
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
                      ],
                    ),
                  ),
      ),
    );
  }
}
