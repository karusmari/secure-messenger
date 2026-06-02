import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. SAA DA SÕNUM
  Future<void> sendMessage(String receiverId, String message) async {
    // Küsime praeguse sisselogitud kasutaja andmed
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    // Loome sõnumi objekti
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
    };

    // Genereerime unikaalse ruumi ID kahe kasutaja jaoks (järjestame tähestiku alusel, et mõlemal oleks sama ID)
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_'); // Tulemus näiteks: uid1_uid2

    // Salvestame sõnumi andmebaasi
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);
  }

  // 2. KUULA SÕNUMEID REAALAJAS (Stream)
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Toome sõnumid ajaliselt järjestatuna (kõige uuemad tulevad järjest juurde)
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // 3. TOOME KÕIK KASUTAJAD (Et näidata neid pealehel nimekirjana)
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id; // Lisame dokumendi ID andmetesse, et saaksime hiljem kasutaja ID-d kasutada
        return data;
      }).toList();
    });
  }
}