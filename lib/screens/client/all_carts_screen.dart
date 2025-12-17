import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/cart.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
// navbar import removed (unused)
import 'cart_screen.dart';

/// Screen showing all carts from all organizations
class AllCartsScreen extends StatefulWidget {
  const AllCartsScreen({super.key});

  @override
  State<AllCartsScreen> createState() => _AllCartsScreenState();
}

class _AllCartsScreenState extends State<AllCartsScreen> {
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

  Future<void> _handleCheckout(List<Cart> carts) async {
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
                  Text('You are about to place ${carts.length} order${carts.length > 1 ? 's' : ''}'),
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
        carts,
        customerInfo: result,
      );

      if (orders.isNotEmpty) {
        // Clear all carts after successful checkout
        cartService.clearAllCarts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${orders.length} order${orders.length > 1 ? 's' : ''} placed successfully!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
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
    final cartService = CartService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // appBar: Navbar(
      //   showMenuButton: false,
      //   accentColor: Colors.blue,
      // ),
      body: ListenableBuilder(
        listenable: cartService,
        builder: (context, _) {
          final carts = cartService.getAllCartsWithItems();

          return Column(
            children: [
              // Header
              Container(
                color: Colors.white,
                // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.only(top: 60, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1A1A1A),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Shopping Carts',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${carts.length} ${carts.length == 1 ? 'organization' : 'organizations'}',
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
                    if (carts.isNotEmpty)
                      Container(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Clear all carts',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Clear All Carts'),
                                content: const Text(
                                  'Remove all products from all carts?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Clear All'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              cartService.clearAllCarts();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All carts cleared'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // Cart List
              Expanded(
                child: carts.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: carts.length,
                          itemBuilder: (context, index) {
                            final cart = carts[index];
                            return _buildCartCard(context, cart);
                          },
                        ),
                      ),
              ),

              // Bottom Summary
              if (carts.isNotEmpty)
                Container(
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
                              '${_getTotalItems(carts)}',
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
                            Flexible(child: _buildTotalPrice(carts)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isCheckingOut
                              ? null
                              : () => _handleCheckout(carts),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.deepOrange.shade200,
                          ),
                          child: _isCheckingOut
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
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
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            'No items in cart',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products from organizations to get started',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartCard(BuildContext context, Cart cart) {
    final cartService = CartService();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          // Navigate to specific cart
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CartScreen(
                organizationId: cart.organizationId,
                organizationName: cart.organizationName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Organization Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
                      color: Colors.deepOrange.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cart.organizationName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          '${cart.totalItems} ${cart.totalItems == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Clear single organization cart button
                  if (cart.items.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear this cart',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear Cart'),
                            content: const Text(
                              'Remove all items from this cart?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          cartService.clearCart(cart.organizationId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cart cleared')),
                          );
                        }
                      },
                    ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Price Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Flexible(child: _buildCartPrice(cart)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getTotalItems(List<Cart> carts) {
    return carts.fold(0, (sum, cart) => sum + cart.totalItems);
  }

  Widget _buildTotalPrice(List<Cart> carts) {
    double totalLbp = 0;
    double totalUsd = 0;
    bool hasLbp = false;
    bool hasUsd = false;

    for (var cart in carts) {
      if (cart.totalPriceLbp != null) {
        totalLbp += cart.totalPriceLbp!;
        hasLbp = true;
      }
      if (cart.totalPriceUsd != null) {
        totalUsd += cart.totalPriceUsd!;
        hasUsd = true;
      }
    }

    if (hasLbp && hasUsd) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatNumber(totalLbp)} LBP',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.deepOrange.shade700,
            ),
          ),
          Text(
            '\$${totalUsd.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.deepOrange.shade600,
            ),
          ),
        ],
      );
    } else if (hasLbp) {
      return Text(
        '${_formatNumber(totalLbp)} LBP',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.deepOrange.shade700,
        ),
        textAlign: TextAlign.right,
      );
    } else if (hasUsd) {
      return Text(
        '\$${totalUsd.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.deepOrange.shade700,
        ),
        textAlign: TextAlign.right,
      );
    } else {
      return Text(
        'Price not set',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.right,
      );
    }
  }

  Widget _buildCartPrice(Cart cart) {
    if (cart.totalPriceLbp != null && cart.totalPriceUsd != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatNumber(cart.totalPriceLbp!)} LBP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.deepOrange.shade700,
            ),
          ),
          Text(
            '\$${cart.totalPriceUsd!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
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
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.deepOrange.shade700,
        ),
        textAlign: TextAlign.right,
      );
    } else if (cart.totalPriceUsd != null) {
      return Text(
        '\$${cart.totalPriceUsd!.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 18,
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
