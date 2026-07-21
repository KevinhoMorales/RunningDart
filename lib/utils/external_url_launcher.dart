import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';
import 'helpers.dart';

Future<bool> launchExternalUrl(String url) async {
  final trimmed = url.trim();
  if (!Helpers.isValidHttpUrl(trimmed)) {
    return false;
  }

  final uri = Uri.parse(trimmed);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchExternalUrlFromContext(
  BuildContext context,
  String url,
) async {
  final launched = await launchExternalUrl(url);
  if (!launched && context.mounted) {
    AppSnackBar.show(context, 'No se pudo abrir el enlace. Intenta de nuevo.');
  }
}
