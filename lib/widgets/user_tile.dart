import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';

class UserTile extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserTile({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final String? peerImage = userData['profilePicture'];
    final String peerEmail = userData['email'] ?? 'U';
    final String peerUsername = userData['username'] ?? '';
    final String peerUid = (userData['uid'] ?? '').toString();

    final String displayLetter = (peerUsername.isNotEmpty ? peerUsername : peerEmail)
        .substring(0, 1)
        .toUpperCase();

    final String displayTitle = (peerUsername.isNotEmpty)
        ? peerUsername
        : (userData['email'] ?? 'Unknown User').toString();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[700],
        child: peerImage != null && peerImage.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  base64Decode(peerImage),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                displayLetter,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
      ),
      title: Text(displayTitle),
      trailing: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('unread')
            .doc(peerUid)
            .snapshots(),
        builder: (context, unreadSnapshot) {
          if (unreadSnapshot.hasData && unreadSnapshot.data!.exists) {
            Map<String, dynamic>? unreadData = unreadSnapshot.data!.data() as Map<String, dynamic>?;
            int count = unreadData?['count'] ?? 0;

            if (count > 0) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              );
            }
          }
          return const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey);
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverEmail: displayTitle,
              receiverId: peerUid,
            ),
          ),
        );
      },
    );
  }
}