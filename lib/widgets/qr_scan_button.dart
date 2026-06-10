import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import '../services/chat_service.dart';
import '../services/contact_service.dart'; 
import '../screens/user_profile_screen.dart'; 
import 'qr_scanner.dart'; // Sinu QrScannerWidget

class QrScanButton extends StatelessWidget {
  final ChatService chatService = ChatService();
  final ContactService contactService = ContactService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  QrScanButton({super.key});

  Future<void> _startScanning(BuildContext context) async {
    // open the QR scanner and wait for the result (the scanned email)
    final String? scannedEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerWidget()),
    );

    // in case the user cancels scanning or no email is scanned, we do nothing
    if (scannedEmail == null || scannedEmail.isEmpty) return;

    if (!context.mounted) return;

    // circular loading indicator while we process the scanned email and fetch user data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // finding the user in the database by the scanned email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: scannedEmail.trim().toLowerCase())
          .get();

      // closing the loading indicator
      if (!context.mounted) return;
      Navigator.pop(context);

      if (userQuery.docs.isNotEmpty) {
        final targetUserDoc = userQuery.docs.first;
        final String targetUserId = targetUserDoc.id;

        // checking if the scanned user is already in the current user's active chats (already a friend)
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

        // redirecting to the scanned user's profile page, passing the scanned email and friendship status
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
        // in case no user is found with the scanned email, we show a message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User with this email was not found.')),
        );
      }
    } catch (e) {
      // in case of any error (network issues, database errors, etc), we close the loading indicator and show an error message
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