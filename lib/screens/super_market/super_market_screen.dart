import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
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
  List<Map<String, dynamic>> capturedImages = [];
  List<Category> childCategories = [];
  Map<String, int> productCounts = {}; // Store product counts for each child category
  Category? superMarketCategory;
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

      // Find the "Super Market" category first - using account-filtered categories
      final categories = await CategoryService.getCategoriesForAccount();
      
      // Try to find the "Super Market" category (case-insensitive and trim whitespace)
      try {
        superMarketCategory = categories.firstWhere((category) => 
          category.name.toLowerCase().trim() == 'super market'
        );
      } catch (e) {
        // If exact match fails, try partial match
        try {
          superMarketCategory = categories.firstWhere((category) => 
            category.name.toLowerCase().trim().contains('super market')
          );
        } catch (e2) {
          superMarketCategory = null;
        }
      }
      
      if (superMarketCategory == null) {
        // If "Super Market" not found, let's see what categories we have
        throw Exception('Category not found. Available categories: ${categories.map((c) => '"${c.name}"').join(', ')}');
      }

      // Load child categories for the super market category - using account-filtered method
      childCategories = await CategoryService.getChildCategoriesForAccount(superMarketCategory!.id);
      
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
      if (superMarketCategory != null) {
        final updated = await CategoryService.getChildCategoriesForAccount(superMarketCategory!.id);
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
      // Always refresh when returning from detail screen to ensure counts are up to date
      _loadProductCounts();
    });
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
              const SizedBox(height: 20),
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$action $categoryName...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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

  /// Show icon picker dialog for custom icon selection
  Future<IconData?> _showIconPicker(BuildContext context, IconData currentIcon, Color selectedColor) async {
    IconData selectedIcon = currentIcon;
    
    final List<IconData> allIcons = [
      Icons.shopping_cart, Icons.shopping_bag, Icons.store,
      Icons.storefront, Icons.local_grocery_store, Icons.shopping_basket,
      Icons.kitchen, Icons.restaurant, Icons.local_cafe,
      Icons.bakery_dining, Icons.local_pizza, Icons.wine_bar,
      Icons.local_bar, Icons.cake, Icons.icecream,
      Icons.fastfood, Icons.lunch_dining, Icons.local_dining,
      Icons.food_bank, Icons.egg_alt, Icons.breakfast_dining,
      Icons.ramen_dining, Icons.apple, Icons.water_drop,
      Icons.cleaning_services, Icons.shower, Icons.soap,
      Icons.sanitizer, Icons.local_pharmacy, Icons.medication,
      Icons.vaccines, Icons.checkroom, Icons.dry_cleaning,
      Icons.print, Icons.toys, Icons.sports_basketball,
      Icons.fitness_center, Icons.pets, Icons.emoji_nature,
      Icons.yard, Icons.local_florist, Icons.brightness_5,
      Icons.lightbulb, Icons.power, Icons.electrical_services,
      Icons.plumbing, Icons.hardware, Icons.build,
      Icons.handyman, Icons.carpenter, Icons.home_repair_service,
      Icons.construction, Icons.settings, Icons.phone_android,
      Icons.computer, Icons.headphones, Icons.watch,
      Icons.camera_alt, Icons.videogame_asset, Icons.sports_esports,
      Icons.book, Icons.menu_book, Icons.library_books,
      Icons.school, Icons.brush, Icons.palette,
    ];

    return showDialog<IconData>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Choose Icon'),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: allIcons.length,
                  itemBuilder: (context, index) {
                    final icon = allIcons[index];
                    final isSelected = selectedIcon.codePoint == icon.codePoint;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedIcon = icon;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? selectedColor.withOpacity(0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: selectedColor, width: 2)
                              : Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? selectedColor : Colors.grey.shade600,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedIcon),
                  style: ElevatedButton.styleFrom(backgroundColor: selectedColor),
                  child: const Text('Select', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show color picker dialog for custom color selection
  Future<Color?> _showColorPicker(BuildContext context, Color currentColor) async {
    Color selectedColor = currentColor;
    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;

    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
            
            return AlertDialog(
              title: const Text('Choose Custom Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color preview
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Hue slider
                    Row(
                      children: [
                        const Text('Hue:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Slider(
                            value: hue,
                            min: 0,
                            max: 360,
                            divisions: 360,
                            onChanged: (value) {
                              setState(() {
                                hue = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    // Saturation slider
                    Row(
                      children: [
                        const Text('Saturation:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Slider(
                            value: saturation,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: (value) {
                              setState(() {
                                saturation = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    // Value/Brightness slider
                    Row(
                      children: [
                        const Text('Brightness:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Slider(
                            value: value,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: (newValue) {
                              setState(() {
                                value = newValue;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedColor),
                  style: ElevatedButton.styleFrom(backgroundColor: selectedColor),
                  child: const Text('Select', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCategoryDialog(Category childCategory) {
    final TextEditingController nameController = TextEditingController(text: childCategory.name);
    final TextEditingController descriptionController = TextEditingController(text: childCategory.description ?? '');
    Color selectedColor = childCategory.color;
    IconData selectedIcon = childCategory.icon;

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
      Icons.shopping_cart,
      Icons.shopping_bag,
      Icons.store,
      Icons.local_grocery_store,
      Icons.restaurant,
      Icons.local_cafe,
      Icons.cleaning_services,
      Icons.local_pharmacy,
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
                          hintText: 'e.g., Groceries, Electronics, Dairy',
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
                        children: [
                          ...colors.map((color) {
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
                          // More colors button
                          GestureDetector(
                            onTap: () async {
                              final color = await _showColorPicker(context, selectedColor);
                              if (color != null) {
                                setDialogState(() {
                                  selectedColor = color;
                                });
                              }
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.orange,
                                    Colors.yellow,
                                    Colors.green,
                                    Colors.blue,
                                    Colors.purple,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade400, width: 1),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Icon Selection
                      Row(
                        children: [
                          const Text(
                            'Choose Icon:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          // Selected icon preview
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selectedColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: selectedColor, width: 2),
                            ),
                            child: Icon(
                              selectedIcon,
                              color: selectedColor,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                color: isSelected
                                    ? selectedColor
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // More icons button
                      GestureDetector(
                        onTap: () async {
                          final IconData? pickedIcon = await _showIconPicker(context, selectedIcon, selectedColor);
                          if (pickedIcon != null) {
                            setDialogState(() {
                              selectedIcon = pickedIcon;
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.apps, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'More icons...',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
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
                                          : 'Custom super market category',
                                      parentId: superMarketCategory?.id,
                                      iconCode: selectedIcon.codePoint,
                                      colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                                    );

                                    // Refresh the child categories
                                    await _refreshChildCategories();

                                    // Close loading dialog
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
              ),
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
                // Capture scaffold context before closing dialogs
                final scaffoldContext = context;

                try {
                  // Close both dialogs
                  Navigator.of(confirmContext).pop();
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.of(dialogContext).pop();
                  }

                  // Show loading dialog
                  _showLoadingDialog(scaffoldContext, subCategory.name, action: 'Deleting');

                  // Delete the child category from the database
                  await CategoryService.deleteCategory(subCategory.id);

                  // Refresh the child categories
                  await _refreshChildCategories();

                  // Close loading dialog
                  _closeLoadingDialog();

                  // Show success message
                  if (mounted) {
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
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
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

  void _showAddCategoryDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    
    Color selectedColor = Colors.green.shade500;
    IconData selectedIcon = Icons.category;
    
    BuildContext? loadingDialogContext;
    
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
      Icons.shopping_cart,
      Icons.shopping_bag,
      Icons.store,
      Icons.local_grocery_store,
      Icons.restaurant,
      Icons.local_cafe,
      Icons.cleaning_services,
      Icons.local_pharmacy,
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
                          hintText: 'e.g., Groceries, Electronics, Dairy',
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
                      // More colors button
                      GestureDetector(
                        onTap: () async {
                          final Color? pickedColor = await _showColorPicker(context, selectedColor);
                          if (pickedColor != null) {
                            setDialogState(() {
                              selectedColor = pickedColor;
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.palette, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'More colors...',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Icon Selection
                      Row(
                        children: [
                          const Text(
                            'Choose Icon:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          // Selected icon preview
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selectedColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: selectedColor, width: 2),
                            ),
                            child: Icon(
                              selectedIcon,
                              color: selectedColor,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                color: isSelected
                                    ? selectedColor
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // More icons button
                      GestureDetector(
                        onTap: () async {
                          final IconData? pickedIcon = await _showIconPicker(context, selectedIcon, selectedColor);
                          if (pickedIcon != null) {
                            setDialogState(() {
                              selectedIcon = pickedIcon;
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.apps, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'More icons...',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      
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
                                if (nameController.text.isNotEmpty && superMarketCategory != null) {
                                  final scaffoldContext = context;
                                  final messenger = ScaffoldMessenger.of(scaffoldContext);
                                  
                                  try {
                                    // Close the dialog first
                                    if (Navigator.canPop(dialogContext)) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                    
                                    // Show loading dialog
                                    _showLoadingDialog(scaffoldContext, nameController.text, action: 'Creating');
                                    
                                    // Create the new child category
                                    await CategoryService.createCategoryForAccount(
                                      name: nameController.text,
                                      description: descriptionController.text.isNotEmpty
                                          ? descriptionController.text
                                          : 'Custom super market category',
                                      parentId: superMarketCategory!.id,
                                      iconCode: selectedIcon.codePoint,
                                      colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                                    );

                                    // Refresh the child categories
                                    await _refreshChildCategories();

                                    // Close loading dialog
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
              ),
            );
          },
        );
      },
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
                                // Header Section
                                SliverToBoxAdapter(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade600,
                                          Colors.green.shade400,
                                          Colors.green.shade300,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.25),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.1),
                                          blurRadius: 40,
                                          offset: const Offset(0, 16),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.local_grocery_store, color: Colors.white, size: 36),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Super Market',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          superMarketCategory?.description ?? 'Manage your grocery and retail products',
                                          style: const TextStyle(
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
                                          ),
                                        ),
                                        FloatingActionButton(
                                          onPressed: _showAddCategoryDialog,
                                          backgroundColor: Colors.green.shade500,
                                          child: const Icon(Icons.add, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Grid of child categories
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
                                        final color = category.color;

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
                                                  // Background pattern
                                                  Positioned.fill(
                                                    child: Opacity(
                                                      opacity: 0.08,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(16),
                                                          image: const DecorationImage(
                                                            image: AssetImage('assets/images/SuperMarket.png'),
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Content
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
                                                            GestureDetector(
                                                              onTap: () => _showEditCategoryDialog(category),
                                                              child: Container(
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
                                                                '🛒 $productCount ${productCount == 1 ? 'product' : 'products'}',
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
