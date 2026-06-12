import 'package:flutter/material.dart';

class ChatDialogs {
  // deletion confirmation dialog
  static Future<bool?> showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // edit/delete message dialog
  static void showOptionsBottomSheet({
    required BuildContext context,
    required String messageId,
    required String messageText,
    required bool isSecret,
    required Color backgroundColor,
    required Function(String, String, bool) onEditTap,
    required Function(String) onDeleteTap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (messageText.length < 1000) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.white70),
                  title: const Text(
                    'Edit Message',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onEditTap(messageId, messageText, isSecret);
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.05), height: 1),
              ],

              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteTap(messageId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}