import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_card.dart';

typedef ProductCallback = Future<void> Function(Product product, int index);

class CategoryProductsGrid extends StatelessWidget {
  final List<Product> products;
  final Color accentColor;
  final void Function(Product product, int index)? onTap;
  final void Function(Product product, int index)? onEdit;
  final ProductCallback? onIncrement;
  final ProductCallback? onDecrement;

  const CategoryProductsGrid({
    super.key,
    required this.products,
    required this.accentColor,
    this.onTap,
    this.onEdit,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
        return ProductCard(
          product: product,
          accentColor: accentColor,
          onTap: onTap != null ? () => onTap!(product, index) : null,
          onEdit: onEdit != null ? () => onEdit!(product, index) : null,
          onIncrement: onIncrement != null ? () => onIncrement!(product, index) : null,
          onDecrement: onDecrement != null ? () => onDecrement!(product, index) : null,
        );
      },
    );
  }
}
