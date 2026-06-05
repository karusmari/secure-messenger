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

    // 🌟 EEMALDATUD KONTEINER: Tagastame otse ListTile, et taust oleks puhas äpi taust
    return ListTile(
      dense: false, // Messengeri stiilis suurema pildi jaoks sobib false paremini
      
      // Määrame mugava paddingu (vasakult/paremalt sissepoole, vertikaalselt mõnus hingamisruum)
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),

      // 👥 PROFIILIPILT (Nüüd suurem ja esinduslikum, täiesti ümmargune)
      leading: CircleAvatar(
        radius: 26, // Tõstsime raadiust, pilt on nüüd suurem ja ilusam
        backgroundColor: const Color(0xFF3C3D37), // Kasutame taustaks paleti halli
        child: peerImage != null && peerImage.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(26), // Täpselt sama mis radius
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
                  color: Theme.of(context).colorScheme.primary, // ECDFCC toon
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),

      // 📝 KASUTAJA NIMI
      title: Text(
        displayTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16, // Veidi suurem ja loetavam puhtal taustal
          letterSpacing: 0.2,
        ),
      ),

      // 📧 KASUTAJA EMAIL
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          peerEmail,
          style: const TextStyle(
            color: Color(0xFF697565), // Sinu stiilne rohekas-hall
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),

      // 🔴 LUGEMATA SÕNUMID
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
                  color: const Color(0xFFECDFCC), // Kasutame kreemikat esiletõstuks (või jäta punaseks)
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Color(0xFF181C14), // Tume tekst kreemikal taustal
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
          }
          // Puhas ja minimalistlik pisike nooleke paremas ääres
          return const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF3C3D37));
        },
      ),

      // 🔓 VAJUTUSE LOOGIKA
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