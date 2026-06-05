import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'qr_scanner.dart'; // Sinu QrScannerWidget

class QrScanButton extends StatelessWidget {
  final ChatService chatService = ChatService();

  QrScanButton({super.key});

  Future<void> _startScanning(BuildContext context) async {
    // 1. Avame skänneri ja ootame tulemust
    final String? scannedEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerWidget()),
    );

    if (scannedEmail == null || scannedEmail.isEmpty) return;

    // 2. Näitame laadimise indikaatorit
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 3. Kutsume välja uue teenuse funktsiooni
      final String resultMessage = await chatService.addChatByEmail(scannedEmail);

      // 4. Sulgeme laadimisakna
      if (!context.mounted) return;
      Navigator.pop(context);

      // 5. Näitame tulemust ekraani all ääres
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultMessage)),
      );
    } catch (e) {
      // Vigade käsitlemine
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () => _startScanning(context),
    );
  }
}