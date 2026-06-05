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

  // 1. 🌟 LUKK: Hoiab ära olukorra, kus kaamera proovib ekraani sulgemise ajal uuesti skannida
  bool _hasScanned = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: scannerController,
        // 2. 🌟 MUUDATUS: Tegime funktsiooni asünkroonseks (async), et saaksime kaamera peatada
        onDetect: (capture) async {
          if (_hasScanned) return; // Kui kood on juba leitud, ignoreeri kõiki järgnevaid kaadreid

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            setState(() {
              _hasScanned = true; // Paneme luku kohe peale
            });

            final String scannedEmail = barcodes.first.rawValue!;
            
            // 3. 🌟 KÕIGE OLULISEM PARANDUS: Peatame kaamera riistvara täielikult ENNE navigeerimist
            await scannerController.stop(); 
            
            if (mounted) {
              // Tagastame skannitud emaili eelmisele ekraanile
              Navigator.pop(context, scannedEmail); 
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    // Kontrollime igaks juhuks, et kontroller suletaks korrektselt ka siis, kui kasutaja lihtsalt tagasi nuppu vajutab
    scannerController.dispose();
    super.dispose();
  }
}