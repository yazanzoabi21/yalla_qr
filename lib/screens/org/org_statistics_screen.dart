import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/org_statistics.dart';
import '../../services/org_statistics_service.dart';

class OrgStatisticsScreen extends StatefulWidget {
  final Account account;

  const OrgStatisticsScreen({
    super.key,
    required this.account,
  });

  @override
  State<OrgStatisticsScreen> createState() => _OrgStatisticsScreenState();
}

class _OrgStatisticsScreenState extends State<OrgStatisticsScreen> {
  final OrgStatisticsService _statisticsService = OrgStatisticsService();
  OrgStatistics? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _statisticsService.getRefreshedStatistics(widget.account.id);
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('Error loading statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading statistics...',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStatistics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_statistics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No statistics available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Statistics will appear here once data is available',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 40, bottom: 100, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(theme),
          const SizedBox(height: 24),

          // Overview Cards
          _buildSectionTitle('Overview', theme),
          const SizedBox(height: 12),
          _buildOverviewCards(theme),
          const SizedBox(height: 24),

          // Products Section
          _buildSectionTitle('Products', theme),
          const SizedBox(height: 12),
          _buildProductsCards(theme),
          const SizedBox(height: 24),

          // Orders Section
          _buildSectionTitle('Orders', theme),
          const SizedBox(height: 12),
          _buildOrdersCards(theme),
          const SizedBox(height: 24),

          // Revenue Section
          _buildSectionTitle('Revenue', theme),
          const SizedBox(height: 12),
          _buildRevenueCards(theme),
          const SizedBox(height: 24),

          // Deliveries Section
          _buildSectionTitle('Deliveries', theme),
          const SizedBox(height: 12),
          _buildDeliveriesCards(theme),
          const SizedBox(height: 24),

          // Time-based Stats
          _buildSectionTitle('Activity Timeline', theme),
          const SizedBox(height: 12),
          _buildTimelineCards(theme),
          const SizedBox(height: 16),

          // Last updated
          _buildLastUpdated(theme),
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
            color: (isDark
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.primary)
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: headerTextColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Statistics',
                  style: TextStyle(
                    color: headerTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.account.name ?? 'Organization',
            style: TextStyle(
              color: headerTextColor.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOverviewCards(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'QR Codes',
                _statistics!.totalQrCodes.toString(),
                Icons.qr_code_2,
                Colors.blue,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Scans',
                _statistics!.totalScans.toString(),
                Icons.visibility,
                Colors.purple,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Unique Visitors',
          _statistics!.uniqueVisitors.toString(),
          Icons.people,
          Colors.orange,
          theme,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildProductsCards(ThemeData theme) {
    return Column(
      children: [
        _buildStatCard(
          'Total Products',
          _statistics!.totalProducts.toString(),
          Icons.inventory_2,
          Colors.teal,
          theme,
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'In Stock',
                _statistics!.productsInStock.toString(),
                Icons.check_circle,
                Colors.green,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Out of Stock',
                _statistics!.productsOutOfStock.toString(),
                Icons.cancel,
                Colors.red,
                theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersCards(ThemeData theme) {
    return Column(
      children: [
        _buildStatCard(
          'Total Orders',
          _statistics!.totalOrders.toString(),
          Icons.shopping_cart,
          Colors.indigo,
          theme,
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pending',
                _statistics!.pendingOrders.toString(),
                Icons.hourglass_empty,
                Colors.amber,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completed',
                _statistics!.completedOrders.toString(),
                Icons.done_all,
                Colors.green,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Cancelled',
          _statistics!.cancelledOrders.toString(),
          Icons.close,
          Colors.red,
          theme,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildRevenueCards(ThemeData theme) {
    final currencyFormat = NumberFormat('#,##0.00');
    
    return Column(
      children: [
        _buildStatCard(
          'Revenue (LBP)',
          'L.L ${currencyFormat.format(_statistics!.totalRevenueLbp)}',
          Icons.attach_money,
          Colors.green,
          theme,
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Revenue (USD)',
          '\$${currencyFormat.format(_statistics!.totalRevenueUsd)}',
          Icons.monetization_on,
          Colors.greenAccent.shade700,
          theme,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildDeliveriesCards(ThemeData theme) {
    return Column(
      children: [
        _buildStatCard(
          'Total Deliveries',
          _statistics!.totalDeliveries.toString(),
          Icons.local_shipping,
          Colors.brown,
          theme,
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active',
                _statistics!.activeDeliveries.toString(),
                Icons.delivery_dining,
                Colors.orange,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completed',
                _statistics!.completedDeliveries.toString(),
                Icons.done,
                Colors.green,
                theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineCards(ThemeData theme) {
    return Column(
      children: [
        // Orders timeline
        _buildSectionTitle('Orders', theme),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today',
                _statistics!.ordersToday.toString(),
                Icons.today,
                Colors.cyan,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                _statistics!.ordersThisWeek.toString(),
                Icons.view_week,
                Colors.lightBlue,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'This Month',
          _statistics!.ordersThisMonth.toString(),
          Icons.calendar_month,
          Colors.blue,
          theme,
          fullWidth: true,
        ),
        const SizedBox(height: 24),
        
        // Scans timeline
        _buildSectionTitle('Scans', theme),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today',
                _statistics!.scansToday.toString(),
                Icons.today,
                Colors.purple,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                _statistics!.scansThisWeek.toString(),
                Icons.view_week,
                Colors.deepPurple,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'This Month',
          _statistics!.scansThisMonth.toString(),
          Icons.calendar_month,
          Colors.indigo,
          theme,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              if (fullWidth) const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(ThemeData theme) {
    if (_statistics?.lastUpdatedAt == null) return const SizedBox.shrink();

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final lastUpdated = dateFormat.format(_statistics!.lastUpdatedAt!.toLocal());

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.dividerColor,
            width: 1,
          ),
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
              'Last updated: $lastUpdated',
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
}
