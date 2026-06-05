import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/encryption_service.dart';

class ChatScreen extends StatefulWidget {
  final String receiverEmail;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.receiverEmail,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _editingMessageController =
      TextEditingController();
  final FocusNode _editingMessageFocusNode = FocusNode();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isTyping = false;
  bool _isSecretChat = false;
  bool _isEditingMessage = false;
  bool _editingMessageIsSecret = false;
  String? _editingMessageId;

  String _chatRoomId = "";

  // STIILIELEMENDID / VÄRVID (Saad siin muuta, et pealehega täpselt klapiks)
  static const Color _darkBgColor = Color(0xFF121212); // Ekraani üldine taust
  static const Color _myMessageColor = Color(0xFF6C63FF); // Minu sõnumi mull (Stiilne lilla/sinine)
  static const Color _otherMessageColor = Color(0xFF1E1E1E); // Teise kasutaja mull
  static const Color _secretMessageColor = Color(0xFF00BFA6); // Salajase sõnumi mull (Teemantroheline)

  @override
  void initState() {
    super.initState();

    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, widget.receiverId];
    ids.sort();
    _chatRoomId = ids.join('_');

    _chatService.clearUnreadCount(widget.receiverId);

    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        setState(() => _isTyping = true);
        _chatService.setTypingStatus(widget.receiverId, true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        setState(() => _isTyping = false);
        _chatService.setTypingStatus(widget.receiverId, false);
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
        widget.receiverId,
        _messageController.text,
        _isSecretChat,
      );
      _messageController.clear();
    }
  }

  void _startEditingMessage(
    String messageId,
    String messageText,
    bool isSecret,
  ) {
    _chatService.setTypingStatus(widget.receiverId, false);
    if (_isTyping) {
      setState(() => _isTyping = false);
    }
    setState(() {
      _isEditingMessage = true;
      _editingMessageId = messageId;
      _editingMessageIsSecret = isSecret;
    });
    _editingMessageController.text = messageText;
    _editingMessageController.selection = TextSelection.fromPosition(
      TextPosition(offset: messageText.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _editingMessageFocusNode.requestFocus();
      }
    });
  }

  void _cancelEditing() {
    _chatService.setTypingStatus(widget.receiverId, false);
    if (_isTyping) {
      setState(() => _isTyping = false);
    }
    setState(() {
      _isEditingMessage = false;
      _editingMessageId = null;
      _editingMessageIsSecret = false;
    });
    _editingMessageController.clear();
  }

  Future<void> _saveEditedMessage() async {
    if (_editingMessageId == null || _editingMessageController.text.isEmpty) {
      return;
    }

    await _chatService.editMessage(
      widget.receiverId,
      _editingMessageId!,
      _editingMessageController.text,
      _editingMessageIsSecret,
    );
    _cancelEditing();
  }

  void _markVisibleMessagesAsRead(QuerySnapshot snapshot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final hasUnreadIncomingMessages = snapshot.docs.any((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['senderId'] == widget.receiverId &&
            data['receiverId'] == _auth.currentUser!.uid &&
            data['isRead'] != true;
      });

      if (hasUnreadIncomingMessages) {
        _chatService.markMessagesAsRead(widget.receiverId);
      }
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String timeStr = "$hour:$minute";

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return timeStr;
    } else {
      String day = dateTime.day.toString().padLeft(2, '0');
      String month = dateTime.month.toString().padLeft(2, '0');
      return "$day.$month $timeStr";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBgColor, // Muudame lehe tausta modernselt tumedaks
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Läbipaistev ülariba sulandub taustaga
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.receiverId)
              .snapshots(),
          builder: (context, snapshot) {
            String displayName = widget.receiverEmail;
            String? base64Image;
            String userLetter = widget.receiverEmail.substring(0, 1).toUpperCase();

            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;

              if (userData?['username'] != null &&
                  userData!['username'].toString().isNotEmpty) {
                displayName = userData['username'];
                userLetter = displayName.substring(0, 1).toUpperCase();
              }
              base64Image = userData?['profilePicture'];
            }

            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _myMessageColor.withOpacity(0.2),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Eraldusjoon ülariba alla, mis sobib tumeda teemaga
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          
          // 1. SÕNUMITE NIMEKIRI
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(
                _auth.currentUser!.uid,
                widget.receiverId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.', style: TextStyle(color: Colors.white54)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _myMessageColor));
                }

                if (snapshot.hasData) {
                  _markVisibleMessagesAsRead(snapshot.data!);
                }

                _chatService.clearUnreadCount(widget.receiverId);

                return ListView(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String senderId = data['senderId'] ?? '';
                    bool isMe = senderId == _auth.currentUser!.uid;

                    String messageText = data['message'] ?? '';
                    bool msgIsSecret = data['isSecret'] ?? false;
                    bool msgIsRead = data['isRead'] ?? false;
                    bool msgIsEdited = data['isEdited'] ?? false;
                    bool isEditingThisMessage =
                        isMe && _isEditingMessage && _editingMessageId == doc.id;

                    if (msgIsSecret) {
                      messageText = EncryptionService.decryptText(messageText);
                    }

                    String formattedTime = _formatTimestamp(data['timestamp']);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.receiverId)
                                  .snapshots(),
                              builder: (context, userSnapshot) {
                                String? avatarBytes;
                                String fallbackLetter = widget.receiverEmail.substring(0, 1).toUpperCase();

                                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                  final uData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                  avatarBytes = uData?['profilePicture'];
                                  if (uData?['username'] != null &&
                                      uData!['username'].toString().isNotEmpty) {
                                    fallbackLetter = uData['username'].toString().substring(0, 1).toUpperCase();
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

                          // SÕNUMIMULLI DISAIN (ÜMARAD NURGAD)
                          Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isEditingThisMessage)
                                GestureDetector(
                                  onTap: isMe
                                      ? () => _startEditingMessage(
                                            doc.id,
                                            messageText,
                                            msgIsSecret,
                                          )
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: msgIsSecret
                                          ? _secretMessageColor
                                          : (isMe ? _myMessageColor : _otherMessageColor),
                                      // 🌟 MUUDATUS: Palju ümaramad nurgad, mis kohanduvad vastavalt saatjale
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
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      messageText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                // Muudetava sõnumi kast (sobitatud ümara stiiliga)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _darkBgColor,
                                    border: Border.all(
                                      color: msgIsSecret ? _secretMessageColor : _myMessageColor,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      TextField(
                                        controller: _editingMessageController,
                                        focusNode: _editingMessageFocusNode,
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
                                            onPressed: _cancelEditing,
                                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                          ),
                                          const SizedBox(width: 4),
                                          ElevatedButton(
                                            onPressed: _saveEditedMessage,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: msgIsSecret ? _secretMessageColor : _myMessageColor,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            child: const Text('Save', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 3),

                              // STAATUS JA KELLAAEG
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
                                        color: msgIsRead ? _secretMessageColor : Colors.white24,
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
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // 2. TRÜKKIMISE INDIKAATOR
          StreamBuilder<bool>(
            stream: _chatService.getTypingStatusStream(_chatRoomId, widget.receiverId),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${widget.receiverEmail.split('@')[0]} is typing...",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // 3. SISESTUSALA (Pill / kapsli kujuline, väga voolujooneline)
          SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Luku nupp
                  CircleAvatar(
                    backgroundColor: _isSecretChat 
                        ? _secretMessageColor.withOpacity(0.15) 
                        : Colors.white.withOpacity(0.05),
                    child: IconButton(
                      icon: Icon(
                        _isSecretChat ? Icons.lock : Icons.lock_open_rounded,
                        color: _isSecretChat ? _secretMessageColor : Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSecretChat = !_isSecretChat;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: _isSecretChat ? _secretMessageColor : _otherMessageColor,
                            content: Text(
                              _isSecretChat
                                  ? 'Secret Chat Enabled (End-to-End Encrypted)'
                                  : 'Normal Chat Enabled',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            duration: const Duration(milliseconds: 300),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: EdgeInsets.only(
                              bottom: MediaQuery.of(context).size.height * 0.12,
                              left: 16,
                              right: 16,
                            )
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Ümar tekstikast
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _isSecretChat ? 'Write a secret message...' : 'Write a message...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        fillColor: _otherMessageColor,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        // 🌟 TÄIELIKULT ÜMARAD ÄÄRED TEKSTIKASTILE
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
                            color: _isSecretChat ? _secretMessageColor : _myMessageColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Saatmisnupp ringi sees
                  CircleAvatar(
                    backgroundColor: _isSecretChat ? _secretMessageColor : _myMessageColor,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _editingMessageController.dispose();
    _editingMessageFocusNode.dispose();
    _chatService.clearUnreadCount(widget.receiverId);
    _chatService.setTypingStatus(widget.receiverId, false);
    super.dispose();
  }
}