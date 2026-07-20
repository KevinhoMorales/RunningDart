import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  MapLauncherService._();

  static Future<bool> openGoogleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final query = label != null && label.trim().isNotEmpty
        ? Uri.encodeComponent('$latitude,$longitude (${label.trim()})')
        : '$latitude,$longitude';
    return _launch(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
    );
  }

  static Future<bool> openAppleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    if (!Platform.isIOS) {
      return Future.value(false);
    }

    final destination = Uri.encodeComponent(label?.trim().isNotEmpty == true
        ? label!.trim()
        : 'Destino');
    return _launch(
      Uri.parse(
        'https://maps.apple.com/?ll=$latitude,$longitude&q=$destination',
      ),
    );
  }

  static Future<bool> openWaze({
    required double latitude,
    required double longitude,
  }) {
    return _launch(
      Uri.parse(
        'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
      ),
    );
  }

  static Future<bool> _launch(Uri uri) async {
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
