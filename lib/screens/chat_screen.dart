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
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isTyping = false;
  bool _isSecretChat = false;

  String _chatRoomId = "";

  @override
  void initState() {
    super.initState();

    // 1. Genereerime unikaalse jututoa ID (et teada, millist tuba jälgida)
    final String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, widget.receiverId];
    ids.sort();
    _chatRoomId = ids.join('_');

    // 2. 🔕 NULLIME LUGEMATA SÕNUMID: Kui sisenen vestlusse, märgib äpp sõnumid loetuks
    _chatService.clearUnreadCount(widget.receiverId);

    // 3. ✍️ TRÜKKIMISE KUULAJA: Kontrollib reaalajas, kas mina trükin tekstikasti midagi
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
      // Saadame kaasa ka info, kas see sõnum on salajane või mitte
      await _chatService.sendMessage(
        widget.receiverId, 
        _messageController.text,
        _isSecretChat, 
      );
      _messageController.clear(); // Teeme kasti pärast saatmist tühjaks
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String timeStr = "$hour:$minute";

    // Kui sõnum saadeti täna, näitame ainult kellaaega
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return timeStr;
    } else {
      // Kui on vanem sõnum, näitame ka kuupäeva
      String day = dateTime.day.toString().padLeft(2, '0');
      String month = dateTime.month.toString().padLeft(2, '0');
      return "$day.$month $timeStr";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0, // Kaotame tühimiku, et pilt ja nimi oleksid ilusti koos
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.receiverId) // Kuulame reaalajas selle kasutaja andmeid
              .snapshots(),
          builder: (context, snapshot) {
            String displayName = widget.receiverEmail; // Vaikimisi email
            String? base64Image;
            String userLetter = widget.receiverEmail.substring(0, 1).toUpperCase();

            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              
              // Kui tal on kasutajanimi, võtame selle
              if (userData?['username'] != null && userData!['username'].toString().isNotEmpty) {
                displayName = userData['username'];
                userLetter = displayName.substring(0, 1).toUpperCase();
              }
              // Võtame profiilipildi
              base64Image = userData?['profilePicture'];
            }

            return Row(
              children: [
                // 👥 TEISE KASUTAJA AVATAR VESTLUSE ÜLAL RIBAS
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue[700],
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
                
                const SizedBox(width: 12), // Vahemaa pildi ja nime vahel
                
                // KASUTAJA NIMI / EMAIL
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis, // Kui on liiga pikk nimi, tõmbab kolm täppi (...)
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // 1. SÕNUMITE NIMEKIRI (Reaalajas striim andmebaasist)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(_auth.currentUser!.uid, widget.receiverId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // nullime lugemata sõnumite arvu, kui kasutaja avab vestluse
                _chatService.clearUnreadCount(widget.receiverId);

                // Kuvame sõnumid nimekirjana
                return ListView(
                  reverse:true, // Et uusimad sõnumid oleksid all ja vanemad üles
                  padding: const EdgeInsets.all(16),
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String senderId = data['senderId'] ?? '';
                    bool isMe = senderId == _auth.currentUser!.uid;
                    
                    // Küsime andmebaasist teksti ja kontrollime krüpteeritust
                    String messageText = data['message'] ?? '';
                    bool msgIsSecret = data['isSecret'] ?? false;

                    // 🔓 KUI SÕNUM ON SALAJANE, DEKRÜPTEERIME SELLE KASUTAJA JAOKS
                    if (msgIsSecret) {
                      messageText = EncryptionService.decryptText(messageText);
                    }

                    String formattedTime = _formatTimestamp(data['timestamp']);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end, // Joondab avatari mulli alläärega
                        children: [
                          // 👥 TEISE KASUTAJA AVATAR SÕNUMI KÕRVAL (Kuvatakse ainult vasakpoolsetel sõnumitel)
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
                                  if (uData?['username'] != null && uData!['username'].toString().isNotEmpty) {
                                    fallbackLetter = uData['username'].toString().substring(0, 1).toUpperCase();
                                  }
                                }

                                return CircleAvatar(
                                  radius: 15, // Puhas ja kompaktne suurus vestluse sisse
                                  backgroundColor: Colors.blueGrey[800],
                                  child: avatarBytes != null && avatarBytes.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Image.memory(
                                            base64Decode(avatarBytes),
                                            width: 30,
                                            height: 30,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Text(
                                          fallbackLetter,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                );
                              },
                            ),
                            const SizedBox(width: 8), // Vahemaa avatari ja sõnumimulli vahel
                          ],

                          // SÕNUMIMULL + KELLAAEG KAUSTAS
                          Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.65, // Piirame laiust, et ei valguks üle ekraani
                                ),
                                decoration: BoxDecoration(
                                  color: msgIsSecret 
                                      ? Colors.green[700] 
                                      : (isMe ? Colors.blue[600] : Colors.grey[800]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 0),  // Kurv lõpeb teravalt vastavalt saatjale
                                    bottomRight: Radius.circular(isMe ? 0 : 16),
                                  ),
                                ),
                                child: Text(
                                  messageText,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                ),
                              ),

                              const SizedBox(height: 2),

                              // 🕒 KELLAAEG JA KUUPÄEV TEKSTI ALL
                              Padding(
                                padding: EdgeInsets.only(
                                  left: isMe ? 0 : 4,
                                  right: isMe ? 4 : 0,
                                ),
                                child: Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                  ),
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

          // 🔥 2. UUS OSA: TRÜKKIMISE INDIKAATOR (Kuvatakse täpselt sisestuskasti kohal)
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
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[500], fontSize: 13),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // 2. SÕNUMI SISSEKANDE VÄLI (Luku nupp + Tekstikast + Saatmise nupp)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 🔒 TABALUKU NUPP: Lülitab salajase vestluse sisse/välja
                IconButton(
                  icon: Icon(
                    _isSecretChat ? Icons.lock : Icons.lock_open,
                    color: _isSecretChat ? Colors.green : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSecretChat = !_isSecretChat;
                    });
                    
                    // Teavitame kasutajat režiimi muutusest väikese ribaga ekraani all
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isSecretChat 
                            ? 'Secret Chat Enabled (Messages will be encrypted)' 
                            : 'Normal Chat Enabled'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isSecretChat ? 'Write a secret message...' : 'Write a message...',
                      border: const OutlineInputBorder(),
                      // Kui salajane vestlus on sees, muudame tekstikasti ääre roheliseks
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _isSecretChat ? Colors.green : Colors.blue,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send, 
                    color: _isSecretChat ? Colors.green : Colors.blue
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatService.clearUnreadCount(widget.receiverId); // Ja nullin lugemata sõnumite arvu, kui lahkun vestlusest
    _chatService.setTypingStatus(widget.receiverId, false); // Kui lahkun vestlusest, lülitan trükkimise välja
    _messageController.dispose();
    super.dispose();
  }

  
}