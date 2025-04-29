import 'package:flutter/material.dart';

/// A utility class for showing confirmation dialogs
class ConfirmationDialog {
  /// Shows a confirmation dialog with the given title and message
  /// Returns true if the user confirms, false otherwise
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color? confirmColor,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: confirmColor ?? (isDestructive ? Colors.red : null),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result == true;
  }
}
