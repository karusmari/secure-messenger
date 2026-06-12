import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secure_messenger/services/encryption_service.dart';
import 'video_bubble.dart';
import 'audio_bubble.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final String messageId;
  final String messageText;
  final bool isMe;
  final String receiverId;
  final String receiverEmail;
  final String formattedTime;
  final bool isEditingThisMessage;

  final Function(String id, String text, bool secret) onStartEditing;
  final Function(BuildContext ctx, String id, String text, bool secret) onShowOptions;
  final VoidCallback onCancelEditing;
  final VoidCallback onSaveEditedMessage;

  final TextEditingController editingController;
  final FocusNode editingFocusNode;

  final Color myMessageColor;
  final Color otherMessageColor;
  final Color secretMessageColor;
  final Color darkBgColor;

  const MessageBubble({
    super.key,
    required this.data,
    required this.messageId,
    required this.messageText,
    required this.isMe,
    required this.receiverId,
    required this.receiverEmail,
    required this.formattedTime,
    required this.isEditingThisMessage,
    required this.onStartEditing,
    required this.onShowOptions,
    required this.onCancelEditing,
    required this.onSaveEditedMessage,
    required this.editingController,
    required this.editingFocusNode,
    required this.myMessageColor,
    required this.otherMessageColor,
    required this.secretMessageColor,
    required this.darkBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final msgIsSecret = data['isSecret'] ?? false;
    final messageType = data['messageType'] ?? 'text';
    final maxWidth = MediaQuery.of(context).size.width * 0.7;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // User Avatar: Rendered only for the incoming messages (other user)
          if (!isMe) ...[
            _AvatarWidget(receiverId: receiverId, receiverEmail: receiverEmail),
            const SizedBox(width: 8),
          ],

          // Message Column: Contains the bubble container and metadata layout
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isEditingThisMessage)
                GestureDetector(
                  // Enable inline editing on tap for sender's text messages only
                  onTap: isMe && messageType == 'text'
                      ? () => onStartEditing(messageId, messageText, msgIsSecret)
                      : null,
                  // Show option sheet (Edit/Delete actions) on long press for sender's messages
                  onLongPress: isMe
                      ? () => onShowOptions(context, messageId, messageText, msgIsSecret)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: messageType == 'image' 
                        ? const EdgeInsets.all(4) 
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    decoration: BoxDecoration(
                      color: msgIsSecret
                          ? secretMessageColor
                          : (isMe ? myMessageColor : otherMessageColor),
                      borderRadius: _getBubbleRadius(),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(),
                  ),
                )
              else
                // Message Editor State: Rendered when the inline editing flag is active
                _buildMessageEditor(maxWidth, msgIsSecret),
              
              const SizedBox(height: 2),
              
              // Metadata Row: Contains timestamps, delivery ticks, and edit indicators
              _buildMessageMeta(msgIsSecret),
            ],
          ),
        ],
      ),
    );
  }

  // HELPER METHODS FOR CONTENT RENDERING

  // Calculates dynamic border radius configuration based on the message sender
  BorderRadius _getBubbleRadius() {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );
  }

  // Dispatches rendering logic dynamically based on the stored attachment type
  Widget _buildMessageContent() {
    final String messageType = data['messageType'] ?? data['type'] ?? 'text'; 
    final bool msgIsSecret = data['isSecret'] ?? false;

    if (messageType == 'image') {
      return _buildImageContent(msgIsSecret);
    } else if (messageType == 'audio') {
      return AudioBubble(data: data, msgIsSecret: msgIsSecret, isMe: isMe);
    } else if (messageType == 'video') {
      return VideoBubble(data: data, msgIsSecret: msgIsSecret);
    }

    return Text(
      messageText,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.25),
    );
  }

  // Handles Base64 image decoding, on-the-fly decryption, and error state placeholders
  Widget _buildImageContent(bool msgIsSecret) {
    String rawImageBase64 = data['message'] ?? '';

    // Attempt cryptographic decryption if the payload is flagged as secret
    if (msgIsSecret && rawImageBase64.isNotEmpty) {
      try {
        rawImageBase64 = EncryptionService.decryptText(rawImageBase64);
      } catch (e) {
        return const _ErrorPlaceholder(text: 'Failed to decrypt image');
      }
    }

    if (rawImageBase64.isEmpty) {
      return const _ErrorPlaceholder(text: 'Empty image data');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        base64Decode(rawImageBase64),
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _ErrorPlaceholder(text: 'Error loading image', isBroken: true),
      ),
    );
  }

  // Renders the input control interface for structural inline message editing
  Widget _buildMessageEditor(double maxWidth, bool msgIsSecret) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: darkBgColor,
        border: Border.all(
          color: msgIsSecret ? secretMessageColor : myMessageColor,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: editingController,
            focusNode: editingFocusNode,
            autofocus: true,
            maxLines: null,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onCancelEditing,
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: onSaveEditedMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: msgIsSecret ? secretMessageColor : myMessageColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Constructs the tracking metadata layout (Timestamps, read receipts, and edited indicators)
  Widget _buildMessageMeta(bool msgIsSecret) {
    final msgIsRead = data['isRead'] ?? false;
    final msgIsEdited = data['isEdited'] ?? false;

    return Padding(
      padding: EdgeInsets.only(left: isMe ? 0 : 4, right: isMe ? 4 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formattedTime,
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              msgIsRead ? Icons.done_all : Icons.done,
              size: 12,
              color: msgIsRead ? secretMessageColor : Colors.white24,
            ),
          ],
          if (msgIsEdited) ...[
            const SizedBox(width: 6),
            Text(
              '• Edited',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// SUB-WIDGETS

// Handles isolated async stream connection to render the specific contact profile picture
class _AvatarWidget extends StatelessWidget {
  final String receiverId;
  final String receiverEmail;

  const _AvatarWidget({required this.receiverId, required this.receiverEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(receiverId).snapshots(),
      builder: (context, userSnapshot) {
        String fallbackLetter = receiverEmail.substring(0, 1).toUpperCase();
        String? avatarBytes;

        // Extract fresh username data and profile photo records if doc snapshots exist
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final uData = userSnapshot.data!.data() as Map<String, dynamic>?;
          avatarBytes = uData?['profilePicture'];
          if (uData?['username'] != null && uData!['username'].toString().isNotEmpty) {
            fallbackLetter = uData['username'].toString().substring(0, 1).toUpperCase();
          }
        }

        return CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white.withOpacity(0.08),
          child: avatarBytes != null && avatarBytes.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    base64Decode(avatarBytes),
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                )
              : Text(
                  fallbackLetter,
                  style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                ),
        );
      },
    );
  }
}

// Unified state representation widget to handle asset errors or cryptographic parsing blocks smoothly
class _ErrorPlaceholder extends StatelessWidget {
  final String text;
  final bool isBroken;

  const _ErrorPlaceholder({required this.text, this.isBroken = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBroken ? Icons.broken_image : Icons.lock_outline, color: Colors.white60, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}