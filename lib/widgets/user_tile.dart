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
      dense: false, 
      
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),

      leading: CircleAvatar(
        radius: 26, 
        backgroundColor: const Color(0xFF3C3D37), 
        child: peerImage != null && peerImage.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(26), 
                child: Image.memory(
                  base64Decode(peerImage),
                  width: 52,  // 26 * 2
                  height: 52, // 26 * 2
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                displayLetter,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),

      title: Text(
        displayTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16, 
          letterSpacing: 0.2,
        ),
      ),

      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          peerEmail,
          style: const TextStyle(
            color: Color(0xFF697565), 
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),

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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECDFCC), 
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Color(0xFF181C14), 
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
          }
          return const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF3C3D37));
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