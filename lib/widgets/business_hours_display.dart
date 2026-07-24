import 'package:flutter/material.dart';

import '../models/business_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/business_hours_helpers.dart';
import '../utils/constants.dart';

class BusinessHoursDisplay extends StatelessWidget {
  const BusinessHoursDisplay({
    super.key,
    required this.business,
    this.compact = false,
  });

  final BusinessModel business;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (business.hasStructuredHours) {
      final groups = BusinessHoursHelpers.groupSlotsByWeekdays(
        business.operatingHours.slots,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: context.palette.accentPrimary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Horario',
                  style: AppTypography.title(context),
                ),
              ],
            ),
          if (!compact) const SizedBox(height: AppSpacing.sm),
          ...groups.asMap().entries.map(
            (entry) => _HoursGroupRow(
              group: entry.value,
              isLast: entry.key == groups.length - 1,
            ),
          ),
        ],
      );
    }

    if (business.hours.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return _LegacyHoursRow(text: business.hours, compact: compact);
  }
}

class _LegacyHoursRow extends StatelessWidget {
  const _LegacyHoursRow({required this.text, this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? AppSpacing.sm : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryColor.withValues(alpha: 0.14),
                  AppConstants.primaryColorLight.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: AppTypography.body(
                  context,
                  weight: FontWeight.w500,
                ).copyWith(height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursGroupRow extends StatelessWidget {
  const _HoursGroupRow({
    required this.group,
    required this.isLast,
  });

  final BusinessHoursSlotGroup group;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dotColor = palette.accentPrimary;
    final weekdayLabel = BusinessHoursHelpers.formatWeekdays(group.weekdays);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: dotColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: palette.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdayLabel,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...group.slots.map(
                    (slot) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            BusinessHoursHelpers.iconForPeriod(slot.period),
                            size: 14,
                            color: palette.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              BusinessHoursHelpers.formatSlotPeriodAndTime(slot),
                              style: AppTypography.caption(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
