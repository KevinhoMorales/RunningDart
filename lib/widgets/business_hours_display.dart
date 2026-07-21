import 'package:flutter/material.dart';

import '../models/business_hours.dart';
import '../models/business_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/business_hours_helpers.dart';

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
      final slots = BusinessHoursHelpers.sortedSlots(business.operatingHours.slots);
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
          ...slots.asMap().entries.map(
            (entry) => _HoursTimelineRow(
              slot: entry.value,
              isLast: entry.key == slots.length - 1,
            ),
          ),
        ],
      );
    }

    if (business.hours.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return _LegacyHoursRow(text: business.hours);
  }
}

class _LegacyHoursRow extends StatelessWidget {
  const _LegacyHoursRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule_rounded, size: 20, color: palette.accentPrimary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body(context).copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _HoursTimelineRow extends StatelessWidget {
  const _HoursTimelineRow({
    required this.slot,
    required this.isLast,
  });

  final BusinessHoursSlot slot;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = BusinessHoursHelpers.iconForPeriod(slot.period);
    final dotColor = palette.accentPrimary;
    final line = BusinessHoursHelpers.formatSlot(slot);
    final parts = line.split(' · ');
    final primary = parts.isNotEmpty ? parts.first : line;
    final secondary = parts.length > 1 ? parts.sublist(1).join(' · ') : null;

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
                  child: Icon(icon, size: 14, color: dotColor),
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
                  Text(primary, style: AppTypography.body(context)),
                  if (secondary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: AppTypography.caption(context, color: palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
