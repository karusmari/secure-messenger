import 'package:flutter/material.dart';

class TypingIndicator {
  static Widget build({required String receiverEmail, required bool isTyping}) {
    if (!isTyping) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "${receiverEmail.split('@')[0]} is typing...",
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}