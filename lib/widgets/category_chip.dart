import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/category_style.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.category,
    this.palette,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final String? category;

  /// Paleta explicita. Util cuando el chip vive dentro de un
  /// `SliverPersistentHeader`, cuyo subarbol no re-resuelve `Theme` de forma
  /// fiable; pasando la paleta ya resuelta se evita que el fondo quede con la
  /// paleta light al iniciar en dark mode.
  final AppPalette? palette;

  @override
  Widget build(BuildContext context) {
    final palette = this.palette ?? context.palette;
    final selectedColor = category != null && category != 'Todos'
        ? CategoryStyle.solidColor(category!)
        : palette.accentPrimary;

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
              color: isSelected ? selectedColor : palette.chipBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isSelected ? Colors.transparent : palette.inputBorder,
              ),
              // La sombra toma el color del chip: con el verde de marca fijo
              // desentonaba en las categorías cálidas.
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: selectedColor.withValues(alpha: 0.3),
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
