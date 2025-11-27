import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/scan_prompt_overlay.dart';
import '../../services/qr_scanner_service.dart';

class ClientCategoriesScreen extends StatefulWidget {
  const ClientCategoriesScreen({super.key});

  @override
  State<ClientCategoriesScreen> createState() => _ClientCategoriesScreenState();
}

class _ClientCategoriesScreenState extends State<ClientCategoriesScreen> {
  bool _showScanPrompt = true;
  String? _scannedResult;

  Future<void> _handleScan() async {
    final result = await QRScannerService.scanQRCode(context);
    if (result != null) {
      setState(() {
        _scannedResult = result;
        _showScanPrompt = false;
      });
      // TODO: Handle scanned QR code result
    }
  }

  void _handleSkip() {
    setState(() {
      _showScanPrompt = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: Navbar(
        showScanButton: true,
        onScanPressed: _handleScan,
      ),
      body: Stack(
        children: [
          // Main content - Empty state
          Center(
            child: EmptyStateWidget(
              message: _scannedResult ?? 'No Results Found',
              icon: Icons.qr_code_2,
              subtitle: _scannedResult == null 
                ? 'Scan a QR code to get started'
                : null,
            ),
          ),
          
          // Scan prompt overlay
          if (_showScanPrompt)
            ScanPromptOverlay(
              onScan: _handleScan,
              onSkip: _handleSkip,
            ),
        ],
      ),
    );
  }
}
