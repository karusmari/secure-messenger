import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secure_messenger/services/encryption_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // method to send a media message (image, video, audio)
  Future<void> sendMediaMessage(String receiverId, File file, String type, bool isSecret) async {
    
    final int fileSizeInBytes = await file.length();
    final double fileSizeInKB = fileSizeInBytes / 1024;

    if (fileSizeInKB > 650) {
      throw Exception("File is too large to send. Please select a file smaller than 650KB.");
    }
    
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    // creating a consistent chat room ID based on user IDs (sorted to ensure the same ID regardless of sender/receiver order)
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // reading the file as bytes and converting to Base64 string
    final List<int> fileBytes = await file.readAsBytes();
    String base64Content = base64Encode(fileBytes);

    // in case of secret message, we encrypt the Base64 string before sending
    String finalContent = base64Content;
    if (isSecret) {
      finalContent = EncryptionService.encryptText(base64Content);
    }

    // Saving the message in firestore with all necessary metadata, including the type of media and whether it's secret or not
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail, 
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

    // saving the message in a subcollection "messages" under a document named after the chatRoomId in the "chats" collection
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);

    // saving the relationship in the "chatsWith" array for the current user (sender) if it doesn't already exist, so that we can easily query active chats later
    await _db.collection('users').doc(currentUserId).update({
      'chatsWith': FieldValue.arrayUnion([receiverId])
    }).catchError((_) => _db.collection('users').doc(currentUserId).set({'chatsWith': [receiverId]}, SetOptions(merge: true)));

    // same on the receiver's side
    await _db.collection('users').doc(receiverId).update({
      'chatsWith': FieldValue.arrayUnion([currentUserId])
    }).catchError((_) => _db.collection('users').doc(receiverId).set({'chatsWith': [currentUserId]}, SetOptions(merge: true)));

    // unread message count +1 for the receiver, stored in a subcollection "unread" under each user document, with documents named after the sender's user ID, containing a "count" field that we increment
    await _db.collection('users').doc(receiverId).collection('unread').doc(currentUserId).set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // sending the message (both secret and non-secret text messages)
  Future<void> sendMessage(String receiverId, String message, bool isSecret) async {
    String messageToSend = isSecret ? EncryptionService.encryptText(message) : message;
    
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    // creating a map with all the metadata for the message
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': messageToSend,
      'messageType': 'text', // default type is "text" to separate from media messages
      'timestamp': timestamp,
      'isSecret': isSecret, 
      'isRead': false,
      'readAt': null,
      'isEdited': false,
      'editedAt': null,
    };

    // creating a chat room ID based on the user IDs (sorted to ensure consistency)
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).collection('messages').add(newMessage);

    // saving the relationship in the "chatsWith" array for the current user (sender) 
    await _db.collection('users').doc(currentUserId).update({
      'chatsWith': FieldValue.arrayUnion([receiverId])
    }).catchError((_) => _db.collection('users').doc(currentUserId).set({'chatsWith': [receiverId]}, SetOptions(merge: true)));

    // same on the receiver's side
    await _db.collection('users').doc(receiverId).update({
      'chatsWith': FieldValue.arrayUnion([currentUserId])
    }).catchError((_) => _db.collection('users').doc(receiverId).set({'chatsWith': [currentUserId]}, SetOptions(merge: true)));

    // unread messages count +1 for the receiver
    await _db.collection('users').doc(receiverId).collection('unread').doc(currentUserId).set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // listening to messages in real-time for a specific chat
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

  // mark the messages as read 
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

  // edit message (both secret and non-secret)
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

  Future<void> deleteMessage(String receiverId, String messageId) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).delete();
  }

  // active chats stream - to show the list of users
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

  // typing status
  Future<void> setTypingStatus(String receiverId, bool isTyping) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _db.collection('chats').doc(chatRoomId).set({
      'typing': { currentUserId: isTyping }
    }, SetOptions(merge: true));
  }

  // listen to the typing status of the other user in real-time
  Stream<bool> getTypingStatusStream(String chatRoomId, String receiverId) {
    return _db.collection('chats').doc(chatRoomId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        Map<String, dynamic> typingMap = snapshot.data()!['typing'] ?? {};
        return typingMap[receiverId] ?? false;
      }
      return false;
    });
  }

  // clear unread message count when the user opens the chat
  Future<void> clearUnreadCount(String callerId) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _db.collection('users').doc(currentUserId).collection('unread').doc(callerId).set({
      'count': 0,
    }, SetOptions(merge: true));
  }
}