import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';

/// Full-screen product detail view with image zoom and cart actions
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String organizationId;
  final String organizationName;
  final Color accentColor;
  final String? categoryName;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.organizationId,
    required this.organizationName,
    required this.accentColor,
    this.categoryName,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final CartService _cartService = CartService();

  void _openImageDialog() {
    if (widget.product.imageUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          final innerTheme = Theme.of(context);
          return Scaffold(
            backgroundColor: innerTheme.scaffoldBackgroundColor,
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: GestureDetector(
                      onDoubleTap: () {
                        // Double tap handled by InteractiveViewer
                      },
                      child: Image.network(
                        widget.product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 100,
                            color: innerTheme.colorScheme.onSurface.withOpacity(
                              0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: innerTheme.cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: innerTheme.shadowColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: innerTheme.colorScheme.onSurface,
                            size: 24,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addToCart() {
    final added = _cartService.addToCart(
      widget.organizationId,
      widget.organizationName,
      widget.product,
      categoryName: widget.categoryName,
      categoryColor: widget.accentColor,
    );

    if (added) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 12),
              Expanded(child: Text('${widget.product.name} added to cart')),
            ],
          ),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: theme.colorScheme.onSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text('Cannot add more than available stock')),
            ],
          ),
          backgroundColor: theme.colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeFromCart() {
    _cartService.removeFromCart(widget.organizationId, widget.product);

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.remove_circle, color: theme.colorScheme.onSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text('${widget.product.name} removed from cart')),
          ],
        ),
        backgroundColor: theme.colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListenableBuilder(
        listenable: _cartService,
        builder: (context, _) {
          final isInCart = _cartService.isInCart(
            widget.organizationId,
            widget.product.id,
          );
          final quantity = _cartService.getProductQuantity(
            widget.organizationId,
            widget.product.id,
          );

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // App Bar with back button
                  SliverAppBar(
                    expandedHeight: 400,
                    pinned: true,
                    backgroundColor: widget.accentColor,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: GestureDetector(
                        onTap: _openImageDialog,
                        child: widget.product.imageUrl != null
                            ? Image.network(
                                widget.product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: widget.accentColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 100,
                                        color: widget.accentColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                              )
                            : Container(
                                color: widget.accentColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Icon(
                                  Icons.restaurant,
                                  size: 120,
                                  color: widget.accentColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Product Details
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name and Stock Badge Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.product.name,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Stock Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.product.isAvailable
                                        ? Colors.green.shade600.withOpacity(
                                            0.15,
                                          )
                                        : Colors.red.shade600.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.product.isAvailable
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        size: 16,
                                        color: widget.product.isAvailable
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.product.stockStatus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: widget.product.isAvailable
                                              ? Colors.green.shade600
                                              : Colors.red.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Price
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.product.formattedPrice,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: widget.accentColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),

                            // Description
                            if (widget.product.description != null) ...[
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.product.description!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.textTheme.bodyMedium?.color,
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Quantity info if available
                            if (widget.product.quantity > 0) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.accentColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      color: widget.accentColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Available Stock: ${widget.product.quantity}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: widget.accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Extra spacing for button
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Action Buttons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
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
                  child: SafeArea(
                    child: !widget.product.isAvailable
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Out of Stock',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : isInCart
                        ? Row(
                            children: [
                              // Quantity controls
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: widget.accentColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            _cartService.decrementQuantity(
                                              widget.organizationId,
                                              widget.product.id,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(
                                              quantity > 1
                                                  ? Icons.remove_rounded
                                                  : Icons
                                                        .delete_outline_rounded,
                                              color: widget.accentColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        quantity.toString(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: widget.accentColor,
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            // Check if available stock allows increment
                                            if (widget.product.quantity > 0 &&
                                                quantity >=
                                                    widget.product.quantity) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.warning,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          'You cannot add more items. Only ${widget.product.quantity} ${widget.product.quantity == 1 ? "unit is" : "units are"} available in stock.',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            _cartService.incrementQuantity(
                                              widget.organizationId,
                                              widget.product.id,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: widget.accentColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Remove button
                              Material(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: _removeFromCart,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _addToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.accentColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Add here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
