import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();

  final TextEditingController _usernameController = TextEditingController();
  String _profilePicBase64 = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Fetches the authenticated user's remote configuration records from Firestore
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

  // Opens the system gallery to pick, compress, and update the user profile picture
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30, // Compress image quality to maintain light Firestore payloads
    );

    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      await _profileService.uploadAndChangeProfilePicture(File(image.path));
      _loadUserData(); // Reload state context to fetch the fresh Base64 string
      
      if (!context.mounted) return;
      _showSnackBar(context, 'Profile picture updated successfully!', isError: false);
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Error updating image: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // Commits modifications made to the user profile text fields down to the database
  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _profileService.updateUserProfile(
        _usernameController.text.trim(),
        _profilePicBase64,
      );
      if (!context.mounted) return;
      _showSnackBar(context, 'Username updated successfully!', isError: false);
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Error updating profile: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  // UI DIALOG TRIGGERS

  // Displays an alert window generating a unique user identification QR key
  void _showQrCodeDialog(BuildContext context) {
    final String qrData = _auth.currentUser?.email ?? "test_user_emulator@test.com";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'My QR Code', 
          textAlign: TextAlign.center, 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Let a friend scan this code to start a secure chat with you.', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.white60, fontSize: 13)
            ),
            const SizedBox(height: 20),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              width: 220, 
              height: 220, 
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
                errorStateBuilder: (cxt, err) => Center(
                  child: Text(
                    "QR render error: $err",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: isError ? Colors.red : Colors.green
      ),
    );
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
                    // Avatar Layout with camera overlay trigger
                    _buildAvatarHeader(),
                    
                    const SizedBox(height: 15),
                    
                    Text(
                      _auth.currentUser!.email ?? "",
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    
                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: () => _showQrCodeDialog(context),
                      icon: const Icon(Icons.qr_code, color: Colors.blue),
                      label: const Text('Show My QR Code', style: TextStyle(color: Colors.blue)),
                    ),

                    const SizedBox(height: 20),

                    // Username Input Field
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter username...',
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Execution CTA Save Action Button
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

  // SUB-WIDGET BUILDERS

  Widget _buildAvatarHeader() {
    return GestureDetector(
      onTap: _pickAndUploadImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[800],
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
    );
  }
}