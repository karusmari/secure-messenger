import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secure_messenger/services/chat_service.dart';
import '../services/firebase_auth.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService authService = AuthService();
  final ChatService chatService = ChatService();
  final FirebaseAuth auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Chats'),
        elevation: 0,
        actions: [
          // 👤 OMA PROFIILIPILT APP BARIS
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              String? base64Image;
              String userLetter = auth.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U';

              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                base64Image = userData?['profilePicture'];
                if (userData?['username'] != null && userData!['username'].toString().isNotEmpty) {
                  userLetter = userData['username'].toString().substring(0, 1).toUpperCase();
                }
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueGrey[800],
                    // Kui pilt on olemas, dekodeerime Base64 tekstist pildiks, muidu näitame esitähte
                    child: base64Image != null && base64Image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(
                              base64Decode(base64Image),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            userLetter,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 OTSINGUKAST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search contact by email or username...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  onPressed: () {
                    // Avame kaamera skänneri akna
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text('Scan QR Code')),
                          body: MobileScanner(
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                final String scannedEmail = barcodes.first.rawValue!;
                                
                                // Paneme skännitud meili otsingukasti ja sulgeme kaamera
                                setState(() {
                                  _searchController.text = scannedEmail;
                                  _searchQuery = scannedEmail.trim().toLowerCase();
                                });
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const Divider(height: 10, thickness: 0.5),

          // 👥 KASUTAJATE REAALAJAS NIMEKIRI
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong while loading users.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Leiame sisselogitud kasutaja enda andmed, et näha tema suheldud inimeste nimekirja
                final allUsers = snapshot.data ?? [];
                final myUid = auth.currentUser?.uid ?? '';
                final myEmail = auth.currentUser?.email?.toLowerCase() ?? '';
                
                // Otsime andmebaasist enda profiili üles
                final myData = allUsers.firstWhere((u) => u['uid'] == myUid, orElse: () => {});
                final List<dynamic> myActiveChats = myData['chatsWith'] ?? [];

                // Filtreerime nimekirja
                final users = allUsers.where((user) {
                  final userEmail = (user['email'] ?? '').toString().toLowerCase();
                  final username = (user['username'] ?? '').toString().toLowerCase();
                  final userId = user['uid'] ?? '';

                  // 1. Ära näita nimekirjas mind ennast
                  if (userEmail == myEmail) return false;

                  // 2. KUI OTSING ON TÜHI: Näita ainult neid, kelle ID on minu 'chatsWith' listis
                  if (_searchQuery.isEmpty) {
                    return myActiveChats.contains(userId);
                  }

                  // 3. KUI OTSINGUS ON TEKST: Otsi kõigi seast meili järgi
                  return userEmail.contains(_searchQuery) || username.contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty 
                          ? 'No active chats yet.\nSearch above to start a chat!' 
                          : 'No contacts found for "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index];
                    return ListTile(
                      // 👥 TEISE KASUTAJA PROFIILIPILT NIMEKIRJAS
                      leading: Builder(
                        builder: (context) {
                          final String? peerImage = userData['profilePicture'];
                          final String peerEmail = userData['email'] ?? 'U';
                          final String peerUsername = userData['username'] ?? '';
                          
                          // Võtame esitäheks kas kasutajanime või emaili oma
                          final String displayLetter = (peerUsername.isNotEmpty ? peerUsername : peerEmail)
                              .substring(0, 1)
                              .toUpperCase();

                          return CircleAvatar(
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
                          );
                        },
                      ),
                      title: Text(userData['username'] ?? userData['email'],),
                      // 🔴 LUGEMATA SÕNUMITE MÄRGUANNE (TRAILING)
                      trailing: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('unread')
                            .doc(userData['uid']) // Kuulame selle konkreetse kasutaja unread-seisu
                            .snapshots(),
                        builder: (context, unreadSnapshot) {
                          if (unreadSnapshot.hasData && unreadSnapshot.data!.exists) {
                            Map<String, dynamic>? unreadData = unreadSnapshot.data!.data() as Map<String, dynamic>?;
                            int count = unreadData?['count'] ?? 0;

                            // Kui lugemata sõnumeid on rohkem kui 0, kuvame punase täpi numbriga
                            if (count > 0) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.red, // Punane märguande värv
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                          }
                          
                          // Kui lugemata sõnumeid pole, kuvame lihtsalt tavalise halli noolekese
                          return const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey);
                        },
                      ),                      
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverEmail: userData['email'],
                              receiverId: userData['uid'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}