import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:secure_messenger/services/encryption_service.dart';

class AudioBubble extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool msgIsSecret;
  final bool isMe;

  const AudioBubble({
    super.key,
    required this.data,
    required this.msgIsSecret,
    required this.isMe,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInitialized = false;
  String _finalAudioBase64 = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _prepareAudioData();

    // Kuulame heli seisundite muutusi
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero; // Toob täpi algusesse tagasi
          _isPlaying = false;        // Muudab nupu uuesti Play ikooniks
        });
      }
    });
  }

  void _prepareAudioData() {
    String rawAudioBase64 = widget.data['message'] ?? '';
    
    if (widget.msgIsSecret && rawAudioBase64.isNotEmpty) {
      try {
        _finalAudioBase64 = EncryptionService.decryptText(rawAudioBase64);
      } catch (e) {
        debugPrint("Error decrypting audio: $e");
      }
    } else {
      _finalAudioBase64 = rawAudioBase64;
    }
  }

 Future<void> _playPauseAudio() async {
    if (_isPlaying) {
      // Kui mängib, paneme pausi peale
      await _audioPlayer.pause();
    } else {
      if (_finalAudioBase64.isEmpty) return;

      try {
        // LAHENDUS: Söödame baidid pleierile ALATI uuesti ette, 
        // kui alustatakse mängimist nullist (asukoht on alguses).
        if (_position == Duration.zero || !_isInitialized) {
          final Uint8List audioBytes = base64Decode(_finalAudioBase64);
          await _audioPlayer.setSource(BytesSource(audioBytes));
          _isInitialized = true;
        }
        
        // Käivitame heli
        await _audioPlayer.resume();
      } catch (e) {
        debugPrint("Error playing audio: $e");
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      width: 220,
      child: Row(
        children: [
          // Play/Pause nupp
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white,
              size: 36,
            ),
            onPressed: _playPauseAudio,
          ),
          // Progressiriba ja aeg
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() > 0 
                        ? _duration.inMilliseconds.toDouble() 
                        : 1.0,
                    value: _position.inMilliseconds.toDouble(),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                    onChanged: (value) async {
                      final position = Duration(milliseconds: value.toInt());
                      await _audioPlayer.seek(position);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _formatDuration(_position),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}