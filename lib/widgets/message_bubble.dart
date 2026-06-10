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

  // Funktsioonid, mida käivitatakse ema-vidinas (ChatScreen)
  final Function(String id, String text, bool secret) onStartEditing;
  final Function(BuildContext ctx, String id, String text, bool secret)
  onShowOptions;
  final VoidCallback onCancelEditing;
  final VoidCallback onSaveEditedMessage;

  // Kontrollerid muutmiseks
  final TextEditingController editingController;
  final FocusNode editingFocusNode;

  // Värvid
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

  // UUS ABIFUNKTSIOON: See otsustab, mida mullikese sees kuvada
  Widget _buildMessageContent() {
    String messageType = data['messageType'] ?? data['type'] ?? 'text'; // Kontrollib mõlemat võimalikku välja
    bool msgIsSecret = data['isSecret'] ?? false;

    // Logime tüübi kontrolliks konsooli
    debugPrint("Bubble ID: $messageId, Type: $messageType");

    // 1. KONTROLL: Pildisõnum
    if (messageType == 'image') {
      String rawImageBase64 = data['message'] ?? '';

      // Kui see oli Secret Chat pilt, peame selle esmalt dekrüpteerima
      if (msgIsSecret && rawImageBase64.isNotEmpty) {
        try {
          rawImageBase64 = EncryptionService.decryptText(rawImageBase64);
        } catch (e) {
          debugPrint("Error decrypting image: $e");
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Failed to decrypt image',
              style: TextStyle(color: Colors.white60),
            ),
          );
        }
      }

      // Kui allikas on millegipärast tühi
      if (rawImageBase64.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Empty image data',
            style: TextStyle(color: Colors.white60),
          ),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(rawImageBase64),
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("Error loading image: $error");
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white60),
                  SizedBox(width: 8),
                  Text(
                    'Error loading image',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } 
    
    // 2. KONTROLL: Helisõnum
    else if (messageType == 'audio') {
      return AudioBubble(
        data: data,
        msgIsSecret: msgIsSecret,
        isMe: isMe,
      );
    }
    
    // 3. KONTROLL: Videosõnum
    else if (messageType == 'video') {
      // Kutsume välja uue puhta vidina teises failis!
      return VideoBubble(
        data: data,
        msgIsSecret: msgIsSecret,
      );
    }

    // 4. LÕPPHINDAMINE: Kui tüüp on 'text' või midagi tundmatut, tagastame alati tekstividina.
    // See rida peab asuma täiesti viimastest if-idest VÄLJASPOOL, tagades et funktsioon tagastab ALATI widgeti.
    return Text(
      messageText,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool msgIsSecret = data['isSecret'] ?? false;
    bool msgIsRead = data['isRead'] ?? false;
    bool msgIsEdited = data['isEdited'] ?? false;
    String messageType = data['messageType'] ?? 'text';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(receiverId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                String? avatarBytes;
                String fallbackLetter = receiverEmail
                    .substring(0, 1)
                    .toUpperCase();

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final uData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  avatarBytes = uData?['profilePicture'];
                  if (uData?['username'] != null &&
                      uData!['username'].toString().isNotEmpty) {
                    fallbackLetter = uData['username']
                        .toString()
                        .substring(0, 1)
                        .toUpperCase();
                  }
                }

                return CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withOpacity(0.1),
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
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],

          Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isEditingThisMessage)
                GestureDetector(
                  // PARANDUS: Lubame tekstimuutmist lühikese vajutusega AINULT siis, kui tegu on tekstisõnumiga
                  onTap: isMe && messageType == 'text'
                      ? () =>
                            onStartEditing(messageId, messageText, msgIsSecret)
                      : null,
                  // Pika vajutuse valikud (kustutamine jne) töötavad ikka kõigil
                  onLongPress: isMe
                      ? () => onShowOptions(
                          context,
                          messageId,
                          messageText,
                          msgIsSecret,
                        )
                      : null,
                  child: Container(
                    padding: messageType == 'image'
                        ? const EdgeInsets.all(
                            4,
                          ) // Pildi ümber teeme väiksema ääre, et pilt täidaks mulli paremini
                        : const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: msgIsSecret
                          ? secretMessageColor
                          : (isMe ? myMessageColor : otherMessageColor),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    // KUTSUTAKSE UUT FUNKTSIOONI TEKSTI ASYMEL
                    child: _buildMessageContent(),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: darkBgColor,
                    border: Border.all(
                      color: msgIsSecret ? secretMessageColor : myMessageColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: editingController,
                        focusNode: editingFocusNode,
                        autofocus: true,
                        maxLines: null,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
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
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: onSaveEditedMessage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: msgIsSecret
                                  ? secretMessageColor
                                  : myMessageColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 3),
              Padding(
                padding: EdgeInsets.only(
                  left: isMe ? 0 : 6,
                  right: isMe ? 6 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedTime,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                      ),
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
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
