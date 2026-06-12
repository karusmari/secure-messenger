import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import '../services/chat_service.dart';
import '../services/contact_service.dart'; 
import '../screens/user_profile_screen.dart'; 
import 'qr_scanner.dart';

class QrScanButton extends StatelessWidget {
  final ChatService chatService = ChatService();
  final ContactService contactService = ContactService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  QrScanButton({super.key});

  // Orchestrates the scanning flow and routing execution
  Future<void> _startScanning(BuildContext context) async {
    // Open native camera interface via QR Scanner widget and await the string payload
    final String? scannedEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerWidget()),
    );

    if (scannedEmail == null || scannedEmail.isEmpty) return;
    if (!context.mounted) return;

    // Display a blocking global loading spinner during the network request lifecycle
    _showLoadingDialog(context);

    try {
      final sanitizedEmail = scannedEmail.trim().toLowerCase();
      
      // Query the Cloud Firestore collection for a user tracking record matching the scanned email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: sanitizedEmail)
          .get();

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss the loading spinner safely

      if (userQuery.docs.isNotEmpty) {
        final targetUserDoc = userQuery.docs.first;
        final String targetUserId = targetUserDoc.id;

        // 4. Evaluate the user's relational friendship status before rendering profile
        final bool alreadyFriend = await _checkIfAlreadyFriend(targetUserId);

        if (!context.mounted) return;

        // 5. Navigate cleanly to the target profile view, supplying relationship parameters
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
        _showSnackBar(context, 'User with this email was not found.');
      }
    } catch (e) {
      // Intercept execution breaks, clear loading UI contexts, and dispatch alerts
      if (!context.mounted) return;
      Navigator.pop(context); // Safe escape: ensure spinner is dismissed on system crash
      _showSnackBar(context, 'An error occurred during verification: $e');
    }
  }

  // ARCHITECTURAL HELPERS

  // Displays a centralized operational progress barrier
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  // Unified toast system interface for quick context error dispatches
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Queries current user context metadata parameters to verify existing active chats
  Future<bool> _checkIfAlreadyFriend(String targetUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return false;

    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    if (!myDoc.exists) return false;

    final List<dynamic> myActiveChats = myDoc.data()?['chatsWith'] ?? [];
    return myActiveChats.contains(targetUserId);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      tooltip: 'Scan Contact QR Code',
      onPressed: () => _startScanning(context),
    );
  }
}