import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/login_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/search/search_results_screen.dart';
import '../screens/client/product_detail_screen.dart';
import '../screens/org/org_orders_screen.dart';
import '../services/auth_service.dart';
import '../models/product.dart';
import 'dart:async';
import '../utils/navigation_helper.dart';
import '../services/secure_storage_service.dart';
import '../services/order_service.dart';
import '../utils/event_bus.dart';

class Navbar extends StatefulWidget implements PreferredSizeWidget {
  final bool showLoginButton;
  final VoidCallback? onSearchReturn;
  final String? categoryId; // The actual category UUID
  final bool showScanButton;
  final VoidCallback? onScanPressed;
  final bool showBackButton;
  final bool showMenuButton; // New parameter to control menu visibility
  final String? organizationAccountId; // For client search mode
  final String? organizationName; // For client product detail
  final Color? accentColor; // For client product detail
  final bool isClientHomePage; // For client home page search mode
  final Function(String)? onSearchChanged; // Callback for search text changes
  final String? searchHint; // Custom search hint text

  const Navbar({
    super.key,
    this.showLoginButton = false,
    this.onSearchReturn,
    this.categoryId,
    this.showScanButton = false,
    this.onScanPressed,
    this.showBackButton = false,
    this.showMenuButton = true, // Default to true (show menu)
    this.organizationAccountId,
    this.organizationName,
    this.accentColor,
    this.isClientHomePage = false,
    this.onSearchChanged,
    this.searchHint,
  });

  @override
  State<Navbar> createState() => _NavbarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}

class _NavbarState extends State<Navbar> {
  bool _isAuthenticated = false;
  bool _isOrgUser = false;
  late final AuthService _authService;
  late final StreamSubscription<AuthState> _authSubscription;
  final TextEditingController _searchController = TextEditingController();

  // Orders count + notes count for ORG accounts
  final OrderService _orderService = OrderService();
  String? _orgAccountId;
  int _orgOrdersCount = 0;
  int _orgNotesCount = 0;

  // Track assignment ids we've already counted locally (used when DB lacks unread column)
  final Set<String> _noteAssignmentIdsCounted = {};

  /// Load ORG account ID and orders count
  Future<void> _loadOrgAccountAndOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || !_isOrgUser || !_isAuthenticated) return;

      final orgAccount = await Supabase.instance.client
          .from('accounts')
          .select('id')
          .eq('owner_id', user.id)
          .eq('role', 'ORG')
          .maybeSingle();

      if (orgAccount == null) {
        if (mounted) {
          setState(() {
            _orgAccountId = null;
            _orgOrdersCount = 0;
          });
        }
        return;
      }

      final accountId = orgAccount['id'] as String;
      final orders = await _orderService.getOrganizationOrders(accountId);

      // Count PENDING orders (new orders displayed as "Preparing" that haven't been assigned to delivery yet)
      final pendingCount = orders.where((o) => o.status == 'PENDING').length;

      // Count unread delivery notes for this organization
      int notesCount = 0;
      try {
        final notesResp = await Supabase.instance.client
            .from('order_delivery_assignments')
            .select('id, order:orders!fk_order_delivery_order(account_id), delivery_notes_unread')
            .eq('delivery_notes_unread', true);

        final Set<String> idsForThisOrg = {};
        if (notesResp != null) {
          for (var n in (notesResp as List)) {
            final order = n['order'] as Map<String, dynamic>?;
            if (order != null && order['account_id'] == accountId) {
              final id = n['id'] as String?;
              if (id != null) idsForThisOrg.add(id);
            }
          }
        }

        // Use DB truth and sync our local counted ids
        notesCount = idsForThisOrg.length;
        _noteAssignmentIdsCounted
          ..clear()
          ..addAll(idsForThisOrg);
      } on PostgrestException catch (e) {
        // Column doesn't exist yet — don't crash; rely on local note tracking and log a hint
        debugPrint('Error fetching unread note count (schema missing column): $e');
        debugPrint('Hint: run SQL migration to add delivery_notes_unread column.');
        notesCount = _noteAssignmentIdsCounted.length;
      } catch (e) {
        debugPrint('Error fetching unread note count: $e');
      }

      if (mounted) {
        setState(() {
          _orgAccountId = accountId;
          _orgOrdersCount = pendingCount;
          _orgNotesCount = notesCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading ORG orders: $e');
    }
  }

  // Client search state
  List<Product> _productHints = [];
  bool _showHints = false;
  bool _isLoadingHints = false;
  Timer? _hintDebounceTimer;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(Supabase.instance.client);
    _checkAuthenticationStatus();

    // Listen to auth state changes with proper subscription management
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _isAuthenticated = data.session != null;
        });
        _checkOrgStatus();
        // Refresh org orders after auth changes
        _loadOrgAccountAndOrders();
      }
    });
  
    // Initial load in case user is already logged in
    _loadOrgAccountAndOrders();

    // Periodically refresh orders count (keeps badge up-to-date)
    _ordersRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _isOrgUser && _isAuthenticated) {
        _loadOrgAccountAndOrders();
      }
    });

    // Listen to global events (e.g., order assignment/status changes or note events)
    EventBus.stream.listen((event) {
      if (!mounted) return;

      if (event == 'orders:updated' && _isOrgUser && _isAuthenticated) {
        _loadOrgAccountAndOrders();
        return;
      }

      // note events format: note:updated:<assignmentId>:<orderId> or note:deleted:<assignmentId>:<orderId>
      if (event.startsWith('note:updated:') && _isOrgUser && _isAuthenticated) {
        final parts = event.split(':');
        if (parts.length >= 4) {
          final assignmentId = parts[2];
          // final orderId = parts[3];
          if (!_noteAssignmentIdsCounted.contains(assignmentId)) {
            _noteAssignmentIdsCounted.add(assignmentId);
            setState(() {
              _orgNotesCount = _orgNotesCount + 1;
            });
          }
        }
        return;
      }

      if (event.startsWith('note:deleted:') && _isOrgUser && _isAuthenticated) {
        final parts = event.split(':');
        if (parts.length >= 4) {
          final assignmentId = parts[2];
          if (_noteAssignmentIdsCounted.remove(assignmentId)) {
            setState(() {
              _orgNotesCount = _orgNotesCount > 0 ? _orgNotesCount - 1 : 0;
            });
          }
        }
        return;
      }
    });
  }

  Future<void> _checkOrgStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final loginContext = prefs.getString('login_context');
    if (mounted) {
      setState(() {
        _isOrgUser = loginContext == 'ORG';
      });
    }

    // After we know org status, attempt to load account and orders
    _loadOrgAccountAndOrders();
  }

  Timer? _ordersRefreshTimer;

  @override
  void dispose() {
    _authSubscription.cancel();
    _searchController.dispose();
    _hintDebounceTimer?.cancel();
    _ordersRefreshTimer?.cancel();
    super.dispose();
  }

  void _checkAuthenticationStatus() {
    setState(() {
      _isAuthenticated = _authService.isAuthenticated();
    });
    _checkOrgStatus();
  }

  /// Load product hints for client search
  Future<void> _loadProductHints(String query) async {
    if (query.isEmpty || widget.organizationAccountId == null) {
      setState(() {
        _productHints = [];
        _showHints = false;
      });
      return;
    }

    setState(() => _isLoadingHints = true);

    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('account_id', widget.organizationAccountId!)
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(5);

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _productHints = products;
          _showHints = products.isNotEmpty;
          _isLoadingHints = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading product hints: $e');
      if (mounted) {
        setState(() {
          _isLoadingHints = false;
          _showHints = false;
        });
      }
    }
  }

  /// Handle search text changes with debounce
  void _onSearchTextChanged(String text) {
    _hintDebounceTimer?.cancel();

    if (text.isEmpty) {
      setState(() {
        _showHints = false;
        _productHints = [];
      });
      return;
    }

    _hintDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadProductHints(text.trim());
    });
  }

  /// Handle client home page search (organizations)
  void _onClientHomeSearchChanged(String text) {
    if (widget.onSearchChanged != null) {
      widget.onSearchChanged!(text);
    }
  }

  /// Clear the search field
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showHints = false;
      _productHints = [];
    });
    if (widget.onSearchChanged != null) {
      widget.onSearchChanged!('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isClientMode = widget.organizationAccountId != null;
    final bool isClientHomePage = widget.isClientHomePage;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight + 10,
      title: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (widget.showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.grey),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    readOnly: !isClientMode && !isClientHomePage,
                    onChanged: isClientMode
                        ? _onSearchTextChanged
                        : (isClientHomePage
                              ? _onClientHomeSearchChanged
                              : null),
                    decoration: InputDecoration(
                      hintText:
                          widget.searchHint ??
                          (isClientHomePage
                              ? 'Search organizations...'
                              : (isClientMode
                                    ? 'Search products...'
                                    : 'Search')),
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: _buildSearchSuffixIcon(
                        isClientMode || isClientHomePage,
                      ),
                    ),
                    onTap: !isClientMode && !isClientHomePage
                        ? () async {
                            final isHomeScreen = widget.categoryId == null;
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchResultsScreen(
                                  initialQuery: _searchController.text,
                                  categoryId: widget.categoryId,
                                  categoriesOnly: isHomeScreen,
                                ),
                              ),
                            );
                            if (result == true &&
                                widget.onSearchReturn != null) {
                              widget.onSearchReturn!();
                            }
                          }
                        : null,
                    onSubmitted: isClientMode
                        ? (value) {
                            if (value.trim().isNotEmpty) {
                              setState(() => _showHints = false);
                              _navigateToClientSearch(value.trim());
                            }
                          }
                        : null,
                  ),
                ),
                if (widget.showScanButton && widget.onScanPressed != null)
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.grey),
                    onPressed: widget.onScanPressed,
                    tooltip: 'Scan QR Code',
                  ),
                if (widget.showMenuButton)
                  PopupMenuButton<String>(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.menu, color: Colors.grey),
                        if (_orgOrdersCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),                        // Show red dot if there are unread delivery notes
                        if (_orgNotesCount > 0)
                          Positioned(
                            right: 8,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),                      ],
                    ),
                    onSelected: (String value) {
                      _handleMenuSelection(context, value);
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'contact',
                            child: ListTile(
                              leading: Icon(Icons.contact_support),
                              title: Text('Contact'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'feedback',
                            child: ListTile(
                              leading: Icon(Icons.feedback),
                              title: Text('Feedback'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'about',
                            child: ListTile(
                              leading: Icon(Icons.info),
                              title: Text('About'),
                            ),
                          ),
                          if (_isAuthenticated) ...[
                            const PopupMenuItem<String>(
                              value: 'settings',
                              child: ListTile(
                                leading: Icon(Icons.settings),
                                title: Text('Settings'),
                              ),
                            ),
                          ],
                          if (_isOrgUser && _isAuthenticated) ...[
                            PopupMenuItem<String>(
                              value: 'orders',
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long),
                                title: const Text('Orders'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_orgOrdersCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$_orgOrdersCount',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    if (_orgNotesCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_isAuthenticated) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'logout',
                              child: ListTile(
                                leading: Icon(Icons.logout, color: Colors.red),
                                title: Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ] else if (widget.showLoginButton) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'login',
                              child: ListTile(
                                leading: Icon(Icons.login),
                                title: Text('Login'),
                              ),
                            ),
                          ],
                        ],
                  ),
              ],
            ),
          ),
          // Product hints dropdown for client mode
          if (_showHints && _productHints.isNotEmpty)
            Positioned(
              top: 52,
              left: 0,
              right: 0,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                shadowColor: Colors.black26,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: _productHints.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 60,
                      ),
                      itemBuilder: (context, index) {
                        return _buildProductHintTile(_productHints[index]);
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildSearchSuffixIcon(bool isClientMode) {
    if (_isLoadingHints && _searchController.text.isNotEmpty && isClientMode) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_searchController.text.isNotEmpty && isClientMode) {
      return IconButton(
        icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
        onPressed: _clearSearch,
      );
    }
    return null;
  }

  Widget _buildProductHintTile(Product product) {
    final isInStock = product.isAvailable;

    return InkWell(
      onTap: () {
        setState(() => _showHints = false);
        _navigateToProductDetail(product);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.grey[400],
                              size: 22,
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (product.priceLbp != null || product.priceUsd != null)
                    Text(
                      product.formattedPrice,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isInStock
                    ? const Color(0xFF00B86F).withOpacity(0.12)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isInStock ? Icons.check_circle : Icons.cancel,
                    size: 12,
                    color: isInStock ? const Color(0xFF00B86F) : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isInStock ? 'In Stock' : 'Out',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isInStock ? const Color(0xFF00B86F) : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToClientSearch(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          initialQuery: query,
          organizationAccountId: widget.organizationAccountId,
          organizationName: widget.organizationName,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }

  void _navigateToProductDetail(Product product) {
    if (widget.organizationAccountId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          organizationId: widget.organizationAccountId!,
          organizationName: widget.organizationName ?? 'Organization',
          accentColor: widget.accentColor ?? Colors.blue,
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) async {
    switch (value) {
      case 'contact':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact selected')));
        break;
      case 'feedback':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Feedback selected')));
        break;
      case 'settings':
        if (_isAuthenticated) {
          String? currentCategory = _getCurrentCategory(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SettingsScreen(categoryName: currentCategory),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to access settings')),
          );
        }
        break;
      case 'orders':
        if (_isOrgUser && _isAuthenticated) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OrgOrdersScreen()),
          );
        }
        break;
      case 'about':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('About selected')));
        break;
      case 'login':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        break;
      case 'logout':
        // Show classic loading dialog
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (BuildContext context) {
              return WillPopScope(
                onWillPop: () async => false,
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    constraints: const BoxConstraints(maxWidth: 140),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Logging out...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
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

        try {
          debugPrint('🚪 Logging out user...');

          // Use the enhanced logout with complete session clearing
          await _authService.signOut();
          // Clear session flag from secure storage
          await SecureStorageService.clearSession();

          // Clear login context from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('login_context');
          await prefs.remove('last_scanned_qr');

          debugPrint('✅ Session cleared from storage');

          // Verify logout was successful
          final sessionAfterLogout = _authService.getCurrentSession();
          if (sessionAfterLogout != null) {
            debugPrint('⚠️ Session still exists, forcing auth reset');
            await _authService.forceAuthReset();
          }

          // Force update the authentication status
          setState(() {
            _isAuthenticated = false;
          });

          // Close loading dialog
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Successfully logged out'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Add a small delay to ensure logout is complete
            await Future.delayed(const Duration(milliseconds: 500));

            // Navigate to Welcome screen
            if (!mounted) return;
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            }
          }
        } catch (e) {
          // Close loading dialog
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          // Try force reset as a last resort
          try {
            await _authService.forceAuthReset();

            // Clear login context even in error case
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('login_context');
            await prefs.remove('last_scanned_qr');

            setState(() {
              _isAuthenticated = false;
            });

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Force logout successful'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );

              // Navigate to Welcome screen
              if (!mounted) return;
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            }
          } catch (forceError) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to logout: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        break;
    }
  }

  /// Determine the current category based on the current route
  String? _getCurrentCategory(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route?.settings.name != null) {
      final routeName = route!.settings.name!;

      // Extract category from route name
      switch (routeName) {
        case '/meals':
          return 'meals';
        case '/gym':
          return 'gym';
        case '/home':
        case '/login':
          return null; // These are not category-specific
        default:
          // Fallback for route names that contain category info
          if (routeName.contains('meals') || routeName.contains('Meals')) {
            return 'meals';
          } else if (routeName.contains('gym') || routeName.contains('Gym')) {
            return 'gym';
          }
          break;
      }
    }

    return null; // Unknown category, will go to home
  }
}
