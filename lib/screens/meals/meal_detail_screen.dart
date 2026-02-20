import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/category_products_grid.dart';
import '../../widgets/add_product_form.dart';

class MealDetailScreen extends StatefulWidget {
  final Map<String, dynamic> meal;
  final Function(Map<String, dynamic>) onProductAdded;

  const MealDetailScreen({
    Key? key,
    required this.meal,
    required this.onProductAdded,
  }) : super(key: key);

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Product> mealProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    try {
      final loaded = await ProductService.getProductsByCategory(widget.meal['id']);
      if (!mounted) return;
      setState(() {
        mealProducts = loaded;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _showProductDetails(Product product, int index) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AddProductForm(
          categoryId: widget.meal['id'],
          initialProduct: product,
          onSaved: (p) {},
        ),
      ),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.meal['color'] as Color? ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(widget.meal['name'] ?? 'Meal'), backgroundColor: accent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : mealProducts.isEmpty
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add products',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : CategoryProductsGrid(
                        products: mealProducts,
                        accentColor: accent,
                        onTap: (p, i) => _showProductDetails(p, i),
                        onIncrement: (p, i) async {
                          final oldProduct = mealProducts[i];
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

                          setState(() => mealProducts[i] = newProduct);

                          try {
                            await ProductService.updateProductQuantity(productId: oldProduct.id, quantity: newQty);
                          } catch (e) {
                            setState(() => mealProducts[i] = oldProduct);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update quantity: $e')));
                          }
                        },
                        onDecrement: (p, i) async {
                          final oldProduct = mealProducts[i];
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

                          setState(() => mealProducts[i] = newProduct);

                          try {
                            await ProductService.updateProductQuantity(productId: oldProduct.id, quantity: newQty);
                          } catch (e) {
                            setState(() => mealProducts[i] = oldProduct);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update quantity: $e')));
                          }
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: AddProductForm(categoryId: widget.meal['id']),
            ),
          );

          if (created == true) {
            await _loadProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
