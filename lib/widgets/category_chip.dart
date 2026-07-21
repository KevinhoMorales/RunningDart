import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/category_style.dart';
import '../utils/constants.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.category,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final gradient = category != null && category != 'Todos'
        ? CategoryStyle.gradient(category!)
        : const LinearGradient(
            colors: AppConstants.brandGradientAccentColors,
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: AppHaptics.wrap(onSelected),
          enableFeedback: false,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              gradient: isSelected ? gradient : null,
              color: isSelected ? null : palette.chipBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isSelected ? Colors.transparent : palette.inputBorder,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppConstants.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: AppTypography.caption(
                context,
                color: isSelected ? Colors.white : palette.textMuted,
              ).copyWith(
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
