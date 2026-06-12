import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_auth.dart'; 
import '../widgets/qr_scan_button.dart';   
import '../widgets/user_tile.dart';
import '../services/profile_service.dart';         
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    // Listening to search input mutations cleanly
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  // Component: Actions and user configuration inside the AppBar layout
  PreferredSizeWidget _buildAppBar() {
    final String currentUid = _auth.currentUser?.uid ?? '';
    
    return AppBar(
      title: const Text('Secure Messenger'),
      elevation: 0,
      actions: [
        // Widget to start scanning QR codes and adding a new chat
        QrScanButton(),
        
        // Dynamic User Profile Avatar Stream Container
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
          builder: (context, snapshot) {
            String? base64Image;
            String userLetter = _auth.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U';

            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              base64Image = userData?['profilePicture'];
              if (userData?['username'] != null && userData!['username'].toString().trim().isNotEmpty) {
                userLetter = userData['username'].toString().substring(0, 1).toUpperCase();
              }
            }

            return GestureDetector(
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueGrey[800],
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
                      : Text(userLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _authService.signOut(),
        ),
      ],
    );
  }

  // Component: Search configuration filtering input element
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: TextField(
        controller: _searchController,
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
    );
  }

  // Component: Main list processor extracting relational database configurations
  Widget _buildUserList() {
    final String myUid = _auth.currentUser?.uid ?? '';
    final String myEmail = _auth.currentUser?.email?.toLowerCase() ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _profileService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Something went wrong.'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final allUsers = snapshot.data ?? [];
        
        // Safely map internal references to isolate local host payload configuration
        final myData = allUsers.firstWhere((u) => u['uid'] == myUid, orElse: () => {});
        final List<dynamic> myActiveChats = myData['chatsWith'] ?? [];

        // Apply functional filters securely based on search state queries
        final filteredUsers = allUsers.where((user) {
          final userEmail = (user['email'] ?? '').toString().toLowerCase();
          final username = (user['username'] ?? '').toString().toLowerCase();
          final userId = user['uid'] ?? '';

          if (userEmail == myEmail) return false; // Exclude current user from the list
          if (_searchQuery.isEmpty) return myActiveChats.contains(userId); // Show active chats only
          
          return userEmail.contains(_searchQuery) || username.contains(_searchQuery);
        }).toList();

        if (filteredUsers.isEmpty) {
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
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            return UserTile(userData: filteredUsers[index]); 
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search Bar Interface Widget Component
          _buildSearchBar(),
          const Divider(height: 10, thickness: 0.5),

          // Real-time Reactive Chat / Contact Directory Feed List
          Expanded(child: _buildUserList()),
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