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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: scannerController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            final String scannedEmail = barcodes.first.rawValue!;
            
            // Tagastame skannitud emaili eelmisele ekraanile
            Navigator.pop(context, scannedEmail); 
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