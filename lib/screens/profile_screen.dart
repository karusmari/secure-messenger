import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  final TextEditingController _usernameController = TextEditingController();
  String _profilePicBase64 = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final String uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      setState(() {
        _usernameController.text = data['username'] ?? "";
        _profilePicBase64 = data['profilePicture'] ?? "";
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 📸 Valime pildi ja muudame selle tekstiks
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30, // Pakime tugevalt kokku, et andmebaasi tekst poleks liiga pikk
    );

    if (image != null) {
      setState(() => _isLoading = true);
      try {
        await _chatService.uploadAndChangeProfilePicture(File(image.path));
        _loadUserData(); // Värskendame ekraani
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _chatService.updateUserProfile(
        _usernameController.text.trim(),
        _profilePicBase64,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 👤 PROFIILIPILT
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[800],
                            // Kui andmebaasis on Base64 tekst olemas, dekodeerime selle pildiks
                            backgroundImage: _profilePicBase64.isNotEmpty
                                ? MemoryImage(base64Decode(_profilePicBase64))
                                : null,
                            child: _profilePicBase64.isEmpty
                                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                : null,
                          ),
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _auth.currentUser!.email ?? "",
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: () {
                        final String qrData = _auth.currentUser?.email ?? "test_user_emulator@test.com";
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: const Text('My QR Code', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Let a friend scan this code to start a secure chat with you.', 
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 20),
                                // Genereerime QR koodi sisse kasutaja e-maili
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(10),
                                  width: 220, // Fikseeritud laius aitab emulaatoril suurust arvutada
                                  height: 220, // Fikseeritud kõrgus
                                  child: QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                    // 🎨 EMULAATORI GRAAFIKA PARANDUS: Sunnime ruudud mustaks
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                    // Kui tekib viga renderdamisel, kuvatakse teksti kujul veateade
                                    errorStateBuilder: (cxt, err) {
                                      return Center(
                                        child: Text(
                                          "QR render error: $err",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.red, fontSize: 12),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close', style: TextStyle(color: Colors.blue)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code, color: Colors.blue),
                      label: const Text('Show My QR Code', style: TextStyle(color: Colors.blue)),
                    ),

                    const SizedBox(height: 20),

                    // 📝 KASUTAJANIMI
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter unique username...',
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 💾 SALVESTAMISE NUPP
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Profile', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}