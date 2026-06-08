import 'package:flutter/material.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isSecretChat;
  final VoidCallback onToggleSecret;
  final VoidCallback onSendMessage;
  final Color myMessageColor;
  final Color otherMessageColor;
  final Color secretMessageColor;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isSecretChat,
    required this.onToggleSecret,
    required this.onSendMessage,
    required this.myMessageColor,
    required this.otherMessageColor,
    required this.secretMessageColor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Luku nupp
            CircleAvatar(
              backgroundColor: isSecretChat
                  ? secretMessageColor.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              child: IconButton(
                icon: Icon(
                  isSecretChat ? Icons.lock : Icons.lock_open_rounded,
                  color: isSecretChat ? secretMessageColor : Colors.white54,
                ),
                onPressed: onToggleSecret,
              ),
            ),
            const SizedBox(width: 8),

            // Ümar tekstikast
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: isSecretChat ? 'Write a secret message...' : 'Write a message...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  fillColor: otherMessageColor,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(
                      color: isSecretChat ? secretMessageColor : myMessageColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Saatmisnupp ringi sees
            CircleAvatar(
              backgroundColor: isSecretChat ? secretMessageColor : myMessageColor,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: onSendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}