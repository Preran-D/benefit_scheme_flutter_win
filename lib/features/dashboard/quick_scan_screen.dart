import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';

class QuickScanScreen extends StatefulWidget {
  const QuickScanScreen({super.key});

  @override
  State<QuickScanScreen> createState() => _QuickScanScreenState();
}

class _QuickScanScreenState extends State<QuickScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        _controller.stop();
        // Assuming QR code contains Customer ID or Scheme ID
        // For now, just show a dialog or route to customer details
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: $code')));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Scan QR'),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
