import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PlatformStatisticsScreen extends StatefulWidget {
  const PlatformStatisticsScreen({super.key});

  @override
  State<PlatformStatisticsScreen> createState() =>
      _PlatformStatisticsScreenState();
}

class _PlatformStatisticsScreenState extends State<PlatformStatisticsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('platform_statistics')
          .select('*')
          .order('stat_date', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        _stats = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   title: const Text('Platform Statistics'),
      //   backgroundColor: theme.scaffoldBackgroundColor,
      //   foregroundColor: theme.colorScheme.onSurface,
      //   iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      //   titleTextStyle: theme.textTheme.titleLarge?.copyWith(
      //     color: theme.colorScheme.onSurface,
      //     fontWeight: FontWeight.w600,
      //   ),
      //   elevation: 0,
      // ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: _isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [_buildErrorState(theme)],
              )
            : _stats == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [_buildEmptyState(theme)],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Accounts', theme),
                  const SizedBox(height: 8),
                  _buildStatGrid([
                    _stat(
                      'Total Accounts',
                      _int('total_accounts'),
                      Icons.business,
                      Colors.indigo,
                    ),
                    _stat(
                      'Total Users',
                      _int('total_users'),
                      Icons.people,
                      Colors.blue,
                    ),
                    _stat(
                      'Delivery Accounts',
                      _int('total_delivery_accounts'),
                      Icons.delivery_dining,
                      Colors.orange,
                    ),
                    _stat(
                      'New Today',
                      _int('new_accounts_today'),
                      Icons.today,
                      Colors.green,
                    ),
                    _stat(
                      'New This Week',
                      _int('new_accounts_this_week'),
                      Icons.view_week,
                      Colors.teal,
                    ),
                    _stat(
                      'New This Month',
                      _int('new_accounts_this_month'),
                      Icons.calendar_month,
                      Colors.purple,
                    ),
                  ], theme),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Platform Usage', theme),
                  const SizedBox(height: 8),
                  _buildStatGrid([
                    _stat(
                      'Total QR Codes',
                      _int('total_qr_codes'),
                      Icons.qr_code_2,
                      Colors.deepPurple,
                    ),
                    _stat(
                      'Total Scans',
                      _int('total_scans'),
                      Icons.visibility,
                      Colors.pink,
                    ),
                    _stat(
                      'Scans Today',
                      _int('scans_today'),
                      Icons.today,
                      Colors.cyan,
                    ),
                    _stat(
                      'Scans This Week',
                      _int('scans_this_week'),
                      Icons.view_week,
                      Colors.lightBlue,
                    ),
                    _stat(
                      'Scans This Month',
                      _int('scans_this_month'),
                      Icons.calendar_month,
                      Colors.blueGrey,
                    ),
                  ], theme),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Commerce', theme),
                  const SizedBox(height: 8),
                  _buildStatGrid([
                    _stat(
                      'Total Products',
                      _int('total_products'),
                      Icons.inventory_2,
                      Colors.teal,
                    ),
                    _stat(
                      'Total Orders',
                      _int('total_orders'),
                      Icons.shopping_cart,
                      Colors.indigo,
                    ),
                    _stat(
                      'Orders Today',
                      _int('orders_today'),
                      Icons.today,
                      Colors.orange,
                    ),
                    _stat(
                      'Orders This Week',
                      _int('orders_this_week'),
                      Icons.view_week,
                      Colors.deepPurple,
                    ),
                    _stat(
                      'Orders This Month',
                      _int('orders_this_month'),
                      Icons.calendar_month,
                      Colors.green,
                    ),
                  ], theme),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Revenue', theme),
                  const SizedBox(height: 8),
                  _buildStatGrid([
                    _stat(
                      'Total Revenue (LBP)',
                      _currency('total_revenue_lbp', 'LBP'),
                      Icons.attach_money,
                      Colors.green,
                    ),
                    _stat(
                      'Total Revenue (USD)',
                      _currency('total_revenue_usd', 'USD'),
                      Icons.monetization_on,
                      Colors.lightGreen,
                    ),
                    _stat(
                      'Revenue Today (LBP)',
                      _currency('revenue_today_lbp', 'LBP'),
                      Icons.trending_up,
                      Colors.teal,
                    ),
                    _stat(
                      'Revenue Today (USD)',
                      _currency('revenue_today_usd', 'USD'),
                      Icons.trending_up,
                      Colors.blue,
                    ),
                  ], theme),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Deliveries', theme),
                  const SizedBox(height: 8),
                  _buildStatGrid([
                    _stat(
                      'Total Deliveries',
                      _int('total_deliveries'),
                      Icons.local_shipping,
                      Colors.brown,
                    ),
                    _stat(
                      'Active Deliveries',
                      _int('active_deliveries'),
                      Icons.delivery_dining,
                      Colors.orange,
                    ),
                  ], theme),
                  const SizedBox(height: 16),
                  _buildLastUpdated(theme),
                ],
              ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (isDark
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.primary)
                    .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_rounded, color: headerTextColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Platform Overview',
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

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.textTheme.bodyMedium?.color,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatGrid(List<_StatItem> items, ThemeData theme) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _buildStatCard(items[index], theme),
    );
  }

  Widget _buildStatCard(_StatItem item, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const Spacer(),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(ThemeData theme) {
    final raw = _stats?['last_updated_at'] as String?;
    if (raw == null) return const SizedBox.shrink();

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.update,
              size: 16,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Last updated: ${dateFormat.format(parsed)}',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No statistics available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Failed to load statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  _StatItem _stat(String label, String value, IconData icon, Color color) {
    return _StatItem(label: label, value: value, icon: icon, color: color);
  }

  String _int(String key) {
    final value = _stats?[key];
    if (value == null) return '0';
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    return value.toString();
  }

  String _currency(String key, String currency) {
    final value = _stats?[key];
    final numVal = value is num ? value : double.tryParse('$value') ?? 0;
    final format = NumberFormat('#,##0.00');
    if (currency == 'LBP') return 'L.L ${format.format(numVal)}';
    return '\$${format.format(numVal)}';
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
