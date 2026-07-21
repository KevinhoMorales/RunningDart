import 'package:flutter/material.dart';

import '../models/membership_modality.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/constants.dart';

class ModalityChip extends StatelessWidget {
  const ModalityChip({
    super.key,
    required this.modality,
    this.compact = false,
    this.onDarkBackground = false,
  });

  final MembershipModality modality;
  final bool compact;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: compact ? 28 : 32,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: !onDarkBackground && modality == MembershipModality.proTeam
            ? const LinearGradient(
                colors: AppConstants.brandGradientAccentColors,
              )
            : null,
        color: onDarkBackground
            ? Colors.white.withValues(alpha: 0.12)
            : modality == MembershipModality.proTeam
                ? null
                : palette.chipBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: onDarkBackground
              ? Colors.white.withValues(alpha: 0.22)
              : modality == MembershipModality.proTeam
                  ? Colors.transparent
                  : palette.inputBorder,
        ),
      ),
      child: Text(
        modality.displayName,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: AppTypography.caption(
          context,
          color: onDarkBackground || modality == MembershipModality.proTeam
              ? Colors.white
              : palette.textPrimary,
        ).copyWith(fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}
