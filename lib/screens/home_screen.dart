import 'package:flutter/material.dart';
import '../services/firebase_auth.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 Secure Chats'),
        actions: [
          // Väljalogimise nupp
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
            tooltip: 'Log out',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 3, // Esialgu teeme 3 ajutist vestlust näidiseks
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Text('${index + 1}'),
            ),
            title: Text('User ${index + 1}'),
            subtitle: const Text('This is a secure private message...'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              // Siit hakkame tulevikus avama konkreetset vestlusakent!
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open the chat with User ${index + 1}')),
              );
            },
          );
        },
      ),
    );
  }
}