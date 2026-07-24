import 'package:flutter/material.dart';

import '../utils/constants.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.scaffoldBackground,
    required this.cardBackground,
    required this.textPrimary,
    required this.textMuted,
    required this.gradientStart,
    required this.gradientEnd,
    required this.glassBackground,
    required this.glassBorder,
    required this.inputFill,
    required this.inputBorder,
    required this.navBarBackground,
    required this.chipBackground,
    required this.skeletonColor,
    required this.shadowColor,
    required this.iconButtonBackground,
    required this.infoBannerBackground,
    required this.infoBannerBorder,
    required this.qrBackground,
    required this.qrScanSurface,
    required this.cardBorder,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.bottomSheetBackground,
    required this.navBarShadow,
  });

  final Color scaffoldBackground;
  final Color cardBackground;
  final Color textPrimary;
  final Color textMuted;
  final Color gradientStart;
  final Color gradientEnd;
  final Color glassBackground;
  final Color glassBorder;
  final Color inputFill;
  final Color inputBorder;
  final Color navBarBackground;
  final Color chipBackground;
  final Color skeletonColor;
  final Color shadowColor;
  final Color iconButtonBackground;
  final Color infoBannerBackground;
  final Color infoBannerBorder;
  final Color qrBackground;
  final Color qrScanSurface;
  final Color cardBorder;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color bottomSheetBackground;
  final Color navBarShadow;

  bool get isDark => scaffoldBackground.computeLuminance() < 0.2;

  static const light = AppPalette(
    scaffoldBackground: AppConstants.surfaceColor,
    cardBackground: Colors.white,
    textPrimary: AppConstants.textPrimary,
    textMuted: AppConstants.textMuted,
    gradientStart: AppConstants.backgroundGradientStart,
    gradientEnd: AppConstants.backgroundGradientEnd,
    glassBackground: Color(0xEBFFFFFF),
    glassBorder: Color(0xCCFFFFFF),
    inputFill: Colors.white,
    inputBorder: Color(0xFFE5E7EB),
    navBarBackground: Colors.white,
    chipBackground: Colors.white,
    skeletonColor: Color(0xFFD1D5DB),
    shadowColor: AppConstants.cardShadow,
    iconButtonBackground: Colors.white,
    infoBannerBackground: Color(0x14315132),
    infoBannerBorder: Color(0x26315132),
    qrBackground: Colors.white,
    qrScanSurface: Colors.white,
    cardBorder: Color(0xFFE5E7EB),
    accentPrimary: AppConstants.primaryColor,
    accentSecondary: AppConstants.secondaryColor,
    bottomSheetBackground: Colors.white,
    navBarShadow: Color(0x0F000000),
  );

  static const dark = AppPalette(
    scaffoldBackground: Color(0xFF0D1117),
    cardBackground: Color(0xFF161B22),
    textPrimary: Color(0xFFF0F3F6),
    textMuted: Color(0xFF9CA3AF),
    gradientStart: Color(0xFF0F1A12),
    gradientEnd: Color(0xFF121A14),
    glassBackground: Color(0xE6161B22),
    glassBorder: Color(0x33FFFFFF),
    inputFill: Color(0xFF1C2330),
    inputBorder: Color(0xFF2D3748),
    navBarBackground: Color(0xFF161B22),
    chipBackground: Color(0xFF1C2330),
    skeletonColor: Color(0xFF2D3748),
    shadowColor: Color(0x40000000),
    iconButtonBackground: Color(0xFF1C2330),
    infoBannerBackground: Color(0x266FA772),
    infoBannerBorder: Color(0x336FA772),
    qrBackground: Color(0xFF1C2330),
    qrScanSurface: Colors.white,
    cardBorder: Color(0xFF2D3748),
    accentPrimary: AppConstants.primaryColorLight,
    accentSecondary: AppConstants.secondaryColor,
    bottomSheetBackground: Color(0xFF161B22),
    navBarShadow: Color(0x33000000),
  );

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.7),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Sombra neutra para icon buttons en app bar (sin tinte de marca).
  List<BoxShadow> get iconButtonShadow => [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x12000000),
          blurRadius: isDark ? 4 : 6,
          offset: const Offset(0, 2),
        ),
      ];

  List<BoxShadow> get elevatedCardShadow {
    final shadows = <BoxShadow>[
      BoxShadow(
        color: const Color(0x12000000),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: shadowColor.withValues(alpha: isDark ? 0.8 : 0.55),
        blurRadius: 16,
        offset: const Offset(0, 6),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: const Color(0x18000000),
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: -4,
      ),
    ];

    if (isDark) {
      shadows.insert(
        0,
        const BoxShadow(
          color: Color(0x12FFFFFF),
          blurRadius: 0,
          offset: Offset(0, 1),
          spreadRadius: 0,
        ),
      );
    }

    return shadows;
  }

  @override
  AppPalette copyWith({
    Color? scaffoldBackground,
    Color? cardBackground,
    Color? textPrimary,
    Color? textMuted,
    Color? gradientStart,
    Color? gradientEnd,
    Color? glassBackground,
    Color? glassBorder,
    Color? inputFill,
    Color? inputBorder,
    Color? navBarBackground,
    Color? chipBackground,
    Color? skeletonColor,
    Color? shadowColor,
    Color? iconButtonBackground,
    Color? infoBannerBackground,
    Color? infoBannerBorder,
    Color? qrBackground,
    Color? qrScanSurface,
    Color? cardBorder,
    Color? accentPrimary,
    Color? accentSecondary,
    Color? bottomSheetBackground,
    Color? navBarShadow,
  }) {
    return AppPalette(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      navBarBackground: navBarBackground ?? this.navBarBackground,
      chipBackground: chipBackground ?? this.chipBackground,
      skeletonColor: skeletonColor ?? this.skeletonColor,
      shadowColor: shadowColor ?? this.shadowColor,
      iconButtonBackground: iconButtonBackground ?? this.iconButtonBackground,
      infoBannerBackground: infoBannerBackground ?? this.infoBannerBackground,
      infoBannerBorder: infoBannerBorder ?? this.infoBannerBorder,
      qrBackground: qrBackground ?? this.qrBackground,
      qrScanSurface: qrScanSurface ?? this.qrScanSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      bottomSheetBackground:
          bottomSheetBackground ?? this.bottomSheetBackground,
      navBarShadow: navBarShadow ?? this.navBarShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      navBarBackground:
          Color.lerp(navBarBackground, other.navBarBackground, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      skeletonColor: Color.lerp(skeletonColor, other.skeletonColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      iconButtonBackground:
          Color.lerp(iconButtonBackground, other.iconButtonBackground, t)!,
      infoBannerBackground:
          Color.lerp(infoBannerBackground, other.infoBannerBackground, t)!,
      infoBannerBorder:
          Color.lerp(infoBannerBorder, other.infoBannerBorder, t)!,
      qrBackground: Color.lerp(qrBackground, other.qrBackground, t)!,
      qrScanSurface: Color.lerp(qrScanSurface, other.qrScanSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      bottomSheetBackground:
          Color.lerp(bottomSheetBackground, other.bottomSheetBackground, t)!,
      navBarShadow: Color.lerp(navBarShadow, other.navBarShadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
