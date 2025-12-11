import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../screens/client/cart_screen.dart';
import '../screens/client/all_carts_screen.dart';

/// Floating cart icon that appears on all client screens
/// Shows item count badge and opens cart on tap
class FloatingCartIcon extends StatelessWidget {
  final String organizationId;
  final String organizationName;
  final bool showAllOrganizations; // If true, shows combined count and opens all carts screen

  const FloatingCartIcon({
    super.key,
    required this.organizationId,
    required this.organizationName,
    this.showAllOrganizations = false,
  });

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return ListenableBuilder(
      listenable: cartService,
      builder: (context, _) {
        final itemCount = showAllOrganizations 
            ? cartService.getTotalItemsAllOrganizations()
            : cartService.getTotalItems(organizationId);

        return Positioned(
          bottom: 80,
          right: 20,
          child: GestureDetector(
            onTap: () {
              if (showAllOrganizations) {
                // Show all carts screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllCartsScreen(),
                  ),
                );
              } else {
                // Show single organization cart
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CartScreen(
                      organizationId: organizationId,
                      organizationName: organizationName,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepOrange.shade400,
                    Colors.deepOrange.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (itemCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            itemCount > 99 ? '99+' : itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
