import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/cart.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../widgets/navbar.dart';
import 'product_detail_screen.dart';

/// Cart screen showing all items for a specific organization
class CartScreen extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const CartScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isCheckingOut = false;

  String _formatNumber(double number) {
    final formatted = number.toStringAsFixed(0);
    final parts = <String>[];
    for (int i = formatted.length - 1; i >= 0; i -= 3) {
      final start = i - 2 >= 0 ? i - 2 : 0;
      parts.insert(0, formatted.substring(start, i + 1));
    }
    return parts.join(',');
  }

  Future<void> _handleCheckout(Cart cart) async {
    // Check if user is logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to checkout'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Load saved account/profile info for current user to prefill form
    Map<String, dynamic>? accountProfile;
    try {
      final profiles = await Supabase.instance.client
          .from('accounts')
          .select('*')
          .eq('owner_id', user.id)
          .limit(1);

      if (profiles is List && profiles.isNotEmpty) {
        accountProfile = profiles.first as Map<String, dynamic>?;
      }
    } catch (e) {
      // ignore - proceed without prefill
    }

    // Show checkout form dialog
    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final nameController = TextEditingController(
          text: accountProfile != null ? accountProfile['name'] ?? '' : '');
        final phoneController = TextEditingController(
          text: accountProfile != null ? accountProfile['phone'] ?? '' : '');
        final addressController = TextEditingController(
          text: accountProfile != null
            ? accountProfile['location_address'] ?? ''
            : '');
        final notesController = TextEditingController();

        bool isValid() {
          return nameController.text.trim().isNotEmpty &&
              phoneController.text.trim().isNotEmpty &&
              addressController.text.trim().isNotEmpty;
        }

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Checkout Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order from ${widget.organizationName}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery address',
                    ),
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional notes (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid()
                    ? () {
                        Navigator.pop(context, {
                          'contact_name': nameController.text.trim(),
                          'delivery_phone': phoneController.text.trim(),
                          'delivery_address': addressController.text.trim(),
                          'notes': notesController.text.trim(),
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Place Order'),
              ),
            ],
          );
        });
      },
    );

    if (result == null) return;

    setState(() {
      _isCheckingOut = true;
    });

    try {
      final orderService = OrderService();
      final cartService = CartService();

      final orders = await orderService.createOrdersFromCarts(
        [cart],
        customerInfo: result,
      );

      if (orders.isNotEmpty) {
        // Clear cart after successful checkout
        cartService.clearCart(widget.organizationId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Order placed successfully!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Pop back to previous screen
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartService = CartService();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // appBar: Navbar(
      //   showMenuButton: false,
      //   organizationAccountId: organizationId,
      //   organizationName: organizationName,
      //   accentColor: Colors.blue,
      // ),
      body: ListenableBuilder(
        listenable: cartService,
        builder: (context, _) {
          final cart = cartService.getCart(widget.organizationId, widget.organizationName);

          return Column(
            children: [
              // Header
              Container(
                color: theme.cardColor,
                padding: const EdgeInsets.only(top: 60, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shopping Cart',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.organizationName,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
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
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
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
                            Text(
                              'Total Items:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
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
                            Text(
                              'Total Price:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Flexible(
                              child: _buildTotalPrice(cart),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isCheckingOut ? null : () {
                              _handleCheckout(cart);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: theme.disabledColor,
                            ),
                            child: _isCheckingOut
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Processing...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shopping_bag_outlined, size: 22),
                                      SizedBox(width: 12),
                                      Text(
                                        'Checkout',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
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
                organizationId: widget.organizationId,
                organizationName: widget.organizationName,
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
                        color: Colors.red.shade600.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel, size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600,
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
                    final ok = cartService.incrementQuantity(widget.organizationId, item.product.id);
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
                      cartService.decrementQuantity(widget.organizationId, item.product.id);
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
              cartService.removeFromCart(widget.organizationId, item.product);
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
              cartService.clearCart(widget.organizationId);
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
