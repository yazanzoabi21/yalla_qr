import 'package:flutter/material.dart';
import '../models/category.dart';

/// Reusable grid view widget for displaying child categories
/// Shows categories in a grid with icons, names, and product counts
class CategoryGridView extends StatelessWidget {
  final List<Category> categories;
  final Map<String, int> productCounts;
  final Map<String, bool>? inCart; // indicates whether category has items in cart (keyed by name)
  final Function(String categoryId) onCategoryTap;
  final Function(Category category) onEditCategory;
  final String? backgroundImagePath;
  final String productLabel; // e.g., "product" or "item"

  const CategoryGridView({
    super.key,
    required this.categories,
    required this.productCounts,
    this.inCart,
    required this.onCategoryTap,
    required this.onEditCategory,
    this.backgroundImagePath,
    this.productLabel = 'product',
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = categories[index];
          final productCount = productCounts[category.id] ?? 0;
          final color = category.color;

          return GestureDetector(
            onTap: () => onCategoryTap(category.id),
            child: Stack(
              children: [
                Card(
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
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.18),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withOpacity(0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background pattern (optional)
                        if (backgroundImagePath != null)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.08,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  image: DecorationImage(
                                    image: AssetImage(backgroundImagePath!),
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
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      category.icon,
                                      color: color,
                                      size: 24,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => onEditCategory(category),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        color: Theme.of(context).iconTheme.color,
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
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary,
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
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '🛒 $productCount ${productCount == 1 ? productLabel : '${productLabel}s'}',
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
                if (inCart != null && inCart![category.name] == true)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_cart,
                        size: 12,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        childCount: categories.length,
      ),
    );
  }
}
