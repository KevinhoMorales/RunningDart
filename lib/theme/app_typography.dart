import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Tipografía semántica de SAINTS.
abstract final class AppTypography {
  static const double appBarSize = 20;
  static const FontWeight appBarWeight = FontWeight.w800;

  static const double sectionSize = 17;
  static const FontWeight sectionWeight = FontWeight.w700;

  static const double titleSize = 15;
  static const FontWeight titleWeight = FontWeight.w700;

  static const double bodySize = 14;
  static const FontWeight bodyWeight = FontWeight.w500;

  static const double captionSize = 12;
  static const FontWeight captionWeight = FontWeight.w500;

  static const double navLabelSize = 11;
  static const FontWeight navLabelSelectedWeight = FontWeight.w600;
  static const FontWeight navLabelWeight = FontWeight.w500;

  static const double microSize = 11;
  static const FontWeight microWeight = FontWeight.w600;

  static const double tabLabelSize = 13;

  static TextTheme themedTextTheme({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    TextStyle sized(TextStyle? style, double size, FontWeight weight) {
      return (style ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: palette.textPrimary,
        height: 1.3,
      );
    }

    final appBar = sized(base.titleLarge, appBarSize, appBarWeight);
    final section = sized(base.titleSmall, sectionSize, sectionWeight);
    final title = sized(base.titleMedium, titleSize, titleWeight);
    final body = sized(base.bodyMedium, bodySize, bodyWeight);
    final caption = sized(base.bodySmall, captionSize, captionWeight);
    final navLabel = sized(base.labelMedium, navLabelSize, navLabelWeight);

    return base.copyWith(
      displayLarge: appBar,
      displayMedium: appBar,
      displaySmall: section,
      headlineLarge: appBar,
      headlineMedium: section,
      headlineSmall: title,
      titleLarge: appBar,
      titleMedium: title,
      titleSmall: section,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: body,
      labelMedium: navLabel,
      labelSmall: sized(base.labelSmall, microSize, microWeight),
    );
  }

  static TextStyle appBarTitle(BuildContext context, {Color? color}) {
    return _style(
      context,
      appBarSize,
      appBarWeight,
      color: color,
    );
  }

  static TextStyle sectionTitle(BuildContext context, {Color? color}) {
    return _style(
      context,
      sectionSize,
      sectionWeight,
      color: color,
    );
  }

  static TextStyle cardTitle(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) {
    return _style(
      context,
      titleSize,
      weight ?? titleWeight,
      color: color,
    );
  }

  /// Alias for card titles and primary list labels.
  static TextStyle title(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) {
    return cardTitle(context, color: color, weight: weight);
  }

  static TextStyle body(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) {
    return _style(
      context,
      bodySize,
      weight ?? bodyWeight,
      color: color,
    );
  }

  static TextStyle muted(BuildContext context, {FontWeight? weight}) {
    return body(
      context,
      color: context.palette.textMuted,
      weight: weight,
    );
  }

  static TextStyle caption(BuildContext context, {Color? color}) {
    return _style(
      context,
      captionSize,
      captionWeight,
      color: color ?? context.palette.textMuted,
    );
  }

  static TextStyle navLabel(
    BuildContext context, {
    required bool selected,
    Color? color,
  }) {
    return _style(
      context,
      navLabelSize,
      selected ? navLabelSelectedWeight : navLabelWeight,
      color: color,
    );
  }

  static TextStyle micro(BuildContext context, {Color? color}) {
    return _style(
      context,
      microSize,
      microWeight,
      color: color,
    );
  }

  /// @deprecated Use [appBarTitle] instead.
  static TextStyle headline(BuildContext context, {Color? color}) {
    return appBarTitle(context, color: color);
  }

  static TextStyle _style(
    BuildContext context,
    double size,
    FontWeight weight, {
    Color? color,
  }) {
    final palette = context.palette;
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: size,
          fontWeight: weight,
          color: color ?? palette.textPrimary,
          height: 1.3,
        );
  }
}
