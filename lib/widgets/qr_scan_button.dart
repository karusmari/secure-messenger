import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- PUUDU
import 'package:firebase_auth/firebase_auth.dart'; // <--- PUUDU (et teada, kes on praegune kasutaja)
import '../services/chat_service.dart';
import '../services/contact_service.dart'; 
import '../screens/user_profile_screen.dart'; 
import 'qr_scanner.dart'; // Sinu QrScannerWidget

class QrScanButton extends StatelessWidget {
  final ChatService chatService = ChatService();
  final ContactService contactService = ContactService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // <--- Lisatud autentimine

  QrScanButton({super.key});

  Future<void> _startScanning(BuildContext context) async {
    // 1. Avame QR skänneri ekraani ja ootame tulemust (skaneeritud e-maili)
    final String? scannedEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerWidget()),
    );

    // Kui kasutaja pani skänneri kinni midagi skaneerimata
    if (scannedEmail == null || scannedEmail.isEmpty) return;

    if (!context.mounted) return;

    // 2. Kuvame laadimisringi, kuni andmebaasist kasutajat otsime
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 3. Otsime Firestore'ist skaneeritud e-maili järgi kasutajat
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: scannedEmail.trim().toLowerCase())
          .get();

      // Sulgeme laadimisakna (Loading indicator), sest päring sai läbi
      if (!context.mounted) return;
      Navigator.pop(context);

      if (userQuery.docs.isNotEmpty) {
        final targetUserDoc = userQuery.docs.first;
        final String targetUserId = targetUserDoc.id;

        // 4. Kontrollime, kas see kasutaja on juba minu kontaktide hulgas
        final myUid = _auth.currentUser?.uid;
        bool alreadyFriend = false;

        if (myUid != null) {
          final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
          if (myDoc.exists) {
            final List<dynamic> myActiveChats = myDoc.data()?['chatsWith'] ?? [];
            alreadyFriend = myActiveChats.contains(targetUserId);
          }
        }

        if (!context.mounted) return;

        // 5. Suuname kasutaja uuele profiililehele (UserProfileScreen)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: targetUserId,
              userEmail: scannedEmail.trim(),
              isAlreadyFriend: alreadyFriend,
            ),
          ),
        );
      } else {
        // Kui sellise e-mailiga kasutajat andmebaasist ei leitud
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User with this email was not found.')),
        );
      }
    } catch (e) {
      // Veatöötlus (nt võrguprobleemid)
      if (!context.mounted) return;
      Navigator.pop(context); // Sulgeme laadimisakna, kui see veel lahti on
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