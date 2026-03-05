import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../services/cart_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/visitor_tracking_service.dart';
import '../client/organization_categories_screen.dart';
import '../../models/product.dart';
import '../../widgets/account_product_list.dart';

class ExploreSearchScreen extends StatefulWidget {
  const ExploreSearchScreen({super.key});

  @override
  State<ExploreSearchScreen> createState() => _ExploreSearchScreenState();
}

class _AccountWithCategories {
  final Account account;
  final List<Category> categories;
  _AccountWithCategories({required this.account, required this.categories});
}

class _ExploreSearchScreenState extends State<ExploreSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  final CartService _cartService = CartService();
  Map<String, Set<String>> _cartCategoriesByOrg = {};
  // Track user subscriptions locally (category ids)
  final Set<String> _subscribedCategoryIds = {};
  bool _categorySubscriptionsAvailable = true;
  final Map<String, bool> _subscribing = {};
  final Map<String, bool> _enrollingAccounts = {};
  final Set<String> _enrolledOrgIds = {};

  // Product search results grouped by account id
  Map<String, List<Product>> _productResultsByAccount = {};
  bool _isSearchingProducts = false;

  List<_AccountWithCategories> _allItems = [];
  List<_AccountWithCategories> _filteredItems = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _cartService.addListener(_updateCartFlags);
    _loadUserSubscriptions();
    _loadUserEnrollmentsFromVisitors();
    _loadAllCategories();
    _updateCartFlags();
    EnrollmentService.instance.addListener(_onEnrollmentChanged);
    EnrollmentService.instance.load();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _productResultsByAccount = {};
        _isSearchingProducts = false;
      });
      return;
    }

// No longer restrict search to enrolled organizations.  Show products
      // from all accounts so that un-enrolling doesn't clear search results.
      // (Enrollment still controls other parts of the app.)

    setState(() {
      _isSearchingProducts = true;
    });

    try {
      final pattern = '%${query.replaceAll('%', '')}%';
      final resp = await Supabase.instance.client
          .from('products')
          .select(
            'id, name, description, price_lbp, price_usd, image_url, in_stock, quantity, created_at, category_id, account_id',
          )
          .or('name.ilike.$pattern,description.ilike.$pattern')
          .order('name', ascending: true);

      final products = (resp as List)
          .map((j) => Product.fromJson(j as Map<String, dynamic>))
          .toList();

      final Map<String, List<Product>> grouped = {};
      for (var p in products) {
        final aid = p.accountId ?? '';
        grouped.putIfAbsent(aid, () => []).add(p);
      }

      setState(() {
        _productResultsByAccount = grouped;
        _isSearchingProducts = false;
      });
    } catch (e) {
      debugPrint('Product search failed: $e');
      setState(() {
        _productResultsByAccount = {};
        _isSearchingProducts = false;
      });
    }
  }

  Future<void> _loadUserSubscriptions() async {
    if (!_categorySubscriptionsAvailable) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final resp = await Supabase.instance.client
          .from('user_category_subscriptions')
          .select('category_id')
          .eq('user_id', user.id)
          .eq('subscribed', true);
      final ids = (resp as List<dynamic>)
          .map((r) => r['category_id'] as String)
          .toList();
      setState(() {
        _subscribedCategoryIds.addAll(ids);
      });
      // account-level enrollments are loaded by EnrollmentService
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('does not exist') || msg.contains('42P01') || msg.contains('Not Found')) {
        // mark so we don't retry repeatedly and flood logs
        _categorySubscriptionsAvailable = false;
      }
      debugPrint('Failed to load user subscriptions: $e');
    }
  }

  Future<void> _loadUserEnrollmentsFromVisitors() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Resolve the user's account ID (accounts.owner_id -> auth user id)
      final acct = await Supabase.instance.client
          .from('accounts')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();
      if (acct == null) return;
      final accountId = acct['id'] as String;

      // Query organization_visitors for any records for this account
      final resp = await Supabase.instance.client
          .from('organization_visitors')
          .select('org_id')
          .eq('user_id', accountId);

      final ids = (resp as List<dynamic>)
          .map((r) => r['org_id'] as String)
          .toList();
      if (ids.isNotEmpty) {
        // keep local copy for backwards compatibility, but also merge into the
        // shared enrollment service so listeners anywhere in the app will fire.
        setState(() {
          _enrolledOrgIds.addAll(ids);
        });
        EnrollmentService.instance.mergeEnrollments(ids);
      }
    } catch (e) {
      debugPrint('Failed to load enrollments from visitors: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _cartService.removeListener(_updateCartFlags);
    EnrollmentService.instance.removeListener(_onEnrollmentChanged);
    super.dispose();
  }

  void _onEnrollmentChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilter();
      final q = _controller.text.trim();
      if (q.isNotEmpty) {
        _searchProducts(q);
      } else {
        setState(() {
          _productResultsByAccount = {};
        });
      }
    });
  }

  Future<void> _loadAllCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await Supabase.instance.client
          .from('accounts')
          .select('*')
          .eq('role', 'ORG');
      final accounts = (resp as List)
          .map((json) => Account.fromJson(json as Map<String, dynamic>))
          .toList();

      // Build per-account category lists (only top-level / parent categories)
      final List<_AccountWithCategories> items = [];
      for (var org in accounts) {
        try {
          final cats = await CategoryService.getCategoriesForSpecificAccount(
            org.id,
            parentOnly: true,
          );
          // Exclude categories marked hidden for this account
          final parentCats = cats
              .where((c) => c.parentId == null && c.isHidden == false)
              .toList();
          items.add(
            _AccountWithCategories(account: org, categories: parentCats),
          );
        } catch (e) {
          debugPrint('Failed to load categories for org ${org.id}: $e');
          items.add(_AccountWithCategories(account: org, categories: []));
        }
      }

      setState(() {
        _allItems = items;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      _filteredItems = _allItems.where((it) {
        final accountName = it.account.name.toLowerCase();
        final catNames = it.categories
            .map((c) => c.name.toLowerCase())
            .join(' ');
        return accountName.contains(query) || catNames.contains(query);
      }).toList();
    }
    setState(() {});
  }

  void _updateCartFlags() {
    final Map<String, Set<String>> flags = {};
    for (var cart in _cartService.getAllCartsWithItems()) {
      flags[cart.organizationId] = cart.items
          .map((i) => i.categoryName ?? '')
          .toSet();
    }
    setState(() {
      _cartCategoriesByOrg = flags;
    });
  }

  Future<void> _openOrg(Account org) async {
    List<Category> categories = [];
    try {
      categories = await CategoryService.getCategoriesForSpecificAccount(
        org.id,
        parentOnly: true,
      );
      // Make doubly sure only root categories are shown here
      categories = categories.where((c) => c.parentId == null).toList();
    } catch (e) {
      debugPrint('Error loading categories for ${org.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrganizationCategoriesScreen(account: org, categories: categories),
      ),
    );
  }

  Future<void> _toggleSubscription(Category category) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to subscribe to categories.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final cid = category.id;
    final currently = _subscribedCategoryIds.contains(cid);
    setState(() {
      _subscribing[cid] = true;
    });

    try {
      // Attempt to upsert a subscription record. Table may not exist; swallow errors.
      await Supabase.instance.client.from('user_category_subscriptions').upsert(
        {'user_id': user.id, 'category_id': cid, 'subscribed': !currently},
      );

      setState(() {
        if (currently) {
          _subscribedCategoryIds.remove(cid);
        } else {
          _subscribedCategoryIds.add(cid);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currently
                  ? 'Unenrolled from ${category.name}'
                  : 'Enrolled in ${category.name}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to toggle subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update subscription'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _subscribing.remove(cid);
      });
    }
  }

  void _showAccountCategories(_AccountWithCategories item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final cats = item.categories;
        final bool isEnrolled =
            EnrollmentService.instance.isEnrolled(item.account.id) ||
            _enrolledOrgIds.contains(item.account.id) ||
            (cats.isNotEmpty &&
                cats.every((c) => _subscribedCategoryIds.contains(c.id)));

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  item.account.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: cats.isEmpty
                      ? Center(
                          child: Text(
                            'No categories available',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (c, i) {
                            final cat = cats[i];
                            final enrolledViaAccount =
                                EnrollmentService.instance.isEnrolled(
                                  item.account.id,
                                ) ||
                                _subscribedCategoryIds.contains(cat.id);
                            return ListTile(
                              leading: cat.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        cat.imagePath!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: cat.color.withOpacity(
                                        0.2,
                                      ),
                                      child: Icon(cat.icon, color: cat.color),
                                    ),
                              title: Text(
                                cat.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: cat.description != null
                                  ? Text(
                                      cat.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: enrolledViaAccount
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _enrollingAccounts[item.account.id] == true
                            ? const SizedBox(
                                height: 44,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : (isEnrolled
                                  ? Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: Colors.green.shade300,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check,
                                              color: Colors.green.shade800,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Enrolled',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade600,
                                            Colors.green.shade400,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                          ),
                                          minimumSize: const Size.fromHeight(
                                            56,
                                          ),
                                        ),
                                        onPressed: () {
                                          // optimistic update before closing the sheet so the
                                          // grid reflects the change immediately
                                          setState(() {
                                            _enrolledOrgIds.add(
                                              item.account.id,
                                            );
                                          });
                                          EnrollmentService.instance
                                              .enrollAccount(
                                                item.account.id,
                                                categoryIds: item.categories
                                                    .map((c) => c.id)
                                                    .toList(),
                                              );
                                          Navigator.pop(context);
                                          // continue the network flow without awaiting so we
                                          // don't delay the UI; errors are handled inside
                                          _toggleAccountEnrollment(
                                            item,
                                            enroll: true,
                                          );
                                        },
                                        child: const Text(
                                          'Enroll',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleAccountEnrollment(
    _AccountWithCategories item, {
    bool? enroll,
  }) async {
    final accId = item.account.id;
    final desired = enroll ?? !_enrolledOrgIds.contains(accId);

    // mark that we're working on this account and optimistically update
    setState(() {
      _enrollingAccounts[accId] = true;
      if (desired) {
        _enrolledOrgIds.add(accId);
      } else {
        _enrolledOrgIds.remove(accId);
      }
    });

    // make sure the shared service also reflects the optimistic state
    if (desired) {
      EnrollmentService.instance.enrollAccount(
        accId,
        categoryIds: item.categories.map((c) => c.id).toList(),
      );
    } else {
      EnrollmentService.instance.unenrollAccount(
        accId,
        categoryIds: item.categories.map((c) => c.id).toList(),
      );
    }

    try {
      if (desired) {
        // Try to find a QR code for this organization and use the visitor tracking flow
        try {
          final qr = await Supabase.instance.client
              .from('qr_codes')
              .select('id')
              .eq('account_id', accId)
              .maybeSingle();

          if (qr != null && qr['id'] != null) {
            final qrId = qr['id'] as String;
            await VisitorTrackingService.trackVisitor(
              qrCodeId: qrId,
              orgId: accId,
            );
          } else {
            // Fallback: creation already triggered above via enrollAccount, so nothing more to do
          }
        } catch (e) {
          debugPrint('Failed to enroll via visitor tracking, ignoring: $e');
        }
      } else {
        // Unenroll: remove organization_visitors record if exists, and keep service in sync
        try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final acct = await Supabase.instance.client
                .from('accounts')
                .select('id')
                .eq('owner_id', user.id)
                .maybeSingle();
            if (acct != null) {
              final accountId = acct['id'] as String;
              await Supabase.instance.client
                  .from('organization_visitors')
                  .delete()
                  .eq('user_id', accountId)
                  .eq('org_id', accId);
            }
          }
        } catch (e) {
          debugPrint('Failed to unenroll via visitors table: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              desired
                  ? 'Enrolled in ${item.account.name}'
                  : 'Unenrolled from ${item.account.name}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Enrollment action failed: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update enrollment'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      setState(() {
        _enrollingAccounts.remove(accId);
      });
    }
  }

  Widget _buildGrid() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final account = item.account;
        final cats = item.categories;
        final subtitle = cats.isEmpty
            ? 'No categories'
            : (cats.length == 1
                  ? cats.first.name
                  : '${cats.first.name} +${cats.length - 1} more');

        final bool isEnrolledMain =
            EnrollmentService.instance.isEnrolled(account.id) ||
            _enrolledOrgIds.contains(account.id) ||
            (cats.isNotEmpty &&
                cats.every((c) => _subscribedCategoryIds.contains(c.id)));

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: () => _showAccountCategories(item),
            leading: account.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      account.logoUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                : CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.12),
                    child: Text(
                      account.name.isNotEmpty ? account.name[0] : '?',
                    ),
                  ),
            title: Text(
              account.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEnrolledMain)
                  const Icon(Icons.check_circle, color: Colors.green),
                if (isEnrolledMain) const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search Stores or products...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : (_controller.text.trim().isNotEmpty
                ? (_isSearchingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : (_productResultsByAccount.isEmpty
                            ? const Center(child: Text('No products found'))
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: _productResultsByAccount.entries.map((
                                    entry,
                                  ) {
                                    // find account object for header
                                    final account = _allItems
                                        .map((e) => e.account)
                                        .firstWhere(
                                          (a) => a.id == entry.key,
                                          orElse: () => Account(
                                            id: entry.key,
                                            ownerId: null,
                                            name: entry.key,
                                            email: null,
                                            phone: null,
                                            description: null,
                                            locationAddress: null,
                                            locationLat: null,
                                            locationLng: null,
                                            logoUrl: null,
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                            role: 'ORG',
                                            zoneId: null,
                                            cityId: null,
                                          ),
                                        );

                                    return AccountProductList(
                                      account: account,
                                      products: entry.value,
                                    );
                                  }).toList(),
                                ),
                              )))
                : _filteredItems.isEmpty
                ? const Center(child: Text('No categories found'))
                : _buildGrid()),
    );
  }
}
