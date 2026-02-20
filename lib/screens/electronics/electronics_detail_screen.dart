import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../widgets/add_product_form.dart';
import '../../services/category_service.dart';
import '../../services/currency_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../widgets/category_products_grid.dart';

class ElectronicsDetailScreen extends StatefulWidget {
  final String parentCategoryId;
  final String childCategoryId;

  const ElectronicsDetailScreen({
    Key? key,
    required this.parentCategoryId,
    required this.childCategoryId,
  }) : super(key: key);

  @override
  State<ElectronicsDetailScreen> createState() =>
      _ElectronicsDetailScreenState();
}

class _ElectronicsDetailScreenState extends State<ElectronicsDetailScreen> {
  bool isLoading = true;
  String? errorMessage;
  Category? childCategory;
  List<Product> products = [];
  double usdRate = 0;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUsdRate();
    _loadData();
  }

  Future<void> _loadUsdRate() async {
    try {
      final rate = await CurrencyService.getUsdRate();
      setState(() {
        usdRate = rate ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final category = await CategoryService.getCategoryById(
        widget.childCategoryId,
      );
      final loadedProducts = await ProductService.getProductsByCategory(
        widget.childCategoryId,
      );
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

  void _showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name ?? 'Product'),
        content: Text(product.description ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        childCategory?.color ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(childCategory?.name ?? 'Category'),
        backgroundColor: accent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 100,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No products',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add products',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : CategoryProductsGrid(
                products: products,
                accentColor: accent,
                onTap: (product, index) async {
                  final updated = await showDialog<bool>(
                    context: context,
                    builder: (context) => Dialog(
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: AddProductForm(
                        categoryId: widget.childCategoryId,
                        initialProduct: product,
                        onSaved: (p) {},
                      ),
                    ),
                  );

                  if (updated == true) {
                    await _loadData();
                  }
                },
                onEdit: (product, index) async {
                  final saved = await showDialog<bool>(
                    context: context,
                    builder: (context) => Dialog(
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: AddProductForm(
                        categoryId: widget.childCategoryId,
                        initialProduct: product,
                        onSaved: (p) {},
                      ),
                    ),
                  );

                  if (saved == true) {
                    await _loadData();
                  }
                },
                onIncrement: (product, index) async {
                  final oldProduct = products[index];
                  final oldQty = oldProduct.quantity;
                  final newQty = oldQty + 1;
                  final newProduct = Product(
                    id: oldProduct.id,
                    accountId: oldProduct.accountId,
                    name: oldProduct.name,
                    description: oldProduct.description,
                    priceLbp: oldProduct.priceLbp,
                    priceUsd: oldProduct.priceUsd,
                    imageUrl: oldProduct.imageUrl,
                    inStock: true,
                    quantity: newQty,
                    createdAt: oldProduct.createdAt,
                    categoryId: oldProduct.categoryId,
                  );

                  setState(() => products[index] = newProduct);

                  try {
                    await ProductService.updateProductQuantity(
                      productId: oldProduct.id,
                      quantity: newQty,
                    );
                  } catch (e) {
                    setState(() => products[index] = oldProduct);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update quantity: $e'),
                        ),
                      );
                  }
                },
                onDecrement: (product, index) async {
                  final oldProduct = products[index];
                  if (oldProduct.quantity <= 0) return;
                  final oldQty = oldProduct.quantity;
                  final newQty = oldQty - 1;
                  final newProduct = Product(
                    id: oldProduct.id,
                    accountId: oldProduct.accountId,
                    name: oldProduct.name,
                    description: oldProduct.description,
                    priceLbp: oldProduct.priceLbp,
                    priceUsd: oldProduct.priceUsd,
                    imageUrl: oldProduct.imageUrl,
                    inStock: newQty > 0,
                    quantity: newQty,
                    createdAt: oldProduct.createdAt,
                    categoryId: oldProduct.categoryId,
                  );

                  setState(() => products[index] = newProduct);

                  try {
                    await ProductService.updateProductQuantity(
                      productId: oldProduct.id,
                      quantity: newQty,
                    );
                  } catch (e) {
                    setState(() => products[index] = oldProduct);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update quantity: $e'),
                        ),
                      );
                  }
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: _addProduct,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addProduct() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AddProductForm(
          categoryId: widget.childCategoryId,
          onSaved: (p) {
            _hasChanges = true;
          },
        ),
      ),
    );

    if (created == true) {
      await _loadData();
    }
  }
}
