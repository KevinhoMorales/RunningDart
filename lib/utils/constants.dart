import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_environment.dart';

class AppConstants {
  static const String appName = 'SAINTS';
  static const String appTagline =
      'Wellness Club · Running · Bienestar en Santo Domingo';
  static const String clubLocation = 'Santo Domingo de los Tsáchilas, Ecuador';
  static const String clubVenue = 'Jelen Tenka';
  static const String membershipTermsLabel =
      'Acepto los términos y condiciones de SAINTS Wellness Club';

  static const String termsOfServiceUrl =
      'https://kevinhomorales.notion.site/T-rminos-y-Condiciones-3a9a9ccd42b9809aa0e8cfce72ae420f';
  static const String privacyPolicyUrl =
      'https://kevinhomorales.notion.site/Pol-ticas-de-privacidad-3a9a9ccd42b980abbd24da0710aeb9cf';

  static const String officialMembershipPriceLabel = r'$5 lanzamiento 2026';

  static const String supportWhatsApp = '+593984126959';
  static const String supportWhatsAppDisplay = '+593 98 412 6959';
  static const String supportWhatsAppDefaultMessage =
      'Hola, tengo una consulta sobre SAINTS.';

  static const String communityWhatsAppGroupUrl =
      'https://chat.whatsapp.com/JNSEYSbOtelsoIPdvOibh';
  static const String proTeamWhatsAppGroupUrl =
      'https://chat.whatsapp.com/lbs975Y30T0HsJQHMnSDR';

  static const String devLokosEnterpriseUrl =
      'https://devlokos.com/empresarial';
  static const String devLokosEnterpriseName = 'DevLokos Enterprise';
  static const String devLokosLogoAsset = 'assets/images/devlokos_logo.png';

  static const String notificationChannelId = 'saints_alerts';
  static const String notificationChannelName = 'Alertas SAINTS';
  static const String notificationChannelDescription =
      'Nuevas marcas aliadas y eventos de la comunidad';

  /// Los topics llevan sufijo de ambiente para que crear una marca de prueba en
  /// dev no dispare un push a todos los usuarios de producción.
  static String fcmTopicNewBusinesses(AppEnvironment environment) =>
      '${_legacyFcmTopicNewBusinesses}_${environment.name}';

  static String fcmTopicNewEvents(AppEnvironment environment) =>
      '${_legacyFcmTopicNewEvents}_${environment.name}';

  static const String _legacyFcmTopicNewBusinesses = 'saints_new_businesses';
  static const String _legacyFcmTopicNewEvents = 'saints_new_events';

  /// Topics sin sufijo usados antes de separar los ambientes. Se conservan solo
  /// para desuscribir a los dispositivos que ya venían suscritos a ellos.
  static const List<String> legacyFcmTopics = [
    _legacyFcmTopicNewBusinesses,
    _legacyFcmTopicNewEvents,
  ];

  static const String legacyFcmTopicsClearedKey = 'legacy_fcm_topics_cleared';

  static const String pushNotificationsEnabledKey =
      'push_notifications_enabled';
  static const String notificationsOnboardingCompletedKey =
      'notifications_onboarding_completed';
  static const String notificationsOnboardingPendingKey =
      'notifications_onboarding_pending';

  static const String remoteConfigMinVersionKey = 'running_dart_version';
  static const String iosAppStoreUrl =
      'https://apps.apple.com/us/app/saints/id6792610093';
  static const String androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.devlokos.runningdart';
  static const String appDownloadUrl = 'https://onelink.to/saints';

  static const int minPasswordLength = 6;

  static const List<String> businessCategories = [
    'Todos',
    'café',
    'restaurante',
    'gimnasio',
    'retail',
    'salud',
    'lifestyle',
    'servicios',
  ];

  static const Color primaryColor = Color(0xFF315132);
  static const Color primaryColorLight = Color(0xFF6FA772);
  static const Color secondaryColor = Color(0xFFFFFFFF);
  static const Color accentColor = Color(0xFF315132);

  static const Color surfaceColor = Color(0xFFF5F7F5);
  static const Color backgroundGradientStart = Color(0xFFE9F4EC);
  static const Color backgroundGradientEnd = Color(0xFFF4F8F5);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color cardShadow = Color(0x1A315132);

  static const List<Color> brandGradientColors = [
    primaryColor,
    primaryColor,
  ];

  static const List<Color> brandGradientAccentColors = [
    primaryColor,
    primaryColor,
  ];

  static List<Color> brandGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [primaryColorLight, primaryColorLight]
        : brandGradientColors;
  }

  /// Header de perfil: verde solido, adaptado a light/dark.
  static List<Color> profileCardGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [primaryColorLight, primaryColorLight]
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
  static const LatLng defaultMapCenter = LatLng(-0.2522, -79.1754);
}
