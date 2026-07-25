import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import '../utils/user_messages.dart';

abstract final class AppSnackBar {
  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static void showError(
    BuildContext context,
    String? message, {
    String? fallback,
  }) {
    AppHaptics.alert();
    show(
      context,
      UserMessages.error(message, fallback: fallback),
    );
  }
}
