import 'package:flutter/material.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isSecretChat;
  final VoidCallback onToggleSecret;
  final VoidCallback onSendMessage;
  
  final Function(String type) onMediaSelected; 

  final Color myMessageColor;
  final Color otherMessageColor;
  final Color secretMessageColor;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isSecretChat,
    required this.onToggleSecret,
    required this.onSendMessage,
    required this.onMediaSelected, 
    required this.myMessageColor,
    required this.otherMessageColor,
    required this.secretMessageColor,
  });

  // attachment menu for selecting media type (image, video, audio)
  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: otherMessageColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.white70),
                title: const Text('Send Image', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  onMediaSelected('image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_collection, color: Colors.white70),
                title: const Text('Send Video', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  onMediaSelected('video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack, color: Colors.white70),
                title: const Text('Send Audio', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  onMediaSelected('audio');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // key icon to toggle secret chat mode
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

            // text input field with attachment button inside
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
                  
                  // attachment icon inside the text field
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Colors.white54),
                    onPressed: () => _showAttachmentMenu(context),
                  ),

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

            // Send button
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