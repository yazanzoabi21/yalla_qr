import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'home_item.dart';
import '../../widgets/navbar.dart';
import '../../models/category.dart';
import '../../models/qr_code.dart';
import '../../services/category_service.dart';
import '../../services/qr_code_service.dart';
import '../../utils/navigation_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? lastClicked;
  List<Category> categories = [];
  bool isLoadingCategories = true;
  String? errorMessage;
  String? _orgAccountId; // Store ORG account ID for QR code display
  bool _showQRButton = false; // Control QR button visibility

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if user logged in from different context
    final prefs = await SharedPreferences.getInstance();
    final loginContext = prefs.getString('login_context'); // 'ORG' or 'CLIENT'
    final existingUser = Supabase.instance.client.auth.currentUser;

    if (existingUser != null) {
      debugPrint(
        '🔄 [HomeScreen] Found existing session: ${existingUser.email}',
      );
      debugPrint('🔄 [HomeScreen] Login context: $loginContext');

      // If user logged in from CLIENT context, sign them out
      if (loginContext == 'CLIENT') {
        debugPrint(
          '🔄 [HomeScreen] User logged in from CLIENT context - signing out',
        );
        await Supabase.instance.client.auth.signOut();
        await prefs.remove('login_context');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login with an ORGANIZATION account'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }

    // Load data (navbar will prompt for login)
    loadLastClicked();
    loadCategories();
    _loadOrgAccount(); // Load ORG account for QR button
  }

  /// Load ORG account ID for QR code display
  Future<void> _loadOrgAccount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final orgAccount = await Supabase.instance.client
            .from('accounts')
            .select('id')
            .eq('owner_id', user.id)
            .eq('role', 'ORG')
            .maybeSingle();

        if (orgAccount != null && mounted) {
          setState(() {
            _orgAccountId = orgAccount['id'] as String;
            _showQRButton = true; // Show button initially
          });
          debugPrint('✅ [HomeScreen] Found ORG account ID: $_orgAccountId');

          // Hide button after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showQRButton = false;
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error loading ORG account: $e');
    }
  }

  /// Check if current user is CLIENT - if so, sign them out
  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        debugPrint('🔍 [HomeScreen] Checking user role...');
        debugPrint('   📧 Current auth user: ${user.email}');

        // Check user's role in accounts table - need to handle multiple accounts
        final accountsResponse = await Supabase.instance.client
            .from('accounts')
            .select('role, name')
            .eq('owner_id', user.id);

        if (accountsResponse.isNotEmpty) {
          // Check if ANY account is ORG role
          final hasOrgAccount = accountsResponse.any(
            (acc) => acc['role'] == 'ORG',
          );
          final firstAccount = accountsResponse.first;
          final role = firstAccount['role'] as String?;
          final name = firstAccount['name'] as String?;

          debugPrint('   👤 Found ${accountsResponse.length} account(s)');
          debugPrint('   👤 First account role: $role, name: $name');
          debugPrint('   👤 Has ORG account: $hasOrgAccount');

          // If user ONLY has CLIENT accounts (no ORG), sign them out
          if (!hasOrgAccount && role == 'USER') {
            debugPrint(
              '   ⚠️ CLIENT-only user detected on ORG page - signing out',
            );
            await Supabase.instance.client.auth.signOut();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please login with an ORGANIZATION account to manage categories',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );

              // Force state update to show login prompt
              setState(() {
                isLoadingCategories = false;
              });
            }
          } else {
            debugPrint('   ✅ ORG user confirmed');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking user role: $e');
    }
  }

  Future<void> loadCategories() async {
    try {
      setState(() {
        isLoadingCategories = true;
        errorMessage = null;
      });

      // Fetch only parent categories (categories without parent_id) for current account
      final fetchedCategories = await CategoryService.getParentCategoriesForAccount();

      if (!mounted) return;

      setState(() {
        categories = fetchedCategories;
        isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load categories: ${e.toString()}';
        isLoadingCategories = false;
      });
    }
  }

  Future<void> loadLastClicked() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTitle = prefs.getString('lastClicked');

    if (!mounted) return;
    if (savedTitle != null) {
      setState(() {
        lastClicked = savedTitle;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context);
    }
  }

  Future<void> updateLastClicked(String title) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastClicked', title);

    if (!mounted) return;
    setState(() {
      lastClicked = title;
    });

    // Optional: show feedback toast
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text('Last Clicked: $title')),
    // );

    // Navigate to the selected category screen
    NavigationHelper.navigateToCategory(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: const Navbar(),
      body: Padding(padding: const EdgeInsets.all(12.0), child: _buildBody()),
      floatingActionButton: _orgAccountId != null
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: _showQRButton
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A), // Navy blue
                          Color(0xFF3B82F6), // Bright blue
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _showQRButton ? null : Colors.transparent,
                boxShadow: _showQRButton
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showQRCodeModal,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _showQRButton ? 20 : 0,
                      vertical: _showQRButton ? 12 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        // Spacer and text that fade away after 3s
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _showQRButton
                              ? const SizedBox(width: 12)
                              : const SizedBox.shrink(),
                        ),
                        AnimatedOpacity(
                          opacity: _showQRButton ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: _showQRButton
                              ? const Text(
                                  'QR Code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 0.3,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// Show QR code in a clean modal dialog - only the scannable QR
  void _showQRCodeModal() {
    if (_orgAccountId == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'QR Code',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: FadeTransition(
                opacity: animation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header section
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.qr_code_2_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Your QR Code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      // QR Code Display
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            const Text(
                              'Share this code with your clients',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _QRCodeOnlyWidget(accountId: _orgAccountId!),
                            const SizedBox(height: 24),
                            // Share button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _shareQRCode(),
                                icon: const Icon(Icons.share_rounded, size: 22),
                                label: const Text(
                                  'Share QR Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Share QR code as image
  Future<void> _shareQRCode() async {
    if (_orgAccountId == null) return;

    try {
      // Show loading
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

      // Get QR code from service
      final qrCodeService = QRCodeService(Supabase.instance.client);
      final qrCode = await qrCodeService.getQRCodeByAccountId(_orgAccountId!);

      if (qrCode != null) {
        // Generate QR code image (transparent PNG)
        final qrPainter = QrPainter(
          data: qrCode.code,
          version: QrVersions.auto,
          gapless: true,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF1E3A8A),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF1A1A1A),
          ),
        );

        final ByteData? rawPng = await qrPainter.toImageData(
          1024,
          format: ui.ImageByteFormat.png,
        );

        if (rawPng != null) {
          // Ensure a white background and adequate quiet-zone padding
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

          // Draw original QR centered with padding
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
            // Share as PNG image directly
            await Printing.sharePdf(
              bytes: bytes,
              filename: 'qr_code_${qrCode.code}.png',
            );

            if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to share: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildBody() {
    if (isLoadingCategories) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading categories...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadCategories,
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.6, // Makes cards taller (width/height ratio)
        children: _buildGridItems(),
      ),
    );
  }

  List<Widget> _buildGridItems() {
    List<Widget> items = [];

    // Add database categories first
    for (Category category in categories) {
      items.add(
        HomeItem(
          title: category.name,
          color: category.color,
          imagePath: category.imagePath,
          lastClicked: lastClicked,
          onTap: updateLastClicked,
        ),
      );
    }

    // Fill remaining slots with "Coming Soon" cards to maintain the 2x4 grid
    final totalSlots = 8;
    final remainingSlots = totalSlots - categories.length;

    final List<Color> comingSoonColors = [
      Colors.indigo,
      Colors.amber,
      Colors.pink,
      Colors.lime,
      Colors.cyan,
      Colors.brown,
    ];

    for (int i = 0; i < remainingSlots && i < comingSoonColors.length; i++) {
      items.add(
        HomeItem(
          title: 'Coming Soon',
          color: comingSoonColors[i],
          lastClicked: lastClicked,
          onTap: updateLastClicked,
        ),
      );
    }

    return items;
  }
}

/// Simple widget to display only the QR code for scanning
class _QRCodeOnlyWidget extends StatefulWidget {
  final String accountId;

  const _QRCodeOnlyWidget({required this.accountId});

  @override
  State<_QRCodeOnlyWidget> createState() => _QRCodeOnlyWidgetState();
}

class _QRCodeOnlyWidgetState extends State<_QRCodeOnlyWidget> {
  final _qrCodeService = QRCodeService(Supabase.instance.client);
  bool _isLoading = true;
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
        if (mounted) {
          setState(() {
            _qrCode = newQRCode;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _qrCode = qrCode;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Failed to load QR code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadQRCode,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_qrCode == null) {
      return const SizedBox.shrink();
    }

    // Display only the QR code - clean and scannable
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
              width: 2,
            ),
          ),
          child: QrImageView(
            data: _qrCode!.code,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1E3A8A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }
}
