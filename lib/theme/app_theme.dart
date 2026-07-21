import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        palette: AppPalette.light,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
      );

  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppTypography.themedTextTheme(
      brightness: brightness,
      palette: palette,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.scaffoldBackground,
      extensions: [palette],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: brightness,
        primary: isDark
            ? AppConstants.primaryColorLight
            : AppConstants.primaryColor,
        onPrimary: Colors.white,
        secondary: AppConstants.secondaryColor,
        onSecondary: AppConstants.primaryColor,
        surface: palette.cardBackground,
        onSurface: palette.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        systemOverlayStyle: systemOverlayStyle(brightness),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: AppTypography.appBarWeight,
          fontSize: AppTypography.appBarSize,
          color: palette.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: palette.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: palette.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
            color: isDark
                ? AppConstants.primaryColorLight
                : AppConstants.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        labelStyle: TextStyle(color: palette.textMuted),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        titleTextStyle: textTheme.titleSmall?.copyWith(
          fontWeight: AppTypography.sectionWeight,
          fontSize: AppTypography.sectionSize,
          color: palette.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textMuted,
          fontSize: AppTypography.bodySize,
          height: 1.45,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark
            ? AppConstants.primaryColorLight
            : AppConstants.primaryColor,
        unselectedLabelColor: palette.textMuted,
        indicatorColor: isDark
            ? AppConstants.primaryColorLight
            : AppConstants.primaryColor,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontSize: AppTypography.tabLabelSize,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontSize: AppTypography.tabLabelSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 70,
        backgroundColor: palette.navBarBackground,
        indicatorColor: AppConstants.primaryColor.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontSize: AppTypography.navLabelSize,
            fontWeight: selected
                ? AppTypography.navLabelSelectedWeight
                : AppTypography.navLabelWeight,
            color: selected
                ? (isDark
                    ? AppConstants.primaryColorLight
                    : AppConstants.primaryColor)
                : palette.textMuted,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? palette.cardBackground : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          enableFeedback: false,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enableFeedback: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(64, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          enableFeedback: false,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        enableFeedback: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark
                ? AppConstants.primaryColorLight
                : AppConstants.primaryColor;
          }
          return palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppConstants.primaryColor.withValues(alpha: 0.35);
          }
          return palette.inputBorder;
        }),
      ),
    );
  }
}
