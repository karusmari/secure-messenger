import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // getting all the users in real-time (for the search screen)
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }

  // change the profile picture of the user (uploading to Firestore as base64 string)
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

  // update the username and profile picture URL in Firestore
  Future<void> updateUserProfile(String username, String profilePicUrl) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _db.collection('users').doc(currentUserId).update({
      'username': username,
      'profilePicture': profilePicUrl,
    });
  }
}