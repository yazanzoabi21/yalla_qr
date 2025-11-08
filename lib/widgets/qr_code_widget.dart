import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/index.dart';
import '../services/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget to display QR code information and statistics
class QRCodeCard extends StatelessWidget {
  final QRCodeModel qrCode;
  final VoidCallback? onRefresh;
  final VoidCallback? onViewDetails;

  const QRCodeCard({
    super.key,
    required this.qrCode,
    this.onRefresh,
    this.onViewDetails,
  });

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your QR Code',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // QR Code placeholder (will show actual QR with qr_flutter package)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 120,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'QR Code Preview',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // QR Code details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Code',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              qrCode.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () => _copyToClipboard(context, qrCode.code),
                        tooltip: 'Copy code',
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat('Total Scans', qrCode.scanCount.toString()),
                      _buildStat(
                        'Created',
                        _formatDate(qrCode.createdAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (onViewDetails != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Statistics'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }
}

/// Widget to generate QR code for an account
class QRCodeGenerator extends StatefulWidget {
  final String accountId;
  final Function(QRCodeModel)? onGenerated;

  const QRCodeGenerator({
    super.key,
    required this.accountId,
    this.onGenerated,
  });

  @override
  State<QRCodeGenerator> createState() => _QRCodeGeneratorState();
}

class _QRCodeGeneratorState extends State<QRCodeGenerator> {
  final _qrCodeService = QRCodeService(Supabase.instance.client);
  bool _isLoading = false;
  QRCodeModel? _qrCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQRCode();
  }

  Future<void> _loadQRCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final qrCode = await _qrCodeService.getQRCodeByAccountId(widget.accountId);
      
      if (qrCode == null) {
        // Generate new QR code
        final newQRCode = await _qrCodeService.createQRCodeForAccount(widget.accountId);
        setState(() {
          _qrCode = newQRCode;
          _isLoading = false;
        });
        
        widget.onGenerated?.call(newQRCode);
      } else {
        setState(() {
          _qrCode = qrCode;
          _isLoading = false;
        });
        
        widget.onGenerated?.call(qrCode);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load QR code',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadQRCode,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_qrCode == null) {
      return const SizedBox.shrink();
    }

    return QRCodeCard(
      qrCode: _qrCode!,
      onRefresh: _loadQRCode,
      onViewDetails: () {
        // Navigate to QR code statistics page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodeStatisticsScreen(accountId: widget.accountId),
          ),
        );
      },
    );
  }
}

/// Screen to display QR code statistics
class QRCodeStatisticsScreen extends StatefulWidget {
  final String accountId;

  const QRCodeStatisticsScreen({
    super.key,
    required this.accountId,
  });

  @override
  State<QRCodeStatisticsScreen> createState() => _QRCodeStatisticsScreenState();
}

class _QRCodeStatisticsScreenState extends State<QRCodeStatisticsScreen> {
  final _qrCodeService = QRCodeService(Supabase.instance.client);
  bool _isLoading = true;
  Map<String, dynamic>? _statistics;
  List<ScanLog>? _recentScans;
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
      final stats = await _qrCodeService.getScanStatistics(widget.accountId);
      final scans = await _qrCodeService.getScanLogsByAccountId(widget.accountId, limit: 20);
      
      setState(() {
        _statistics = stats;
        _recentScans = scans;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadStatistics,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Statistics cards
                      _buildStatisticsGrid(),
                      const SizedBox(height: 24),
                      
                      // Recent scans
                      Text(
                        'Recent Scans',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_recentScans == null || _recentScans!.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No scans yet',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Share your QR code to get started',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ..._recentScans!.map((scan) => _buildScanLogCard(scan)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Scans',
          _statistics?['total_scans']?.toString() ?? '0',
          Icons.qr_code_scanner,
          Colors.blue,
        ),
        _buildStatCard(
          'Today',
          _statistics?['today_scans']?.toString() ?? '0',
          Icons.today,
          Colors.green,
        ),
        _buildStatCard(
          'This Week',
          _statistics?['week_scans']?.toString() ?? '0',
          Icons.calendar_today,
          Colors.orange,
        ),
        _buildStatCard(
          'This Month',
          _statistics?['month_scans']?.toString() ?? '0',
          Icons.calendar_month,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanLogCard(ScanLog scan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            Icons.qr_code_scanner,
            color: Colors.blue.shade700,
          ),
        ),
        title: Text(
          _formatDateTime(scan.scannedAt),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: scan.locationLat != null && scan.locationLng != null
            ? Text('Location: ${scan.locationLat!.toStringAsFixed(4)}, ${scan.locationLng!.toStringAsFixed(4)}')
            : const Text('No location data'),
        trailing: scan.deviceInfo != null
            ? Icon(Icons.phone_android, color: Colors.grey.shade600)
            : null,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
