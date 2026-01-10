import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/navbar.dart';
import '../../widgets/floating_cart_icon.dart';
import '../../widgets/floating_tracking_button.dart';
import 'product_detail_screen.dart';

/// Screen to display products for a specific subcategory of an organization
/// This is a read-only view for clients who scanned the QR code
class OrganizationCategoryProductsScreen extends StatefulWidget {
  final String accountId;
  final String accountName;
  final Map<String, dynamic> category; // Contains: name, description, color, icon, id

  const OrganizationCategoryProductsScreen({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.category,
  });

  @override
  State<OrganizationCategoryProductsScreen> createState() =>
      _OrganizationCategoryProductsScreenState();
}

class _OrganizationCategoryProductsScreenState
    extends State<OrganizationCategoryProductsScreen> {
  List<Product> products = [];
  bool isLoading = true;
  String? errorMessage;
  final CartService _cartService = CartService();

  @override
  void initState() {
    super.initState();
    _initializeCart();
    _loadProducts();
  }

  Future<void> _initializeCart() async {
    await _cartService.initialize();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final categoryId = widget.category['id'] as String;
      final fetchedProducts = await ProductService.getProductsByAccountAndCategory(
        widget.accountId,
        categoryId,
      );

      if (mounted) {
        setState(() {
          products = fetchedProducts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = widget.category['color'] as Color;
    final categoryIcon = widget.category['icon'] as IconData;
    final categoryName = widget.category['name'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // appBar: Navbar(
      //   showMenuButton: false,
      //   organizationAccountId: widget.accountId,
      //   organizationName: widget.accountName,
      //   accentColor: categoryColor,
      // ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header with back button
              Padding(
                // padding: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.only(top: 60, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: categoryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
          // Floating Tracking Button (above cart)
          const FloatingTrackingButton(),
          // Floating Cart Icon
          FloatingCartIcon(
            organizationId: widget.accountId,
            organizationName: widget.accountName,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No products yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This category is currently empty',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final categoryColor = widget.category['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: categoryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Open full product detail screen
          final categoryName = widget.category['name'] as String;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                product: product,
                organizationId: widget.accountId,
                organizationName: widget.accountName,
                accentColor: categoryColor,
                categoryName: categoryName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Header
              Row(
                children: [
                  // Product Image or Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor.withValues(alpha: 0.15),
                          categoryColor.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.restaurant,
                                color: categoryColor,
                                size: 32,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.restaurant,
                            color: categoryColor,
                            size: 32,
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (product.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Price, Stock, and Cart Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stock Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: product.isAvailable
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          product.isAvailable ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: product.isAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          product.stockStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: product.isAvailable ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Quick Add to Cart Button
                  ListenableBuilder(
                    listenable: _cartService,
                    builder: (context, _) {
                      final isInCart = _cartService.isInCart(widget.accountId, product.id);
                      
                      return IconButton(
                        onPressed: product.isAvailable ? () {
                          if (isInCart) {
                            // Remove from cart
                            _cartService.removeFromCart(widget.accountId, product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.remove_shopping_cart, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('${product.name} removed from cart'),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            // Add to cart
                            final categoryColor = widget.category['color'] as Color;
                            final categoryName = widget.category['name'] as String;
                            final added = _cartService.addToCart(
                              widget.accountId,
                              widget.accountName,
                              product,
                              categoryName: categoryName,
                              categoryColor: categoryColor,
                            );
                            if (added) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('${product.name} added to cart'),
                                      ),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.warning, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text('Cannot add more than available stock')),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } : null,
                        icon: Icon(
                          isInCart ? Icons.shopping_cart : Icons.add_shopping_cart,
                          color: product.inStock 
                              ? (isInCart ? Colors.green : categoryColor)
                              : Colors.grey,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: product.inStock
                              ? (isInCart 
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : categoryColor.withValues(alpha: 0.1))
                              : Colors.grey.withValues(alpha: 0.1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
