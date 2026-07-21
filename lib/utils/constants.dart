import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AppConstants {
  static const String appName = 'SAINTS';
  static const String appTagline =
      'Wellness Club · Running · Bienestar en Santo Domingo';
  static const String clubLocation = 'Santo Domingo de los Tsáchilas, Ecuador';
  static const String clubVenue = 'Jelen Tenka';
  static const String membershipTermsLabel =
      'Acepto los términos y condiciones de SAINTS Wellness Club';

  /// Placeholder URLs — reemplazar cuando estén publicadas.
  static const String termsOfServiceUrl =
      'https://saints-wellness.club/terminos-y-condiciones';
  static const String privacyPolicyUrl =
      'https://saints-wellness.club/politica-de-privacidad';

  static const String officialMembershipPriceLabel = r'$5 lanzamiento 2026';

  static const String devLokosEnterpriseUrl =
      'https://devlokos.com/empresarial';
  static const String devLokosEnterpriseName = 'DevLokos Enterprise';
  static const String devLokosLogoAsset = 'assets/images/devlokos_logo.png';

  static const String notificationChannelId = 'saints_alerts';
  static const String notificationChannelName = 'Alertas SAINTS';
  static const String notificationChannelDescription =
      'Nuevas marcas aliadas y eventos de la comunidad';

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

  /// Credencial digital: fondo oscuro neutro con acento verde sutil (no bloque verde).
  static List<Color> credentialCardGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [Color(0xFF0D1117), Color(0xFF161B22)]
        : const [Color(0xFF1A1D26), Color(0xFF2A3140)];
  }

  static Color credentialAccentColor(Brightness brightness) {
    return brightness == Brightness.dark ? primaryColorLight : accentColor;
  }

  /// Centro por defecto del mapa (Santo Domingo de los Tsáchilas).
  static const LatLng defaultMapCenter = LatLng(-0.1807, -78.4678);
}
