import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Toome kõik kasutajad (Et näidata neid pealehel nimekirjana)
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Muuda pilt tekstiks ja salvesta Firestore'i
  Future<void> uploadAndChangeProfilePicture(File imageFile) async {
    final String currentUserId = _auth.currentUser!.uid;
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      await _db.collection('users').doc(currentUserId).update({
        'profilePicture': base64Image,
      });
    } catch (e) {
      throw Exception("Failed to save image: $e");
    }
  }

  // Uuenda kasutaja profiili (Kasutajanimi ja pilt)
  Future<void> updateUserProfile(String username, String profilePicUrl) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _db.collection('users').doc(currentUserId).update({
      'username': username,
      'profilePicture': profilePicUrl,
    });
  }
}