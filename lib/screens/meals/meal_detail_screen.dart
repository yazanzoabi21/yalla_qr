import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/camera_service.dart';
import '../../services/currency_service.dart';

class MealDetailScreen extends StatefulWidget {
  final Map<String, dynamic> meal;
  final Function(Map<String, dynamic>) onProductAdded;

  const MealDetailScreen({
    super.key,
    required this.meal,
    required this.onProductAdded,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  // Helper to format LBP price with commas
  String _formatLbpInput(num value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  List<Product> mealProducts = [];
  bool isLoading = true;
  String? errorMessage;
  double usdRate = 0.0;

  Color get inStockColor => Colors.green.shade700;
  Color get outOfStockColor => Colors.red.shade600;

  Color get inStockBg => Colors.green.shade700.withOpacity(0.12);
  Color get outOfStockBg => Colors.red.shade600.withOpacity(0.12);


  // Map to store product quantities by product ID (using String since product.id is String)
  Map<String, int> productQuantities = <String, int>{};
  
  // Map to store expanded state for descriptions by product ID
  Map<String, bool> expandedDescriptions = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadUsdRate();
    _loadProductsAndQuantities();
  }

  Future<void> _loadProductsAndQuantities() async {
    // First load saved quantities
    await _loadSavedQuantities();
    // Then load products
    await _loadProducts();
  }

  Future<void> _loadSavedQuantities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quantitiesJson = prefs.getString(
        'product_quantities_${widget.meal['id']}',
      );
      if (quantitiesJson != null) {
        final Map<String, dynamic> saved = json.decode(quantitiesJson);
        productQuantities = saved.map(
          (key, value) => MapEntry(key, value as int),
        );
        debugPrint('Loaded saved quantities: $productQuantities');
      } else {
        debugPrint('No saved quantities found for meal ${widget.meal['id']}');
      }
    } catch (e) {
      debugPrint('Error loading saved quantities: $e');
      // Initialize empty map on error
      productQuantities = <String, int>{};
    }
  }

  Future<void> _saveQuantities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quantitiesJson = json.encode(productQuantities);
      await prefs.setString(
        'product_quantities_${widget.meal['id']}',
        quantitiesJson,
      );
      debugPrint('Saved quantities: $productQuantities');
    } catch (e) {
      debugPrint('Error saving quantities: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get the category ID from the meal data
      final categoryId = widget.meal['id'] as String;

      // Fetch products for this category
      final products = await ProductService.getProductsByCategory(
        categoryId,
      );

      setState(() {
        mealProducts = products;
        isLoading = false;

        // Initialize quantities for new products only (don't overwrite saved quantities)
        for (var product in products) {
          if (!productQuantities.containsKey(product.id)) {
            productQuantities[product.id] = 1;
          }
        }

        // Save the updated quantities (in case new products were added)
        _saveQuantities();
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _loadUsdRate() async {
    try {
      usdRate = await CurrencyService.getUsdRate();
      debugPrint('USD Rate loaded: $usdRate');
      // Test the conversion with 89,000 LBP
      if (usdRate > 0) {
        final testUsd = 89000 / usdRate;
        debugPrint(
          'Test conversion: 89,000 LBP = \$${testUsd.toStringAsFixed(2)} USD',
        );
      }
      setState(() {}); // To trigger rebuild if needed
    } catch (e) {
      debugPrint('Error loading USD rate: $e');
      // Set a default rate if loading fails (you can adjust this value)
      usdRate = 89000.0; // Default LBP to USD rate
      setState(() {});
    }
  }

  @override
  void dispose() {
    _saveQuantities(); // Save quantities when leaving the page
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.meal['name'],
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: widget.meal['color'],
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.meal['color'],
                    widget.meal['color'].withValues(alpha: 0.8),
                    widget.meal['color'].withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.meal['color'].withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.meal['icon'], color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    widget.meal['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.meal['description'],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Product Image Capture Section
            Text(
              'Add Product Images',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Camera Capture Area
                  GestureDetector(
                    onTap: _captureProductImage,
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.meal['color'].withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: widget.meal['color'].withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: widget.meal['color'],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to add product image',
                            style: TextStyle(
                              fontSize: 17,
                              color: widget.meal['color'],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Products in this meal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.meal['name']} Products',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.meal['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${mealProducts.length} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.meal['color'],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Products Grid with fixed height and better scrolling
            SizedBox(
              height: 600, // Fixed height for scrollable content
              child: isLoading
                        ? Center(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text('Loading products...', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        ],
                      ),
                    )
                  : errorMessage != null
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: outOfStockColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline,
                              size: 48,
                              color: outOfStockColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Error loading products',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadProducts,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.meal['color'],
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : mealProducts.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: widget.meal['color'].withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.meal['icon'],
                              size: 48,
                              color: widget.meal['color'].withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No products added yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by adding your first product',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.45, // Reduced from 0.50 to 0.45 to make cards taller
                          ),
                      itemCount: mealProducts.length,
                      itemBuilder: (context, index) {
                        final product = mealProducts[index];
                        // Get quantity from map, ensuring we get the saved value
                        int quantity = productQuantities[product.id] ?? 1;

                        return StatefulBuilder(
                          builder: (context, setProductState) {
                            // Update quantity from map in case it changed
                            quantity = productQuantities[product.id] ?? 1;
                            return Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: widget.meal['color'].withValues(alpha: 0.28),
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).shadowColor.withOpacity(0.06),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color: widget.meal['color'].withValues(alpha: 0.12),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // 🟢 Stock label top-left (always full opacity)
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: product.quantity > 0 ? inStockBg : outOfStockBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            product.quantity > 0
                                                ? 'In Stock'
                                                : 'Out of Stock',
                                              style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: product.quantity > 0 ? inStockColor : outOfStockColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Content with conditional opacity
                                      AnimatedOpacity(
                                        duration: const Duration(milliseconds: 200),
                                        opacity: product.quantity > 0 ? 1.0 : 0.4,
                                        child: Column(
                                          children: [
                                            // ✅ Tap to open product details
                                            GestureDetector(
                                              onTap: () {
                                                _showProductDetails(product, index);
                                              },
                                              child: Column(
                                                children: [
                                                  Container(
                                                    height: 140,
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Theme.of(context).cardColor
                                                          : widget.meal['color'].withAlpha(30),
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: widget.meal['color'].withValues(alpha: 0.28),
                                                        width: 1.6,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Theme.of(context).shadowColor.withOpacity(0.04),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: product.imageUrl != null
                                                        ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            child: Image.network(
                                                              product.imageUrl!,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) => Icon(
                                                                    Icons.fastfood,
                                                                    color: widget
                                                                        .meal['color'],
                                                                    size: 44,
                                                                  ),
                                                            ),
                                                          )
                                                        : Icon(
                                                            Icons.fastfood,
                                                            color:
                                                                widget.meal['color'],
                                                            size: 44,
                                                          ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    product.name,
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    product.description != null &&
                                                            product
                                                                .description!
                                                                .isNotEmpty
                                                        ? product.description!
                                                        : 'No description',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(height: 6),

                                            // 💰 Price
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: widget.meal['color'].withAlpha(
                                                  25,
                                                ),
                                                borderRadius: BorderRadius.circular(
                                                  12,
                                                ),
                                              ),
                                              child: Text(
                                                product.priceLbp != null &&
                                                        product.priceUsd != null
                                                    ? 'LBP ${_formatLbpInput(product.priceLbp!)} / \$${product.priceUsd!.toStringAsFixed(1)}'
                                                    : product.formattedPrice,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: widget.meal['color'],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // ➖ Stock quantity ➕ (always full opacity)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              if (product.quantity > 0) {
                                                try {
                                                  final updatedProduct = await ProductService.updateProductQuantity(
                                                    productId: product.id,
                                                    quantity: product.quantity - 1,
                                                  );
                                                  setState(() {
                                                    mealProducts[index] = updatedProduct;
                                                  });
                                                  setProductState(() {});
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Failed to update stock: $e')),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                          Text(
                                            '${product.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              try {
                                                final updatedProduct = await ProductService.updateProductQuantity(
                                                  productId: product.id,
                                                  quantity: product.quantity + 1,
                                                );
                                                setState(() {
                                                  mealProducts[index] = updatedProduct;
                                                });
                                                setProductState(() {});
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Failed to update stock: $e')),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // 🖊 Edit icon
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showEditProductDialog(product),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceVariant,
                                          shape: BoxShape.circle,
                                        ),
                                      child: ShaderMask(
                                        shaderCallback: (Rect bounds) {
                                          return LinearGradient(
                                            colors: [
                                              Colors.purple,
                                              Colors.blue,
                                              Colors.green,
                                              Colors.orange,
                                              Colors.red,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds);
                                        },
                                        child: const Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
    );
  }

  void _captureProductImage() async {
    // Show camera/gallery options
    final imageFile = await CameraService.showImageSourceDialog(context);
    if (imageFile != null) {
      final added = await _showAddProductDialog(capturedImage: imageFile);
      if (added == true) {
        await _loadProducts();
      }
    }
  }

  Future<bool?> _showAddProductDialog({File? capturedImage}) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController priceLbpController = TextEditingController();
    final TextEditingController priceUsdController = TextEditingController();
    bool isUploading = false;

    // Ensure USD rate is loaded before setting up listeners
    if (usdRate == 0.0) {
      _loadUsdRate().then((_) {
        // Setup both formatting and currency conversion listeners after rate is loaded
        _setupPriceListeners(priceLbpController, priceUsdController);
      });
    } else {
      // Setup both formatting and currency conversion listeners
      _setupPriceListeners(priceLbpController, priceUsdController);
    }

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
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
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Product',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: widget.meal['color'],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            iconSize: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Product Image Preview
                      GestureDetector(
                        onTap: () async {
                          if (!isUploading) {
                            final newImage =
                                await CameraService.showImageSourceDialog(
                                  context,
                                );
                            if (newImage != null) {
                              setDialogState(() {
                                capturedImage = newImage;
                              });
                            }
                          }
                        },
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.meal['color'].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.meal['color'].withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: capturedImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        capturedImage!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    if (!isUploading)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              final newImage =
                                                  await CameraService.showImageSourceDialog(
                                                    context,
                                                  );
                                              if (newImage != null) {
                                                setDialogState(() {
                                                  capturedImage = newImage;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      color: widget.meal['color'],
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tap to add product image',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: widget.meal['color'],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Camera or Gallery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.meal['color'].withValues(
                                          alpha: 0.7,
                                        ),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Fields
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          border: OutlineInputBorder(),
                          hintText: 'Enter product name',
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          hintText: 'Enter product description',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceLbpController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Price (LBP)',
                                border: OutlineInputBorder(),
                                hintText: '0',
                                prefixText: 'LBP ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: priceUsdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Price (USD)',
                                border: OutlineInputBorder(),
                                hintText: '0.00',
                                prefixText: '\$ ',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextButton(
                              onPressed: isUploading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isUploading
                                  ? null
                                  : () async {
                                      if (nameController.text.isNotEmpty) {
                                        setDialogState(() {
                                          isUploading = true;
                                        });

                                        // Ensure price fields are calculated before saving
                                        if (priceLbpController.text.isNotEmpty &&
                                            priceUsdController.text.isEmpty) {
                                          final lbpValue = double.tryParse(
                                            priceLbpController.text.replaceAll(',', ''),
                                          );
                                          if (lbpValue != null && usdRate > 0) {
                                            priceUsdController.text =
                                                (lbpValue / usdRate).toStringAsFixed(2);
                                          }
                                        } else if (priceUsdController.text.isNotEmpty &&
                                            priceLbpController.text.isEmpty) {
                                          final usdValue = double.tryParse(
                                            priceUsdController.text,
                                          );
                                          if (usdValue != null && usdRate > 0) {
                                            priceLbpController.text =
                                                (usdValue * usdRate).toStringAsFixed(0);
                                          }
                                        }

                                        await _createProduct(
                                          name: nameController.text,
                                          description:
                                              descriptionController
                                                  .text
                                                  .isNotEmpty
                                              ? descriptionController.text
                                              : null,
                                          priceLbp:
                                              priceLbpController.text.isNotEmpty
                                              ? double.tryParse(
                                                  priceLbpController.text
                                                      .replaceAll(',', ''),
                                                )
                                              : null,
                                          priceUsd:
                                              priceUsdController.text.isNotEmpty
                                              ? double.tryParse(
                                                  priceUsdController.text,
                                                )
                                              : null,
                                          imageFile: capturedImage,
                                        );

                                        if (context.mounted) {
                                          Navigator.of(context).pop(true);
                                        }
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please enter a product name',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.meal['color'],
                                foregroundColor: Colors.white,
                              ),
                              child: isUploading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Saving...'),
                                      ],
                                    )
                                  : const Text('Save Product'),
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

  void _setupPriceListeners(
    TextEditingController lbpController,
    TextEditingController usdController,
  ) {
    bool updating = false;

    lbpController.addListener(() {
      if (updating) return;
      updating = true;

      final text = lbpController.text.replaceAll(',', '');
      if (text.isNotEmpty) {
        final value = double.tryParse(text);
        if (value != null) {
          // Format LBP with commas
          final formatted = _formatLbpInput(value);
          if (lbpController.text != formatted) {
            final selectionIndex =
                formatted.length -
                (lbpController.text.length - lbpController.selection.end);
            lbpController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(
                offset: selectionIndex.clamp(0, formatted.length),
              ),
            );
          }

          // Convert to USD
          if (usdRate > 0) {
            final usd = value / usdRate;
            debugPrint('Converting LBP $value to USD: $usd (rate: $usdRate)');
            usdController.text = usd.toStringAsFixed(2);
          } else {
            debugPrint('USD rate not available: $usdRate');
          }
        }
      } else {
        // Clear USD field when LBP is empty
        usdController.clear();
      }

      updating = false;
    });

    usdController.addListener(() {
      if (updating) return;
      updating = true;

      final text = usdController.text;
      if (text.isNotEmpty) {
        final value = double.tryParse(text);
        if (value != null && usdRate > 0) {
          // Convert to LBP and format
          final lbp = value * usdRate;
          debugPrint('Converting USD $value to LBP: $lbp (rate: $usdRate)');
          lbpController.text = _formatLbpInput(lbp);
        }
      } else {
        // Clear LBP field when USD is empty
        lbpController.clear();
      }

      updating = false;
    });
  }

  Future<void> _createProduct({
    required String name,
    String? description,
    double? priceLbp,
    double? priceUsd,
    File? imageFile,
  }) async {
    try {
      final categoryId = widget.meal['id'] as String;
      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        try {
          final fileName =
              'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          imageUrl = await CameraService.uploadImageToSupabase(
            imageFile,
            fileName,
          );
        } catch (e) {
          // Continue without image if upload fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      await ProductService.createProduct(
        name: name,
        description: description,
        priceLbp: priceLbp,
        priceUsd: priceUsd,
        imageUrl: imageUrl,
        categoryId: categoryId,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "$name" added successfully!'),
            backgroundColor: widget.meal['color'],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add product: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showProductDetails(Product product, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  minHeight: 400,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient background
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.meal['color'],
                            widget.meal['color'].withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Product Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showEditProductDialog(product);
                                  },
                                  icon: const Icon(Icons.edit, color: Colors.white),
                                  iconSize: 20,
                                  tooltip: 'Edit',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  iconSize: 20,
                                  tooltip: 'Close',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Product Preview with enhanced styling
                            GestureDetector(
                              onTap: product.imageUrl != null
                                  ? () => _showImagePreviewDialog(
                                      product.imageUrl!,
                                      context,
                                    )
                                  : null,
                              child: Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  // Use a subtle gradient that keeps the meal accent,
                                  // but prefers the card surface so it reads well in dark mode.
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).cardColor,
                                      widget.meal['color'].withValues(alpha: 0.04),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  // Thicker, more opaque border to make the card pop
                                  border: Border.all(
                                    color: widget.meal['color'].withValues(alpha: 0.32),
                                    width: 2.4,
                                  ),
                                  boxShadow: [
                                    // Slight colored glow from the meal accent
                                    BoxShadow(
                                      color: widget.meal['color'].withValues(alpha: 0.12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                    // Small neutral shadow for depth across themes
                                    BoxShadow(
                                      color: Theme.of(context).shadowColor.withOpacity(0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: product.imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          product.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: widget.meal['color'].withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                Icons.fastfood,
                                                color: widget.meal['color'],
                                                size: 48,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.fastfood,
                                        color: widget.meal['color'],
                                        size: 48,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Details section
                            _buildDetailRow('Name:', product.name),
                            _buildExpandableDetailRow(
                              'Description:',
                              product.description ?? 'No description',
                              product.id,
                              setDialogState,
                            ),
                            _buildDetailRow(
                              'Price:',
                              product.priceLbp != null && product.priceUsd != null
                                  ? 'LBP ${_formatLbpInput(product.priceLbp!)} / \$${product.priceUsd!.toStringAsFixed(2)}'
                                  : product.priceLbp != null
                                  ? 'LBP ${_formatLbpInput(product.priceLbp!)}'
                                  : product.priceUsd != null
                                  ? '\$${product.priceUsd!.toStringAsFixed(2)}'
                                  : product.formattedPrice,
                            ),
                            _buildDetailRow(
                              'Stock Status:',
                              product.quantity > 0
                                  ? 'In Stock (${product.quantity})'
                                  : 'Out of Stock',
                              valueTextColor: product.quantity > 0
                                  ? inStockColor
                                  : outOfStockColor,
                              valueBgColor: product.quantity > 0
                                  ? inStockBg
                                  : outOfStockBg,
                            ),
                            const SizedBox(height: 8),
                            
                            _buildDetailRow('Created:', _formatDate(product.createdAt)),

                            const SizedBox(height: 24),

                            // Enhanced Delete Button
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE57373),
                                    Color(0xFFEF5350),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _deleteProduct(product);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Delete Product',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
            );
          },
        );
      },
    );
  }

  void _showEditProductDialog(Product product) {
    final nameController = TextEditingController(text: product.name);
    final descriptionController = TextEditingController(
      text: product.description ?? '',
    );
    // Format initial value with commas if present
    final priceLbpController = TextEditingController(
      text: product.priceLbp != null ? _formatLbpInput(product.priceLbp!) : '',
    );
    final priceUsdController = TextEditingController(
      text: product.priceUsd?.toString() ?? '',
    );

    // Ensure USD rate is loaded before setting up listeners
    if (usdRate == 0.0) {
      _loadUsdRate().then((_) {
        // Setup both formatting and currency conversion listeners after rate is loaded
        _setupPriceListeners(priceLbpController, priceUsdController);
      });
    } else {
      // Setup both formatting and currency conversion listeners
      _setupPriceListeners(priceLbpController, priceUsdController);
    }

    File? updatedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.meal['color'],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        if (updatedImage == null && product.imageUrl != null) {
                          // Show a custom bottom sheet with View Image, Camera, Gallery
                          final result = await showModalBottomSheet<String>(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (BuildContext ctx) {
                              Widget optionCard({
                                required IconData icon,
                                required String label,
                                required Color color,
                                required String value,
                              }) {
                                return GestureDetector(
                                  onTap: () => Navigator.of(ctx).pop(value),
                                    child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).shadowColor.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 38, color: color),
                                        const SizedBox(height: 10),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).dividerColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Select Option',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        optionCard(
                                          icon: Icons.zoom_out_map,
                                          label: 'View Image',
                                          color: Colors.deepPurple,
                                          value: 'view',
                                        ),
                                        const SizedBox(width: 16),
                                        optionCard(
                                          icon: Icons.camera_alt,
                                          label: 'Camera',
                                          color: Colors.blue,
                                          value: 'camera',
                                        ),
                                        const SizedBox(width: 16),
                                        optionCard(
                                          icon: Icons.photo_library,
                                          label: 'Gallery',
                                          color: Colors.green,
                                          value: 'gallery',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                          );
                          if (result == 'view') {
                            _showImagePreviewDialog(product.imageUrl!, context);
                          } else if (result == 'camera') {
                            final newImg =
                                await CameraService.captureImageFromCamera();
                            if (newImg != null) {
                              setDialogState(() => updatedImage = newImg);
                            }
                          } else if (result == 'gallery') {
                            final newImg =
                                await CameraService.pickImageFromGallery();
                            if (newImg != null) {
                              setDialogState(() => updatedImage = newImg);
                            }
                          }
                        } else {
                          // Default: just pick new image
                          final newImg =
                              await CameraService.showImageSourceDialog(
                                context,
                              );
                          if (newImg != null) {
                            setDialogState(() => updatedImage = newImg);
                          }
                        }
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: widget.meal['color'].withOpacity(0.1),
                        ),
                        child: updatedImage != null
                            ? Image.file(updatedImage!, fit: BoxFit.cover)
                            : product.imageUrl != null
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.fastfood,
                                size: 48,
                                color: widget.meal['color'],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceLbpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price (LBP)',
                              prefixText: 'LBP ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceUsdController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price (USD)',
                              prefixText: '\$ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    setDialogState(() => isUploading = true);
                                    String? imageUrl = product.imageUrl;

                                    if (updatedImage != null) {
                                      final fileName =
                                          'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      imageUrl =
                                          await CameraService.uploadImageToSupabase(
                                            updatedImage!,
                                            fileName,
                                          );
                                    }

                                    await ProductService.updateProduct(
                                      productId: product.id,
                                      name: nameController.text,
                                      description: descriptionController.text,
                                      priceLbp: double.tryParse(
                                        priceLbpController.text.replaceAll(
                                          ',',
                                          '',
                                        ),
                                      ),
                                      priceUsd: double.tryParse(
                                        priceUsdController.text,
                                      ),
                                      imageUrl: imageUrl,
                                    );

                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      _loadProducts();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.meal['color'],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isUploading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Saving...'),
                                    ],
                                  )
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Image preview dialog for product images
  void _showImagePreviewDialog(String imageUrl, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black,
              ),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Future<void> _toggleProductStock(Product product) async {
  //   try {
  //     await ProductService.toggleProductStock(product.id);
  //     await _loadProducts(); // Reload products to reflect the change

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('📦 ${product.name} stock status updated!'),
  //           backgroundColor: widget.meal['color'],
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Failed to update stock status: $e'),
  //           backgroundColor: Colors.red,
  //           duration: const Duration(seconds: 3),
  //         ),
  //       );
  //     }
  //   }
  // }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueTextColor,
    Color? valueBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
          width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: valueBgColor != null 
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                  : EdgeInsets.zero,
              decoration: valueBgColor != null 
                  ? BoxDecoration(
                      color: valueBgColor,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueTextColor ?? Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete "${product.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performDeleteProduct(product);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteProduct(Product product) async {
    try {
      await ProductService.deleteProduct(product.id);
      await _loadProducts(); // Reload products to reflect the change

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${product.name}" deleted successfully!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildExpandableDetailRow(String label, String value, String productId, [Function(VoidCallback)? setDialogState]) {
    final isExpanded = expandedDescriptions[productId] ?? false;
    final maxLines = isExpanded ? null : 3;
    
    // Check if the text is actually long enough to need expanding
    final textSpan = TextSpan(
      text: value,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    );
    
    textPainter.layout(maxWidth: 250); // Approximate dialog width
    final bool isTextOverflowing = textPainter.didExceedMaxLines;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  maxLines: maxLines,
                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (isTextOverflowing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        // Use dialog's setState if provided, otherwise use main widget's setState
                        if (setDialogState != null) {
                          setDialogState(() {
                            expandedDescriptions[productId] = !isExpanded;
                          });
                        } else {
                          setState(() {
                            expandedDescriptions[productId] = !isExpanded;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.meal['color'].withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.meal['color'].withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded 
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: widget.meal['color'],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isExpanded ? 'Show less' : 'Show more',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.meal['color'],
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
