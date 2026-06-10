import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secure_messenger/services/encryption_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Peamine meetod meedia saatmiseks Base64 kujul
  Future<void> sendMediaMessage(String receiverId, File file, String type, bool isSecret) async {
    
    final int fileSizeInBytes = await file.length();
    final double fileSizeInKB = fileSizeInBytes / 1024;

    if (fileSizeInKB > 650) {
      throw Exception("File is too large to send. Please select a file smaller than 650KB.");
    }
    
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    // Loome chatRoomId täpselt samamoodi
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // 1. Loeme faili baitidena sisse ja teisendame Base64 stringiks
    final List<int> fileBytes = await file.readAsBytes();
    String base64Content = base64Encode(fileBytes);

    // 2. Kui on Secret Chat, krüpteerime Base64 sisu
    String finalContent = base64Content;
    if (isSecret) {
      finalContent = EncryptionService.encryptText(base64Content);
    }

    // 3. Salvestame sõnumi Firestore-i (Kasutades PARANDATUD TEED ja kõiki vajalikke välju)
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail, // Lisatud ühilduvuse tagamiseks
      'receiverId': receiverId,
      'message': finalContent,
      'messageType': type, // "image", "video", "audio"
      'timestamp': timestamp,
      'isSecret': isSecret,
      'isRead': false,
      'readAt': null,
      'isEdited': false,
      'editedAt': null,
    };

    // Salvestame sõnumi samasse chats kollektsiooni nagu tekstisõnumid
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);

    // Salvestame seose chatsWith massiivi (et see vestlus ilmuks mõlema kasutaja listi)
    await _db.collection('users').doc(currentUserId).update({
      'chatsWith': FieldValue.arrayUnion([receiverId])
    }).catchError((_) => _db.collection('users').doc(currentUserId).set({'chatsWith': [receiverId]}, SetOptions(merge: true)));

    await _db.collection('users').doc(receiverId).update({
      'chatsWith': FieldValue.arrayUnion([currentUserId])
    }).catchError((_) => _db.collection('users').doc(receiverId).set({'chatsWith': [currentUserId]}, SetOptions(merge: true)));

    // Lugemata sõnumite arv +1
    await _db.collection('users').doc(receiverId).collection('unread').doc(currentUserId).set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // 1. SAADA SÕNUM
  Future<void> sendMessage(String receiverId, String message, bool isSecret) async {
    String messageToSend = isSecret ? EncryptionService.encryptText(message) : message;
    
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': messageToSend,
      'messageType': 'text', // Lisatud vaikimisi tüüp, et eristada meediast
      'timestamp': timestamp,
      'isSecret': isSecret, 
      'isRead': false,
      'readAt': null,
      'isEdited': false,
      'editedAt': null,
    };

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).collection('messages').add(newMessage);

    // Salvestame seose chatsWith massiivi
    await _db.collection('users').doc(currentUserId).update({
      'chatsWith': FieldValue.arrayUnion([receiverId])
    }).catchError((_) => _db.collection('users').doc(currentUserId).set({'chatsWith': [receiverId]}, SetOptions(merge: true)));

    await _db.collection('users').doc(receiverId).update({
      'chatsWith': FieldValue.arrayUnion([currentUserId])
    }).catchError((_) => _db.collection('users').doc(receiverId).set({'chatsWith': [currentUserId]}, SetOptions(merge: true)));

    // Lugemata sõnumite arv +1
    await _db.collection('users').doc(receiverId).collection('unread').doc(currentUserId).set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // 2. KUULA SÕNUMEID REAALAJAS
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // MÄRGI SÕNUMID LOETUKS
  Future<void> markMessagesAsRead(String otherUserId) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    final messageSnapshot = await _db.collection('chats').doc(chatRoomId).collection('messages').get();

    final unreadMessages = messageSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['receiverId'] == currentUserId && data['senderId'] == otherUserId && data['isRead'] != true;
    }).toList();

    if (unreadMessages.isEmpty) return;

    final batch = _db.batch();
    final Timestamp readAt = Timestamp.now();

    for (final doc in unreadMessages) {
      batch.update(doc.reference, {'isRead': true, 'readAt': readAt});
    }
    await batch.commit();
  }

  // MUUDA SÕNUMIT
  Future<void> editMessage(String receiverId, String messageId, String newMessage, bool isSecret) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String messageToSave = isSecret ? EncryptionService.encryptText(newMessage) : newMessage;

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).update({
      'message': messageToSave,
      'isSecret': isSecret,
      'isEdited': true,
      'editedAt': Timestamp.now(),
    });
  }

  // KUSTUTA SÕNUM
  Future<void> deleteMessage(String receiverId, String messageId) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).delete();
  }

  // AKTIIVSED VESTLUSED
  Stream<List<Map<String, dynamic>>> getActiveChatsStream() {
    final String currentUserId = _auth.currentUser!.uid;

    return _db.collection('users').snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> activeUsers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String otherUserId = doc.id;
        data['uid'] = otherUserId;

        if (otherUserId == currentUserId) continue;

        List<String> ids = [currentUserId, otherUserId];
        ids.sort();
        String chatRoomId = ids.join('_');

        final messageSnapshot = await _db.collection('chats').doc(chatRoomId).collection('messages').limit(1).get();

        if (messageSnapshot.docs.isNotEmpty) {
          activeUsers.add(data);
        }
      }
      return activeUsers;
    });
  }

  // MUUDA TRÜKKIMISE STAATUST
  Future<void> setTypingStatus(String receiverId, bool isTyping) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).set({
      'typing': { currentUserId: isTyping }
    }, SetOptions(merge: true));
  }

  // KUULA TRÜKKIMIST
  Stream<bool> getTypingStatusStream(String chatRoomId, String receiverId) {
    return _db.collection('chats').doc(chatRoomId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        Map<String, dynamic> typingMap = snapshot.data()!['typing'] ?? {};
        return typingMap[receiverId] ?? false;
      }
      return false;
    });
  }

  // NULLI LUGEMATA SÕNUMID
  Future<void> clearUnreadCount(String callerId) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _db.collection('users').doc(currentUserId).collection('unread').doc(callerId).set({
      'count': 0,
    }, SetOptions(merge: true));
  }
}