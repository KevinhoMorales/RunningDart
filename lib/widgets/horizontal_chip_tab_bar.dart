import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';

class HorizontalChipTabBar extends StatelessWidget {
  const HorizontalChipTabBar({
    super.key,
    required this.labels,
    required this.controller,
    this.icons,
  });

  final List<String> labels;
  final TabController controller;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    assert(
      icons == null || icons!.length == labels.length,
      'icons length must match labels length',
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: labels.length,
            separatorBuilder: (context, _) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _ChipTab(
                label: labels[index],
                icon: icons?[index],
                isSelected: controller.index == index,
                onTap: () {
                  AppHaptics.lightTap();
                  if (controller.index != index) {
                    controller.animateTo(index);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ChipTab extends StatelessWidget {
  const _ChipTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 36,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: icon == null ? AppSpacing.md : AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: AppConstants.brandGradientAccentColors,
                  )
                : null,
            color: isSelected ? null : palette.chipBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isSelected ? Colors.transparent : palette.inputBorder,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppConstants.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : palette.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
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
            ],
          ),
        ),
      ),
    );
  }
}
