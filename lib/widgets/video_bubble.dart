import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:secure_messenger/services/encryption_service.dart';

class VideoBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool msgIsSecret;

  const VideoBubble({
    super.key,
    required this.data,
    required this.msgIsSecret,
  });

  @override
  Widget build(BuildContext context) {
    String rawVideoBase64 = data['message'] ?? '';

    // Kui on Secret Chat, dekrüpteerime video Base64 koodi enne esitamist
    if (msgIsSecret && rawVideoBase64.isNotEmpty) {
      try {
        // Kuna EncryptionService on sul eraldi klassis, impordi see vajadusel faili algusesse
        rawVideoBase64 = EncryptionService.decryptText(rawVideoBase64); 
      } catch (e) {
        debugPrint("Error decrypting video: $e");
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Failed to decrypt video', style: TextStyle(color: Colors.white60)),
        );
      }
    }

    if (rawVideoBase64.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Empty video data', style: TextStyle(color: Colors.white60)),
      );
    }

    return _Base64VideoPlayer(base64String: rawVideoBase64);
  }
}

// Hoiame pleieri privaatse klassina (alalkriipsuga _), sest keegi väljastpoolt seda otse ei kasuta
class _Base64VideoPlayer extends StatefulWidget {
  final String base64String;

  const _Base64VideoPlayer({required this.base64String});

  @override
  State<_Base64VideoPlayer> createState() => _Base64VideoPlayerState();
}

class _Base64VideoPlayerState extends State<_Base64VideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  File? _tempVideoFile;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final Uint8List videoBytes = base64Decode(widget.base64String);
      _tempVideoFile = await File(
        '${Directory.systemTemp.path}/video_${DateTime.now().microsecondsSinceEpoch}.mp4',
      ).writeAsBytes(videoBytes, flush: true);
      _controller = VideoPlayerController.file(_tempVideoFile!);
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting video: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    _tempVideoFile?.deleteSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox(
        width: 200,
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, color: Colors.white60),
              SizedBox(height: 4),
              Text('Cannot play video', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const SizedBox(
        width: 200,
        height: 150,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        color: Colors.black26,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black45,
                  child: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}