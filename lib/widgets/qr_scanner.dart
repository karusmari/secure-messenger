import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerWidget extends StatefulWidget {
  const QrScannerWidget({super.key});

  @override
  State<QrScannerWidget> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerWidget> {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasScanned = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: scannerController,
        onDetect: (capture) async {
          if (_hasScanned) return; 

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            setState(() {
              _hasScanned = true; 
            });

            final String scannedEmail = barcodes.first.rawValue!;
            
            await scannerController.stop(); 
            
            if (mounted) {
              Navigator.pop(context, scannedEmail); 
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }
}