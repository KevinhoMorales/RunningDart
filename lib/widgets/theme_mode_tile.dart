import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final themeProvider = context.watch<ThemeProvider>();
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
      child: Row(
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
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
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
                  'modo oscuro',
                  style: AppTypography.title(context),
                ),
                Text(
                  isDark ? 'Activado' : 'Desactivado',
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDark,
            onChanged: themeProvider.toggleDarkMode,
          ),
        ],
      ),
    );
  }
}
