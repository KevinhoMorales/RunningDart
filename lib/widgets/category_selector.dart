import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/category_style.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.categories = const [],
    this.enabled = true,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final List<String> categories;
  final bool enabled;

  List<String> get _categories {
    if (categories.isNotEmpty) {
      return categories.where((category) => category != 'Todos').toList();
    }
    return AppConstants.businessCategories
        .where((category) => category != 'Todos')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = _categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Categoría',
          style: AppTypography.title(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Elige el tipo de negocio al que pertenece la marca.',
          style: AppTypography.muted(context),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.35,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final category = items[index];
            return _CategoryTile(
              category: category,
              label: Helpers.categoryLabel(category),
              isSelected: selectedCategory == category,
              enabled: enabled,
              onTap: () => onCategorySelected(category),
            );
          },
        ),
        if (selectedCategory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: palette.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    CategoryStyle.iconFor(selectedCategory),
                    size: 18,
                    color: palette.accentPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${Helpers.categoryLabel(selectedCategory)} seleccionado',
                      style: AppTypography.caption(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String category;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accentColor = CategoryStyle.gradientFor(category).first;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? AppHaptics.wrap(onTap) : null,
          enableFeedback: false,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? palette.accentPrimary.withValues(alpha: 0.1)
                  : palette.chipBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isSelected
                    ? palette.accentPrimary
                    : palette.inputBorder,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? palette.cardShadow : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.accentPrimary
                        : accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    CategoryStyle.iconFor(category),
                    size: 20,
                    color: isSelected ? Colors.white : accentColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      context,
                      color: isSelected
                          ? palette.textPrimary
                          : palette.textMuted,
                    ).copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: palette.accentPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
