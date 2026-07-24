import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/category_style.dart';
import '../utils/helpers.dart';

class BusinessCategoryTag extends StatelessWidget {
  const BusinessCategoryTag({
    super.key,
    required this.category,
    this.compact = false,
  });

  final String category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = (compact
            ? AppTypography.micro(context, color: Colors.white)
            : AppTypography.caption(context, color: Colors.white))
        .copyWith(fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: CategoryStyle.badgeColor(category),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        Helpers.categoryLabel(category),
        style: textStyle,
      ),
    );
  }
}
