import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> addChatByEmail(String email) async {
    final String currentUid = _auth.currentUser!.uid;
    final String currentEmail = _auth.currentUser?.email ?? '';

    if (email.toLowerCase() == currentEmail.toLowerCase()) {
      return "You scanned your own QR code!";
    }

    final userQuery = await _db
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .get();

    if (userQuery.docs.isEmpty) {
      return "No user found with email: $email";
    }

    final String targetUid = userQuery.docs.first.id;
    final batch = _db.batch();
    
    batch.update(_db.collection('users').doc(currentUid), {
      'chatsWith': FieldValue.arrayUnion([targetUid])
    });
    
    batch.update(_db.collection('users').doc(targetUid), {
      'chatsWith': FieldValue.arrayUnion([currentUid])
    });

    await batch.commit();
    return "Chat with $email added!";
  }
}