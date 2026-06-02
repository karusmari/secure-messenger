import 'package:flutter/material.dart';
import 'package:secure_messenger/services/chat_service.dart';
import '../services/firebase_auth.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final ChatService chatService = ChatService();
    final FirebaseAuth auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 Secure Chats'),
        actions: [
          // Väljalogimise nupp
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chatService.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong while loading users.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtreerime nimekirjast välja iseenda, et me endaga rääkida ei saaks
          final users = snapshot.data!
              .where((user) => user['email'] != auth.currentUser?.email)
              .toList();

          if (users.isEmpty) {
            return const Center(child: Text('No other users found.'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(userData['email']),
                trailing: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                onTap: () {
                  // Viime kasutaja otse spetsiaalsesse vestlusaknasse
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
    );
  }
}