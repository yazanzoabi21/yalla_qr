import 'package:flutter/material.dart';
import '../../models/cart.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../widgets/navbar.dart';
import 'product_detail_screen.dart';

/// Cart screen showing all items for a specific organization
class CartScreen extends StatelessWidget {
  final String organizationId;
  final String organizationName;

  const CartScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  String _formatNumber(double number) {
    final formatted = number.toStringAsFixed(0);
    final parts = <String>[];
    for (int i = formatted.length - 1; i >= 0; i -= 3) {
      final start = i - 2 >= 0 ? i - 2 : 0;
      parts.insert(0, formatted.substring(start, i + 1));
    }
    return parts.join(',');
  }

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // appBar: Navbar(
      //   showMenuButton: false,
      //   organizationAccountId: organizationId,
      //   organizationName: organizationName,
      //   accentColor: Colors.blue,
      // ),
      body: ListenableBuilder(
        listenable: cartService,
        builder: (context, _) {
          final cart = cartService.getCart(organizationId, organizationName);

          return Column(
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(top: 60, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shopping Cart',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            organizationName,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (cart.items.isNotEmpty)
                      Container(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _showClearCartDialog(context, cartService);
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Cart Items
              Expanded(
                child: cart.items.isEmpty
                    ? _buildEmptyCart(context)
                    : RefreshIndicator(
                        onRefresh: () async {
                          // Cart is already listenable, just trigger a rebuild
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: _buildGroupedCartItems(context, cart, cartService),
                      ),
              ),

              // Bottom Summary
              // ...existing code...

              // Bottom Summary
              if (cart.items.isNotEmpty)
                Container(
                  // reduced top padding and keep comfortable bottom padding
                  padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  // avoid adding extra top padding from SafeArea
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Items:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              '${cart.totalItems}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.deepOrange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total Price:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Flexible(
                              child: _buildTotalPrice(cart),
                            ),
                          ],
                        ),
                        // Checkout removed from per-organization cart; available in All Carts screen
                      ],
                    ),
                  ),
                ),
// ...existing code...
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some products to get started',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCartItems(BuildContext context, Cart cart, CartService cartService) {
    // Group items by category
    final Map<String, List<CartItem>> groupedItems = {};
    for (var item in cart.items) {
      final categoryKey = item.categoryName ?? 'Other';
      if (!groupedItems.containsKey(categoryKey)) {
        groupedItems[categoryKey] = [];
      }
      groupedItems[categoryKey]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final categoryName = groupedItems.keys.elementAt(index);
        final items = groupedItems[categoryName]!;
        final categoryColor = items.first.categoryColor ?? Colors.blue;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12, top: index == 0 ? 0 : 16),
              child: Row(
                children: [
                  Icon(
                    Icons.category_rounded,
                    color: categoryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${items.length} ${items.length == 1 ? 'item' : 'items'})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Category Items
            ...items.map((item) => _buildCartItem(context, item, cartService)),
          ],
        );
      },
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, CartService cartService) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to product detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                product: item.product,
                organizationId: organizationId,
                organizationName: organizationName,
                accentColor: item.categoryColor ?? Colors.blue,
                categoryName: item.categoryName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: item.product.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.restaurant,
                          color: Colors.grey.shade400,
                          size: 40,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.restaurant,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
            ),
            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: item.product.isAvailable 
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Show out of stock badge if product is no longer available
                  if (!item.product.isAvailable) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel, size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    item.product.formattedPrice,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: item.product.isAvailable 
                          ? Colors.deepOrange.shade700
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${item.formattedTotalPrice}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Column(
              children: [
                IconButton(
                  onPressed: item.product.isAvailable ? () {
                    final ok = cartService.incrementQuantity(organizationId, item.product.id);
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Cannot add more than available stock')),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } : null,
                  icon: Icon(
                    Icons.add_circle,
                    color: item.product.isAvailable 
                        ? Colors.deepOrange.shade700
                        : Colors.grey.shade400,
                    size: 28,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (item.quantity > 1) {
                      cartService.decrementQuantity(organizationId, item.product.id);
                    } else {
                      _showRemoveItemDialog(context, item, cartService);
                    }
                  },
                  icon: Icon(
                    item.quantity > 1 ? Icons.remove_circle : Icons.delete,
                    color: item.quantity > 1 ? Colors.deepOrange.shade700 : Colors.red,
                    size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showRemoveItemDialog(BuildContext context, CartItem item, CartService cartService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${item.product.name} from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartService.removeFromCart(organizationId, item.product);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartService cartService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartService.clearCart(organizationId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPrice(Cart cart) {
    if (cart.totalPriceLbp != null && cart.totalPriceUsd != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatNumber(cart.totalPriceLbp!)} LBP',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.deepOrange.shade700,
            ),
          ),
          Text(
            '\$${cart.totalPriceUsd!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.deepOrange.shade600,
            ),
          ),
        ],
      );
    } else if (cart.totalPriceLbp != null) {
      return Text(
        '${_formatNumber(cart.totalPriceLbp!)} LBP',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.deepOrange.shade700,
        ),
        textAlign: TextAlign.right,
      );
    } else if (cart.totalPriceUsd != null) {
      return Text(
        '\$${cart.totalPriceUsd!.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.deepOrange.shade700,
        ),
        textAlign: TextAlign.right,
      );
    } else {
      return Text(
        '0',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.right,
      );
    }
  }
}
