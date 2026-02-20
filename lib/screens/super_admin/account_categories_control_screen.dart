import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountCategoriesControlScreen extends StatefulWidget {
  const AccountCategoriesControlScreen({super.key});

  @override
  State<AccountCategoriesControlScreen> createState() =>
      _AccountCategoriesControlScreenState();
}

class _AccountCategoriesControlScreenState
    extends State<AccountCategoriesControlScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, bool> _hiddenByCategoryId = {};
  String? _selectedAccountId;
  bool _loadingAccounts = true;
  bool _loadingCategories = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
      _error = null;
    });

    try {
      final accounts = await _supabase
          .from('accounts')
          .select('id, name, role')
          .order('created_at', ascending: false);

      // Keep only ORG accounts in the selection
      final all = List<Map<String, dynamic>>.from(accounts as List);
      final orgs = all.where((a) {
        final role = (a['role'] as String?)?.toUpperCase() ?? '';
        return role == 'ORG';
      }).toList();

      setState(() {
        _accounts = orgs;
        if (_selectedAccountId == null && _accounts.isNotEmpty) {
          _selectedAccountId = _accounts.first['id'] as String;
        }
        _loadingAccounts = false;
      });

      if (_selectedAccountId != null) {
        await _loadCategoriesForAccount(_selectedAccountId!);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingAccounts = false;
      });
    }
  }

  Future<void> _loadCategoriesForAccount(String accountId) async {
    setState(() {
      _loadingCategories = true;
      _error = null;
    });

    try {
      final categories = await _supabase
          .from('categories')
          .select('id, name, description, parent_id')
          .is_('parent_id', null)
          .order('name');

      final mappings = await _supabase
          .from('account_categories')
          .select('category_id, is_hidden')
          .eq('account_id', accountId);

      final hiddenMap = <String, bool>{};
      for (final m in (mappings as List)) {
        hiddenMap[m['category_id'] as String] =
            (m['is_hidden'] as bool?) ?? false;
      }

      setState(() {
        _categories = List<Map<String, dynamic>>.from(categories as List);
        _hiddenByCategoryId = hiddenMap;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingCategories = false;
      });
    }
  }

  Future<void> _toggleCategoryHidden(String categoryId, bool hidden) async {
    if (_selectedAccountId == null) return;

    setState(() {
      _hiddenByCategoryId[categoryId] = hidden;
    });

    try {
      await _supabase.from('account_categories').upsert({
        'account_id': _selectedAccountId,
        'category_id': categoryId,
        'is_hidden': hidden,
      }, onConflict: 'account_id,category_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hidden
                  ? 'Category hidden for account'
                  : 'Category visible for account',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   title: const Text('Account Categories Control'),
      //   backgroundColor: theme.scaffoldBackgroundColor,
      //   foregroundColor: theme.colorScheme.onSurface,
      //   iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      //   titleTextStyle: theme.textTheme.titleLarge?.copyWith(
      //     color: theme.colorScheme.onSurface,
      //     fontWeight: FontWeight.w600,
      //   ),
      //   elevation: 0,
      // ),
      body: _loadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState(theme)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: _buildHeader(theme),
                ),
                _buildAccountPicker(theme),
                const Divider(height: 1),
                Expanded(
                  child: _loadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : _buildCategoryList(theme),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final headerTextColor = isDark ? theme.colorScheme.onSurface : Colors.white;
    final gradientColors = isDark
        ? <Color>[
            theme.colorScheme.surfaceVariant,
            theme.colorScheme.primaryContainer,
          ]
        : <Color>[
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                (isDark
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.primary)
                    .withOpacity(0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, color: headerTextColor, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Account Categories Control',
              style: TextStyle(
                color: headerTextColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountPicker(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedAccountId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Select Account',
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: _accounts.map((account) {
          final name = account['name'] as String? ?? 'Unnamed';
          final role = account['role'] as String? ?? 'USER';
          return DropdownMenuItem<String>(
            value: account['id'] as String,
            child: Text('$name • $role'),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedAccountId = value;
          });
          _loadCategoriesForAccount(value);
        },
      ),
    );
  }

  Widget _buildCategoryList(ThemeData theme) {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No parent categories found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = _categories[index];
        final categoryId = category['id'] as String;
        final hidden = _hiddenByCategoryId[categoryId] ?? false;
        final categoryName = category['name'] as String? ?? 'Category';
        final description = category['description'] as String?;

        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(16),
          color: hidden
              ? theme.colorScheme.errorContainer.withOpacity(0.3)
              : theme.cardColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggleCategoryHidden(categoryId, !hidden),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: hidden
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: hidden
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (description != null && description.isNotEmpty)
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hidden
                                ? theme.colorScheme.error.withOpacity(0.1)
                                : theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hidden ? 'HIDDEN' : 'VISIBLE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: hidden
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Switch
                  Switch(
                    value: hidden,
                    onChanged: (value) =>
                        _toggleCategoryHidden(categoryId, value),
                    activeColor: theme.colorScheme.error,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Failed to load data', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
