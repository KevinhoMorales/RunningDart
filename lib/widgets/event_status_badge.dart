import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/helpers.dart';

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({
    super.key,
    required this.eventDate,
    this.referenceDate,
  });

  final DateTime eventDate;
  final DateTime? referenceDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = Helpers.eventStatusLabel(eventDate, referenceDate);
    final isPast = Helpers.isEventPast(eventDate, referenceDate);
    final isUrgent = Helpers.eventStatusIsUrgent(eventDate, referenceDate);

    final Color color;
    if (isPast) {
      color = palette.textMuted;
    } else if (isUrgent) {
      color = palette.accentSecondary;
    } else {
      color = palette.accentPrimary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        label,
        style: AppTypography.micro(context, color: color),
      ),
    );
  }
}
