import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AppConstants {
  static const String appName = 'SAINTS';
  static const String appTagline = 'Tu comunidad, tus beneficios exclusivos';

  static const String devLokosEnterpriseUrl =
      'https://devlokos.com/empresarial';
  static const String devLokosEnterpriseName = 'DevLokos Enterprise';
  static const String devLokosLogoAsset = 'assets/images/devlokos_logo.png';

  static const String notificationChannelId = 'saints_alerts';
  static const String notificationChannelName = 'Alertas SAINTS';
  static const String notificationChannelDescription =
      'Nuevos negocios y eventos de la comunidad';

  static const String fcmTopicNewBusinesses = 'saints_new_businesses';
  static const String fcmTopicNewEvents = 'saints_new_events';

  static const String pushNotificationsEnabledKey =
      'push_notifications_enabled';

  static const int minPasswordLength = 6;

  static const List<String> businessCategories = [
    'Todos',
    'café',
    'restaurante',
    'gimnasio',
    'retail',
    'salud',
  ];

  static const Color primaryColor = Color(0xFF1C4524);
  static const Color primaryColorLight = Color(0xFF4A9A5C);
  static const Color secondaryColor = Color(0xFFFFFFFF);
  static const Color accentColor = Color(0xFF3D8B4E);

  static const Color surfaceColor = Color(0xFFF5F7F5);
  static const Color backgroundGradientStart = Color(0xFFE8EFE9);
  static const Color backgroundGradientEnd = Color(0xFFF5F7F5);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color cardShadow = Color(0x1A1C4524);

  static const List<Color> brandGradientColors = [
    primaryColor,
    secondaryColor,
  ];

  static const List<Color> brandGradientAccentColors = [
    primaryColor,
    primaryColorLight,
  ];

  static List<Color> brandGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [primaryColorLight, primaryColor]
        : brandGradientColors;
  }

  /// Gradiente del header de perfil: mantiene contraste con texto blanco en light mode.
  static List<Color> profileCardGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [primaryColorLight, primaryColor]
        : brandGradientAccentColors;
  }

  /// Centro por defecto del mapa (Quito, Ecuador).
  static const LatLng defaultMapCenter = LatLng(-0.1807, -78.4678);
}
