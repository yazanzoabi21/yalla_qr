import 'dart:io';

import 'package:flutter/material.dart';

import '../../widgets/navbar.dart';
import '../../services/camera_service.dart';
import '../../services/category_service.dart';
import '../../services/currency_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';
import '../../models/product.dart';

class SuperMarketDetailScreen extends StatefulWidget {
  final String parentCategoryId;
  final String childCategoryId;

  const SuperMarketDetailScreen({
    super.key,
    required this.parentCategoryId,
    required this.childCategoryId,
  });

  @override
  State<SuperMarketDetailScreen> createState() => _SuperMarketDetailScreenState();
}

class _SuperMarketDetailScreenState extends State<SuperMarketDetailScreen> {
  Category? childCategory;
  List<Product> products = [];
  bool isLoading = true;
  String? errorMessage;
  double usdRate = 0.0;
  final Map<String, bool> _expandedDescriptions = <String, bool>{};
  bool _hasChanges = false; // Track if products were added/deleted/updated

  @override
  void initState() {
    super.initState();
    _loadUsdRate();
    _loadData();
  }

  String _formatLbpInput(num value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load the child category details
      final category = await CategoryService.getCategoryById(widget.childCategoryId);
      if (category == null) throw Exception('Category not found');

      // Load products for this category
      final loadedProducts = await ProductService.getProductsByCategory(widget.childCategoryId);

      if (!mounted) return;

      setState(() {
        childCategory = category;
        products = loadedProducts;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadUsdRate() async {
    try {
      usdRate = await CurrencyService.getUsdRate();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = childCategory?.color ?? Colors.blue;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
        title: Text(
          childCategory?.name ?? 'Category',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
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
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
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
                                color,
                                color.withOpacity(0.85),
                                color.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(childCategory?.icon ?? Icons.category, color: Colors.white, size: 32),
                              const SizedBox(height: 14),
                              Text(
                                childCategory?.name ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                childCategory?.description ?? 'Manage products in this category',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Add Product Images
                        Text(
                          'Add Product Images',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).textTheme.titleMedium?.color,
                            ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _captureProductImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: (childCategory?.color ?? Colors.blue).withOpacity(0.14), width: 1.8),
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).cardColor
                                        : (childCategory?.color ?? Colors.blue).withOpacity(0.06),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.blue.withOpacity(0.15),
                                        child: Icon(Icons.add_photo_alternate_rounded, color: Colors.blue.shade700, size: 28),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tap to add product image',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
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

                        const SizedBox(height: 28),

                        // Products header
                        Row(
                          children: [
                            Text(
                              '${childCategory?.name ?? 'Category'} Products',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).textTheme.titleMedium?.color,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${products.length} ${products.length == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  color: childCategory?.color ?? Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (products.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).cardColor
                                  : color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: color.withOpacity(0.14)),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).shadowColor.withOpacity(0.03),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withOpacity(0.12),
                                  ),
                                  child: Icon(Icons.anchor, size: 42, color: color),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'No products added yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Start by adding your first product',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextButton.icon(
                                  onPressed: _captureProductImage,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    foregroundColor: Colors.white,
                                    backgroundColor: color,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                  label: const Text(
                                    'Add product image',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.78,
                            ),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final bool isOutOfStock = product.quantity <= 0;
                              return Opacity(
                                opacity: isOutOfStock ? 0.5 : 1.0,
                                child: GestureDetector(
                                  onTap: isOutOfStock ? null : () => _showProductDetails(product),
                                  child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor.withOpacity(isOutOfStock ? 0.06 : 0.12),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).shadowColor.withOpacity(isOutOfStock ? 0.02 : 0.06),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                    child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                              child: Container(
                                                width: double.infinity,
                                                color: Theme.of(context).cardColor,
                                                child: product.imageUrl != null
                                                    ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                                                    : Icon(Icons.image_outlined, size: 48, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: product.quantity > 0 ? Colors.green.shade700 : Colors.red.shade600,
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.08),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  product.quantity > 0 ? 'In Stock' : 'Out of Stock',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (!isOutOfStock)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: GestureDetector(
                                                  onTap: () => _showEditProductDialog(product),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).cardColor,
                                                      borderRadius: BorderRadius.circular(10),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Theme.of(context).shadowColor.withOpacity(0.05),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.secondary),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              product.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if (product.description?.isNotEmpty == true) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                product.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                                  fontSize: 12,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Text(
                                              product.priceLbp != null && product.priceUsd != null
                                                  ? 'LBP ${_formatLbpInput(product.priceLbp!)} / \$${product.priceUsd!.toStringAsFixed(1)}'
                                                  : product.formattedPrice,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: childCategory?.color ?? Theme.of(context).colorScheme.primary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () async {
                                                    if (product.quantity > 0) {
                                                      try {
                                                        final updated = await ProductService.updateProductQuantity(
                                                          productId: product.id,
                                                          quantity: product.quantity - 1,
                                                        );
                                                        if (mounted) {
                                                          setState(() {
                                                            products[index] = updated;
                                                            _hasChanges = true;
                                                          });
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Failed to update stock: $e')),
                                                          );
                                                        }
                                                      }
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Theme.of(context).dividerColor,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.remove,
                                                      size: 18,
                                                      color: Theme.of(context).iconTheme.color?.withOpacity(0.85),
                                                    ),
                                                  ),
                                                ),  
                                                Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  child: Text(
                                                    '${product.quantity}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 16,
                                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () async {
                                                    try {
                                                      final updated = await ProductService.updateProductQuantity(
                                                        productId: product.id,
                                                        quantity: product.quantity + 1,
                                                      );
                                                      if (mounted) {
                                                        setState(() {
                                                          products[index] = updated;
                                                          _hasChanges = true;
                                                        });
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Failed to update stock: $e')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                    child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Theme.of(context).dividerColor,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.add,
                                                      size: 18,
                                                      color: Theme.of(context).iconTheme.color?.withOpacity(0.85),
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
                              ));
                            },
                          ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  void _captureProductImage() async {
    final imageFile = await CameraService.showImageSourceDialog(context);
    if (imageFile != null) {
      final added = await _showAddProductDialog(capturedImage: imageFile);
      if (added == true) {
        _hasChanges = true;
        await _loadData();
      }
    }
  }

  Future<bool?> _showAddProductDialog({File? capturedImage}) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController priceLbpController = TextEditingController();
    final TextEditingController priceUsdController = TextEditingController();
    bool isUploading = false;

    if (usdRate > 0) {
      _setupPriceListeners(priceLbpController, priceUsdController);
    } else {
      _loadUsdRate().then((_) {
        _setupPriceListeners(priceLbpController, priceUsdController);
      });
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Product',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: childCategory?.color ?? Colors.blue,
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
                      GestureDetector(
                        onTap: () async {
                          if (!isUploading) {
                            final newImage = await CameraService.showImageSourceDialog(context);
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
                            color: (childCategory?.color ?? Colors.blue).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (childCategory?.color ?? Colors.blue).withOpacity(0.3),
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
                                              final newImage = await CameraService.showImageSourceDialog(context);
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
                                      color: childCategory?.color ?? Colors.blue,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tap to add product image',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: childCategory?.color ?? Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Camera or Gallery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: (childCategory?.color ?? Colors.blue).withOpacity(0.7),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isUploading ? null : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isUploading
                                  ? null
                                  : () async {
                                      if (nameController.text.isNotEmpty) {
                                        setDialogState(() {
                                          isUploading = true;
                                        });

                                        if (priceLbpController.text.isNotEmpty && priceUsdController.text.isEmpty && usdRate > 0) {
                                          final lbpValue = double.tryParse(priceLbpController.text.replaceAll(',', ''));
                                          if (lbpValue != null) {
                                            priceUsdController.text = (lbpValue / usdRate).toStringAsFixed(2);
                                          }
                                        }

                                        if (priceUsdController.text.isNotEmpty && priceLbpController.text.isEmpty && usdRate > 0) {
                                          final usdValue = double.tryParse(priceUsdController.text);
                                          if (usdValue != null) {
                                            priceLbpController.text = (usdValue * usdRate).toStringAsFixed(0);
                                          }
                                        }

                                        await _createProduct(
                                          name: nameController.text,
                                          description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                                          priceLbp: priceLbpController.text.isNotEmpty
                                              ? double.tryParse(priceLbpController.text.replaceAll(',', ''))
                                              : null,
                                          priceUsd: priceUsdController.text.isNotEmpty ? double.tryParse(priceUsdController.text) : null,
                                          imageFile: capturedImage,
                                        );

                                        if (context.mounted) {
                                          Navigator.of(context).pop(true);
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter a product name'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: childCategory?.color ?? Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: isUploading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Saving...', softWrap: false),
                                      ],
                                    )
                                  : const Text('Save Product', softWrap: false),
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
          final formatted = _formatLbpInput(value);
          if (lbpController.text != formatted) {
            final selectionIndex =
                formatted.length - (lbpController.text.length - lbpController.selection.end);
            lbpController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(
                offset: selectionIndex.clamp(0, formatted.length),
              ),
            );
          }

          if (usdRate > 0) {
            final usd = value / usdRate;
            usdController.text = usd.toStringAsFixed(2);
          }
        }
      } else {
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
          final lbp = value * usdRate;
          lbpController.text = _formatLbpInput(lbp);
        }
      } else {
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
      final categoryId = childCategory?.id ?? widget.childCategoryId;
      String? imageUrl;

      if (imageFile != null) {
        try {
          final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          imageUrl = await CameraService.uploadImageToSupabase(imageFile, fileName);
        } catch (e) {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "$name" added successfully!'),
            backgroundColor: childCategory?.color ?? Colors.blue,
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

  void _showProductDetails(Product product) {
    final Color accent = childCategory?.color ?? Colors.blue;
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
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.8)],
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
                                  color: Colors.white.withOpacity(0.2),
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
                                  color: Colors.white.withOpacity(0.2),
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

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: product.imageUrl != null
                                  ? () => _showImagePreviewDialog(product.imageUrl!, context)
                                  : null,
                              child: Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accent.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
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
                                                color: accent.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                Icons.local_mall,
                                                color: accent,
                                                size: 48,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.local_mall,
                                        color: accent,
                                        size: 48,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildDetailRow('Name:', product.name),
                            _buildExpandableDetailRow(
                              'Description:',
                              product.description?.isNotEmpty == true ? product.description! : 'No description',
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
                              product.inStock && product.quantity > 0
                                  ? 'In Stock (${product.quantity})'
                                  : 'Out of Stock',
                              valueTextColor: product.inStock && product.quantity > 0
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                              valueBgColor: product.inStock && product.quantity > 0
                                  ? const Color(0xFFE7F7EA)
                                  : const Color(0xFFFDE8E7),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Created:', _formatDate(product.createdAt)),

                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE57373), Color(0xFFEF5350)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
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
                                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
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
    final Color accent = childCategory?.color ?? Colors.blue;
    final nameController = TextEditingController(text: product.name);
    final descriptionController = TextEditingController(text: product.description ?? '');
    final priceLbpController = TextEditingController(
      text: product.priceLbp != null ? _formatLbpInput(product.priceLbp!) : '',
    );
    final priceUsdController = TextEditingController(
      text: product.priceUsd?.toString() ?? '',
    );

    if (usdRate == 0.0) {
      _loadUsdRate().then((_) {
        _setupPriceListeners(priceLbpController, priceUsdController);
      });
    } else {
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
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        if (updatedImage == null && product.imageUrl != null) {
                          final result = await showModalBottomSheet<String>(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                                      border: Border.all(color: Theme.of(context).dividerColor),
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
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        optionCard(icon: Icons.zoom_out_map, label: 'View Image', color: Colors.deepPurple, value: 'view'),
                                        const SizedBox(width: 16),
                                        optionCard(icon: Icons.camera_alt, label: 'Camera', color: Colors.blue, value: 'camera'),
                                        const SizedBox(width: 16),
                                        optionCard(icon: Icons.photo_library, label: 'Gallery', color: Colors.green, value: 'gallery'),
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
                            final newImg = await CameraService.captureImageFromCamera();
                            if (newImg != null) setDialogState(() => updatedImage = newImg);
                          } else if (result == 'gallery') {
                            final newImg = await CameraService.pickImageFromGallery();
                            if (newImg != null) setDialogState(() => updatedImage = newImg);
                          }
                        } else {
                          final newImg = await CameraService.showImageSourceDialog(context);
                          if (newImg != null) setDialogState(() => updatedImage = newImg);
                        }
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: accent.withOpacity(0.1),
                        ),
                        child: updatedImage != null
                            ? Image.file(updatedImage!, fit: BoxFit.cover)
                            : product.imageUrl != null
                                ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                                : Icon(Icons.local_mall, size: 48, color: accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceLbpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Price (LBP)', prefixText: 'LBP '),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceUsdController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Price (USD)', prefixText: '\$ '),
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
                            style: TextButton.styleFrom(backgroundColor: Colors.grey.shade200),
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
                                      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      imageUrl = await CameraService.uploadImageToSupabase(updatedImage!, fileName);
                                    }

                                    await ProductService.updateProduct(
                                      productId: product.id,
                                      name: nameController.text,
                                      description: descriptionController.text,
                                      priceLbp: double.tryParse(priceLbpController.text.replaceAll(',', '')),
                                      priceUsd: double.tryParse(priceUsdController.text),
                                      imageUrl: imageUrl,
                                    );

                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      await _loadData();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteProduct(Product product) async {
    try {
      await ProductService.deleteProduct(product.id);
      _hasChanges = true;
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${product.name}" removed successfully!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove product: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

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
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                color: Theme.of(context).textTheme.bodyMedium?.color,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: valueBgColor != null ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : EdgeInsets.zero,
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
                  color: valueTextColor ?? const Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableDetailRow(String label, String value, String productId, [Function(VoidCallback)? setDialogState]) {
    final bool isExpanded = _expandedDescriptions[productId] ?? false;
    final int? maxLines = isExpanded ? null : 3;

    final textSpan = TextSpan(
      text: value,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    );

    textPainter.layout(maxWidth: 250);
    final bool isTextOverflowing = textPainter.didExceedMaxLines;
    final Color accent = childCategory?.color ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                color: Theme.of(context).textTheme.bodyMedium?.color,
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
                        if (setDialogState != null) {
                          setDialogState(() {
                            _expandedDescriptions[productId] = !isExpanded;
                          });
                        } else {
                          setState(() {
                            _expandedDescriptions[productId] = !isExpanded;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              isExpanded ? 'Show less' : 'Show more',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
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
