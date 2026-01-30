import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/index.dart';
import '../services/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:ui' as ui;

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

  Future<void> _printQr(BuildContext context) async {
    try {
      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Preparing QR code for printing...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          // Render QR to image bytes using QrPainter for high quality
          final painter = QrPainter(
            data: qrCode.code,
            version: QrVersions.auto,
            gapless: true,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          );
          final ByteData? pngBytes = await painter.toImageData(
            2048,
            format: ui.ImageByteFormat.png,
          );
          final bytes = pngBytes?.buffer.asUint8List() ?? Uint8List(0);

          doc.addPage(
            pw.Page(
              build: (pw.Context ctx) => pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'QR Code',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    if (bytes.isNotEmpty)
                      pw.Container(
                        width: 300,
                        height: 300,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 2),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Image(
                          pw.MemoryImage(bytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      qrCode.code,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Scan this QR code to access your information',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColor.fromInt(0xFF616161),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return doc.save();
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print QR: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _shareQr(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Preparing QR code...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Generate QR code with white background
      final painter = QrPainter(
        data: qrCode.code,
        version: QrVersions.auto,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final ByteData? rawPng = await painter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );

      if (rawPng != null) {
        // Add white background and padding
        final codec = await ui.instantiateImageCodec(
          rawPng.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        final ui.Image qrImage = frame.image;

        const int padding = 64; // quiet zone around QR
        final int finalSize = qrImage.width + padding * 2;

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // Fill white background
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, finalSize.toDouble(), finalSize.toDouble()),
          paint,
        );

        // Draw QR code centered with padding
        final srcRect = Rect.fromLTWH(
          0,
          0,
          qrImage.width.toDouble(),
          qrImage.height.toDouble(),
        );
        final dstRect = Rect.fromLTWH(
          padding.toDouble(),
          padding.toDouble(),
          qrImage.width.toDouble(),
          qrImage.height.toDouble(),
        );
        canvas.drawImageRect(qrImage, srcRect, dstRect, Paint());

        final picture = recorder.endRecording();
        final ui.Image finalImage = await picture.toImage(
          finalSize,
          finalSize,
        );
        final ByteData? finalBytes = await finalImage.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (finalBytes != null) {
          final bytes = finalBytes.buffer.asUint8List();
          // Share as PNG image
          await Printing.sharePdf(
            bytes: bytes,
            filename: 'qr_code_${qrCode.code}.png',
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('QR code ready to share'),
                  ],
                ),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to share: ${e.toString()}')),
            ],
          ),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hintColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurface.withOpacity(0.7);
    final surface = colorScheme.surface;

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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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

            // Actual QR Code with enhanced design
            Center(
                child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary.withOpacity(0.06), colorScheme.secondary.withOpacity(0.04)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // QR Code container with white background (keep fully white for scannability)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrCode.code,
                        version: QrVersions.auto,
                        size: 220,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                        backgroundColor: Colors.white,
                        embeddedImage: null,
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(40, 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _printQr(context),
                          icon: const Icon(Icons.print, size: 20),
                          label: const Text('Print QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _shareQr(context),
                          icon: const Icon(Icons.share, size: 20),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Scan instruction text
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scan to view details',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // QR Code details with enhanced design
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [surface, colorScheme.surfaceVariant.withOpacity(0.98)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.key,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QR Code',
                                style: TextStyle(
                                fontSize: 13,
                                color: hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              qrCode.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                        IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                        onPressed: () => _copyToClipboard(context, qrCode.code),
                        tooltip: 'Copy code',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedStat(
                          context,
                          'Total Scans',
                          qrCode.scanCount.toString(),
                          Icons.qr_code_scanner,
                          Colors.blue,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: theme.dividerColor,
                      ),
                      Expanded(
                        child: _buildEnhancedStat(
                          context,
                          'Created',
                          _formatDate(qrCode.createdAt),
                          Icons.calendar_today,
                          Colors.green,
                        ),
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEnhancedStat(BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
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

  const QRCodeGenerator({super.key, required this.accountId, this.onGenerated});

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
      final qrCode = await _qrCodeService.getQRCodeByAccountId(
        widget.accountId,
      );

      if (qrCode == null) {
        // Generate new QR code
        final newQRCode = await _qrCodeService.createQRCodeForAccount(
          widget.accountId,
        );
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
      final theme = Theme.of(context);
      final hintColor = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface.withOpacity(0.7);

      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error.withOpacity(0.7)),
              const SizedBox(height: 16),
              Text(
                'Failed to load QR code',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: hintColor),
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
            builder: (context) =>
                QRCodeStatisticsScreen(accountId: widget.accountId),
          ),
        );
      },
    );
  }
}

/// Screen to display QR code statistics
class QRCodeStatisticsScreen extends StatefulWidget {
  final String accountId;

  const QRCodeStatisticsScreen({super.key, required this.accountId});

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
      final scans = await _qrCodeService.getScanLogsByAccountId(
        widget.accountId,
        limit: 20,
      );

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
          ? Builder(builder: (context) {
              final theme = Theme.of(context);
              final hintColor = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface.withOpacity(0.7);

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load statistics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: hintColor),
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
              );
            })
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Statistics cards
                  _buildStatisticsGrid(context),
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No scans yet',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share your QR code to get started',
                                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._recentScans!.map((scan) => _buildScanLogCard(context, scan)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          'Total Scans',
          _statistics?['total_scans']?.toString() ?? '0',
          Icons.qr_code_scanner,
          Colors.blue,
        ),
        _buildStatCard(
          context,
          'Today',
          _statistics?['today_scans']?.toString() ?? '0',
          Icons.today,
          Colors.green,
        ),
        _buildStatCard(
          context,
          'This Week',
          _statistics?['week_scans']?.toString() ?? '0',
          Icons.calendar_today,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          'This Month',
          _statistics?['month_scans']?.toString() ?? '0',
          Icons.calendar_month,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
                  style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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

  Widget _buildScanLogCard(BuildContext context, ScanLog scan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hintColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurface.withOpacity(0.7);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.12),
          child: Icon(Icons.qr_code_scanner, color: colorScheme.primary),
        ),
        title: Text(
          _formatDateTime(scan.scannedAt),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: scan.locationLat != null && scan.locationLng != null
            ? Text(
                'Location: ${scan.locationLat!.toStringAsFixed(4)}, ${scan.locationLng!.toStringAsFixed(4)}',
              )
            : const Text('No location data'),
        trailing: scan.deviceInfo != null
            ? Icon(Icons.phone_android, color: hintColor)
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
