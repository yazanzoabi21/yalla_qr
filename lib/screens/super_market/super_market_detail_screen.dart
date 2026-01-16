import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../services/category_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: Navbar(
        showBackButton: true,
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
              : Column(
                  children: [
                    // Category header
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              childCategory?.icon ?? Icons.category,
                              size: 32,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  childCategory?.name ?? 'Super Market',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (childCategory?.description != null)
                                  Text(
                                    childCategory!.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Products section
                    Expanded(
                      child: products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 80,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Products Yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: products.length,
                                itemBuilder: (context, index) {
                                  final product = products[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.grey.shade200,
                                        ),
                                        child: product.imageUrl != null
                                            ? Image.network(
                                                product.imageUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.image,
                                                color: Colors.grey.shade400,
                                              ),
                                      ),
                                      title: Text(
                                        product.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (product.description != null)
                                            Text(product.description!),
                                          const SizedBox(height: 4),
                                          Text(
                                            product.formattedPrice,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: product.inStock ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          product.inStock ? 'In Stock' : 'Out',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: product.inStock
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
