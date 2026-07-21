import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.accentPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: palette.accentPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.title(context),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTypography.caption(
                            context,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.textMuted,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
