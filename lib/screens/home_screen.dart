import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:secure_messenger/services/chat_service.dart';
import '../services/firebase_auth.dart'; 
import '../widgets/qr_scan_button.dart';   
import '../widgets/user_tile.dart';         
import 'profile_screen.dart';

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
          // 🌟 UUS VIDIN: Teeb kogu skännimise ja kasutaja lisamise töö ise ära
          QrScanButton(),
          
          // Oma profiilipilt
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).snapshots(),
            builder: (context, snapshot) {
              String? base64Image;
              String userLetter = auth.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U';

              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                base64Image = userData?['profilePicture'];
                if (userData?['username'] != null && userData!['username'].toString().trim().isNotEmpty) {
                  userLetter = userData['username'].toString().substring(0, 1).toUpperCase();
                }
              }

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueGrey[800],
                    child: base64Image != null && base64Image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(base64Decode(base64Image), width: 36, height: 36, fit: BoxFit.cover),
                          )
                        : Text(userLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          // Otsingukast
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search contact...',
                hintStyle: const TextStyle(color: Color(0xFF697565), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF697565), size: 20),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface, 
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ), 
          ),
          const Divider(height: 10, thickness: 0.5),

          // Kasutajate reaalaegne nimekiri
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Something went wrong.'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final allUsers = snapshot.data ?? [];
                final myUid = auth.currentUser?.uid ?? '';
                final myEmail = auth.currentUser?.email?.toLowerCase() ?? '';
                
                final myData = allUsers.firstWhere((u) => u['uid'] == myUid, orElse: () => {});
                final List<dynamic> myActiveChats = myData['chatsWith'] ?? [];

                final users = allUsers.where((user) {
                  final userEmail = (user['email'] ?? '').toString().toLowerCase();
                  final username = (user['username'] ?? '').toString().toLowerCase();
                  final userId = user['uid'] ?? '';

                  if (userEmail == myEmail) return false;
                  if (_searchQuery.isEmpty) return myActiveChats.contains(userId);
                  return userEmail.contains(_searchQuery) || username.contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No active chats yet.\nSearch above to start a chat!' : 'No contacts found for "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return UserTile(userData: users[index]); 
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