import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/contact_service.dart'; 
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final bool isAlreadyFriend; 

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.isAlreadyFriend,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ContactService _contactService = ContactService();
  bool _isLoading = false;

  void _addAndStartChat() async {
    setState(() => _isLoading = true);
    
    // adding chat into database
    String result = await _contactService.addChatByEmail(widget.userEmail);
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    // letting the user know about the process result (success or failure)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));

    // navigating the user to the chat screen if the chat was created successfully
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverEmail: widget.userEmail,
          receiverId: widget.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User not found", style: TextStyle(color: Colors.white)));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          String username = userData['username'] ?? 'No username set';
          String realEmail = userData['email'] ?? 'No email found'; 
          String? base64Image = userData['profilePicture'];
          String userLetter = widget.userEmail.substring(0, 1).toUpperCase();

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // profile picture 
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[800],
                    child: base64Image != null && base64Image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.memory(base64Decode(base64Image), width: 120, height: 120, fit: BoxFit.cover),
                          )
                        : Text(userLetter, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),

                  // username
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // email
                  Text(
                    realEmail,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // dynamic button: if we are not friends yet, we show the "Add to Contacts & Chat" button, 
                  // otherwise we show the "Back to Chat" button
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else if (!widget.isAlreadyFriend)
                    // in case we are not friends yet
                    ElevatedButton.icon(
                      onPressed: _addAndStartChat,
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text("Add to Contacts & Chat", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  else
                    // in case we are already friends, we just show a button to go back to the chat
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context), 
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text("Back to Chat", style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}