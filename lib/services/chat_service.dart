import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secure_messenger/services/encryption_service.dart';
import 'dart:convert';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. SAA DA SÕNUM
  Future<void> sendMessage(String receiverId, String message, bool isSecret) async {

    //in case of a secret chat we will encrypt it
    String messageToSend = message;
    if (isSecret) {
      messageToSend = EncryptionService.encryptText(message);
    }
    // Küsime praeguse sisselogitud kasutaja andmed
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    // Loome sõnumi objekti
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': messageToSend,
      'timestamp': timestamp,
      'isSecret': isSecret, 
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

        // See loob massiivi 'chatsWith', kus on kirjas kõigi suheldud inimeste ID-d.
    await _db.collection('users').doc(currentUserId).update({
      'chatsWith': FieldValue.arrayUnion([receiverId])
    }).catchError((_) => _db.collection('users').doc(currentUserId).set({'chatsWith': [receiverId]}, SetOptions(merge: true)));

    await _db.collection('users').doc(receiverId).update({
      'chatsWith': FieldValue.arrayUnion([currentUserId])
    }).catchError((_) => _db.collection('users').doc(receiverId).set({'chatsWith': [currentUserId]}, SetOptions(merge: true)));

    // sonumi kättesaamise teavitus
    await _db
        .collection('users')
        .doc(receiverId)
        .collection('unread')
        .doc(currentUserId)
        .set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
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
  // 4. TOOME KASUTAJAD, KELLEGA ON REAALNE VESTLUS OLEMAS (Parandatud versioon)
  Stream<List<Map<String, dynamic>>> getActiveChatsStream() {
    final String currentUserId = _auth.currentUser!.uid;

    // Kuulame kõiki kasutajaid
    return _db.collection('users').snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> activeUsers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String otherUserId = doc.id;
        data['uid'] = otherUserId;

        if (otherUserId == currentUserId) continue;

        // Kontrollime suvalist jututuba kahe kasutaja vahel (mõlemat pidi sorteeritult)
        List<String> ids = [currentUserId, otherUserId];
        ids.sort();
        String chatRoomId = ids.join('_');

        // Vaatame, kas seal on kasvõi üks sõnum olemas
        final messageSnapshot = await _db
            .collection('chats')
            .doc(chatRoomId)
            .collection('messages')
            .limit(1)
            .get();

        if (messageSnapshot.docs.isNotEmpty) {
          activeUsers.add(data);
        }
      }
      return activeUsers;
    });
  }

  // 6. MUUDA PILT TEKSTIKS JA SALVESTA FIRESTORE'I (TASUTA JA LOLLIKINDEL)
  Future<void> uploadAndChangeProfilePicture(File imageFile) async {
    final String currentUserId = _auth.currentUser!.uid;

    try {
      // Loeme faili bittidena sisse
      List<int> imageBytes = await imageFile.readAsBytes();
      // Muudame bitid Base64 tekstijadaks
      String base64Image = base64Encode(imageBytes);

      // Salvestame selle pika teksti otse kasutaja profiili alla
      await _db.collection('users').doc(currentUserId).update({
        'profilePicture': base64Image,
      });
    } catch (e) {
      throw Exception("Failed to save image: $e");
    }
  }

  // 5. UUEDA KASUTAJA PROFIILI (Kasutajanimi ja pilt)
  Future<void> updateUserProfile(String username, String profilePicUrl) async {
    final String currentUserId = _auth.currentUser!.uid;

    await _db.collection('users').doc(currentUserId).update({
      'username': username,
      'profilePicture': profilePicUrl,
    });
  }

  // 7. UUEDA TRÜKKIMISE STAATUST
  Future<void> setTypingStatus(String receiverId, bool isTyping) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Salvestame vestlusruumi dokumenti info, kes parajasti trükib
    await _db.collection('chats').doc(chatRoomId).set({
      'typing': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  // 8. KUULA, KAS TEINE KASUTAJA TRÜKIB
  Stream<bool> getTypingStatusStream(String chatRoomId, String receiverId) {
    return _db.collection('chats').doc(chatRoomId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        Map<String, dynamic> typingMap = snapshot.data()!['typing'] ?? {};
        return typingMap[receiverId] ?? false;
      }
      return false;
    });
  }

  // 9. NULLI LUGEMATA SÕNUMITE ARV (Kui kasutaja avab vestluse)
  Future<void> clearUnreadCount(String callerId) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('unread')
        .doc(callerId)
        .set({
      'count': 0,
    }, SetOptions(merge: true));
  }
}