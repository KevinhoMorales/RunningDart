import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/schedule_helpers.dart';

class ScheduleLocationBanner extends StatelessWidget {
  const ScheduleLocationBanner({
    super.key,
    required this.location,
    required this.venue,
  });

  final String location;
  final String venue;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accentPrimary.withValues(alpha: 0.12),
            palette.cardBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: palette.accentPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.place_rounded,
              color: palette.accentPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lugar de entrenamiento',
                  style: AppTypography.micro(context, color: palette.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: AppTypography.title(context),
                ),
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    venue,
                    style: AppTypography.caption(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scheduleLines,
    this.icon = Icons.directions_run_rounded,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<String> scheduleLines;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.isDark ? palette.elevatedCardShadow : palette.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: palette.accentPrimary,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: palette.accentPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(icon, color: palette.accentPrimary, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTypography.title(context)),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(subtitle, style: AppTypography.muted(context)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (scheduleLines.isNotEmpty) ...[
                  SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                  ...scheduleLines.asMap().entries.map(
                    (entry) => _ScheduleTimelineRow(
                      line: entry.value,
                      isLast: entry.key == scheduleLines.length - 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimelineRow extends StatelessWidget {
  const _ScheduleTimelineRow({
    required this.line,
    required this.isLast,
  });

  final String line;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parsed = ScheduleHelpers.parseLine(line);

    IconData icon;
    Color dotColor;
    if (parsed.isTimeSlot) {
      icon = Icons.calendar_today_rounded;
      dotColor = palette.accentPrimary;
    } else if (parsed.isLocation) {
      icon = Icons.place_outlined;
      dotColor = palette.textMuted;
    } else {
      icon = Icons.info_outline_rounded;
      dotColor = palette.textMuted;
    }

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
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: parsed.secondary != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed.primary,
                          style: AppTypography.body(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          parsed.secondary!,
                          style: AppTypography.caption(context).copyWith(
                            color: palette.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      parsed.primary,
                      style: AppTypography.body(context),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
