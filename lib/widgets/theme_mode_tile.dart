import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';

class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({super.key});

  String _modeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
      ThemeMode.system => 'Sistema',
    };
  }

  String _modeDescription(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Siempre en modo claro',
      ThemeMode.dark => 'Siempre en modo oscuro',
      ThemeMode.system => 'Sigue la configuración del dispositivo',
    };
  }

  IconData _modeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.settings_brightness_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final themeProvider = context.watch<ThemeProvider>();
    final selectedMode = themeProvider.themeMode;
    final isDark = themeProvider.isDarkMode(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A5F), palette.accentPrimary]
                        : [
                            palette.accentPrimary.withValues(alpha: 0.15),
                            palette.accentSecondary.withValues(alpha: 0.15),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  _modeIcon(selectedMode),
                  color: palette.accentPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: AppTypography.title(context),
                    ),
                    Text(
                      _modeDescription(selectedMode),
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ThemeMode>(
            emptySelectionAllowed: false,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(_modeLabel(ThemeMode.light)),
                icon: const Icon(Icons.light_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(_modeLabel(ThemeMode.dark)),
                icon: const Icon(Icons.dark_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(_modeLabel(ThemeMode.system)),
                icon: const Icon(Icons.settings_brightness_outlined, size: 16),
              ),
            ],
            selected: {selectedMode},
            onSelectionChanged: AppHaptics.wrapValue((selection) {
              if (selection.isNotEmpty) {
                themeProvider.setThemeMode(selection.first);
              }
            }),
          ),
        ],
      ),
    );
  }
}
