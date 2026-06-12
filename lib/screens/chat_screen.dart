import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart'; 
import '../services/chat_service.dart';
import '../services/encryption_service.dart';
import 'user_profile_screen.dart';
import '../widgets/chat_dialogs.dart';
import '../utils/date_formatter.dart';

import '../widgets/chat_input_area.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

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
  final TextEditingController _editingMessageController = TextEditingController();
  final FocusNode _editingMessageFocusNode = FocusNode();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isTyping = false;
  bool _isSecretChat = false;
  bool _isEditingMessage = false;
  bool _editingMessageIsSecret = false;
  String? _editingMessageId;
  String _chatRoomId = "";

  // Styling elements
  static const Color _darkBgColor = Color(0xFF121212);
  static const Color _myMessageColor = Color(0xFF6C63FF);
  static const Color _otherMessageColor = Color.fromARGB(255, 73, 73, 73);
  static const Color _secretMessageColor = Color(0xFF00BFA6);

  @override
  void initState() {
    super.initState();
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, widget.receiverId];
    ids.sort();
    _chatRoomId = ids.join('_');

    // Clear unread message count when entering the chat
    _chatService.clearUnreadCount(widget.receiverId);

    // Listener to update typing status in real-time
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) { // User starts typing
        setState(() => _isTyping = true);
        _chatService.setTypingStatus(widget.receiverId, true);
      } else if (_messageController.text.isEmpty && _isTyping) { // User deletes text or sends message
        setState(() => _isTyping = false);
        _chatService.setTypingStatus(widget.receiverId, false);
      }
    });
  }

  // Sends a standard text message
  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) { // Only send if there's text in the input
      await _chatService.sendMessage(
        widget.receiverId,
        _messageController.text,
        _isSecretChat,
      );
      _messageController.clear();
    }
  }

  // Initializes the editing mode for a specific message
  void _startEditingMessage(
    String messageId,
    String messageText,
    bool isSecret,
  ) {
    _chatService.setTypingStatus(widget.receiverId, false);
    if (_isTyping) setState(() => _isTyping = false);

    setState(() {
      _isEditingMessage = true;
      _editingMessageId = messageId;
      _editingMessageIsSecret = isSecret;
    });

    _editingMessageController.text = messageText;
    _editingMessageController.selection = TextSelection.fromPosition(
      TextPosition(offset: messageText.length),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _editingMessageFocusNode.requestFocus();
      }
    });
  }

  // Cancels the current message editing state
  void _cancelEditing() {
    _chatService.setTypingStatus(widget.receiverId, false);
    if (_isTyping) setState(() => _isTyping = false);

    setState(() {
      _isEditingMessage = false;
      _editingMessageId = null;
      _editingMessageIsSecret = false;
    });

    _editingMessageController.clear();
  }

  // Saves the edited message text back to Firestore
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

  // Marks all currently loaded incoming messages as read
  void _markVisibleMessagesAsRead(QuerySnapshot snapshot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  // Handles selection of media files (image, video, audio) and uploads them as Base64 strings
  Future<void> _handleMediaSelection(String type) async {
    try {
      File? file;

      if (type == 'audio') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
        );
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      } else {
        final ImagePicker picker = ImagePicker();
        XFile? pickedFile;

        if (type == 'image') {
          // Restricting image dimensions and quality to avoid large Base64 payload issues in Firestore
          pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 800, 
            maxHeight: 800, 
            imageQuality: 70, // Compresses image to 70% quality
          );
        } else if (type == 'video') {
          pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        }

        if (pickedFile != null) {
          file = File(pickedFile.path);
        }
      }

      // Automatically triggers media processing, Base64 conversion, and sends to Firestore
      if (file != null) {
        await _chatService.sendMediaMessage(
          widget.receiverId,
          file,
          type,
          _isSecretChat,
        );

        debugPrint(
          "Media ($type) sent successfully to Firestore as a Base64 string!",
        );
      }
    } catch (e) {
      debugPrint("Error sending media: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send media: $e')));
      }
    }
  }

  // Triggers a confirmation dialog box before deleting a selected message
  void _confirmDeleteMessage(String messageId) async {
    final bool? confirmed = await ChatDialogs.showDeleteConfirmation(context);

    if (confirmed == true) {
      try {
        await _chatService.deleteMessage(widget.receiverId, messageId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              duration: Duration(milliseconds: 800),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete message: $e')),
          );
        }
      }
    }
  }

  // Opens up the action bottom sheet menu containing editing and deleting configurations
  void _showOptionsBottomSheet(
    BuildContext context,
    String messageId,
    String messageText,
    bool isSecret,
  ) {
    ChatDialogs.showOptionsBottomSheet(
      context: context,
      messageId: messageId,
      messageText: messageText,
      isSecret: isSecret,
      backgroundColor: _otherMessageColor,
      onEditTap: _startEditingMessage,
      onDeleteTap: _confirmDeleteMessage,
    );
  }

  // Toggles secret end-to-end encryption mode state and pushes a responsive UI notification SnackBar
  void _handleSecretChatToggle() {
    setState(() => _isSecretChat = !_isSecretChat);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isSecretChat ? _secretMessageColor : _otherMessageColor,
        content: Text(
          _isSecretChat
              ? 'Secret Chat Enabled (End-to-End Encrypted)'
              : 'Normal Chat Enabled',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(milliseconds: 300),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.12,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  // Builds a responsive dynamic AppBar containing receiver credentials, profile handling, and actions
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
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

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: widget.receiverId,
                    userEmail: widget.receiverEmail,
                    isAlreadyFriend: true,
                  ),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
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
            ),
          );
        },
      ),
    );
  }

  // Sub-widget: Assembles the interactive ListView and handles real-time streams
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(
        _auth.currentUser!.uid,
        widget.receiverId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading messages.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _myMessageColor),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        // Handle operational unread configurations safely inside data callbacks
        _markVisibleMessagesAsRead(snapshot.data!);
        _chatService.clearUnreadCount(widget.receiverId);

        final docs = snapshot.data!.docs;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            String senderId = data['senderId'] ?? '';
            bool isMe = senderId == _auth.currentUser!.uid;
            String messageText = data['message'] ?? '';
            bool msgIsSecret = data['isSecret'] ?? false;

            // Handle decryption routine locally if End-to-End Encryption flag is validated
            if (msgIsSecret && messageText.isNotEmpty) {
              try {
                messageText = EncryptionService.decryptText(messageText);
              } catch (e) {
                messageText = "Failed to decrypt message";
              }
            }

            return MessageBubble(
              data: data,
              messageId: doc.id,
              messageText: messageText,
              isMe: isMe,
              receiverId: widget.receiverId,
              receiverEmail: widget.receiverEmail,
              formattedTime: DateFormatter.formatTimestamp(data['timestamp']),
              isEditingThisMessage:
                  isMe &&
                  _isEditingMessage &&
                  _editingMessageId == doc.id,
              onStartEditing: _startEditingMessage,
              onShowOptions: _showOptionsBottomSheet,
              onCancelEditing: _cancelEditing,
              onSaveEditedMessage: _saveEditedMessage,
              editingController: _editingMessageController,
              editingFocusNode: _editingMessageFocusNode,
              myMessageColor: _myMessageColor,
              otherMessageColor: _otherMessageColor,
              secretMessageColor: _secretMessageColor,
              darkBgColor: _darkBgColor,
            );
          },
        );
      },
    );
  }

  // Sub-widget: Decoupled typing indicator listening directly to targeted snapshot streams
  Widget _buildTypingIndicator() {
    return StreamBuilder<bool>(
      stream: _chatService.getTypingStatusStream(
        _chatRoomId,
        widget.receiverId,
      ),
      builder: (context, snapshot) => TypingIndicator.build(
        receiverEmail: widget.receiverEmail,
        isTyping: snapshot.data == true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBgColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Container(height: 1, color: Colors.white.withOpacity(0.05)),

          // Live Chat Conversation Feed
          Expanded(child: _buildMessageList()),

          // Typing Notification State Handler
          _buildTypingIndicator(),

          // User Input, Action Panels and Attachments Management Engine
          ChatInputArea(
            controller: _messageController,
            isSecretChat: _isSecretChat,
            onToggleSecret: _handleSecretChatToggle,
            onSendMessage: _sendMessage,
            onMediaSelected: _handleMediaSelection,
            myMessageColor: _myMessageColor,
            otherMessageColor: _otherMessageColor,
            secretMessageColor: _secretMessageColor,
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