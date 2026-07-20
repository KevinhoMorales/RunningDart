import 'package:flutter/material.dart';

import '../models/news_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/helpers.dart';
import 'event_status_badge.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.news,
    required this.onTap,
    this.showDraftBadge = false,
    this.showFinishedBadge = false,
  });

  final NewsModel news;
  final VoidCallback onTap;
  final bool showDraftBadge;
  final bool showFinishedBadge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPast = Helpers.isEventPast(news.eventDate);
    final showStatusBadge = showFinishedBadge || !isPast;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: palette.cardBorder),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      news.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: palette.skeletonColor,
                        child: Icon(
                          Icons.event_rounded,
                          color: palette.textMuted,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showStatusBadge)
                            EventStatusBadge(eventDate: news.eventDate),
                          if (showDraftBadge && !news.isPublished)
                            _Badge(
                              label: 'Borrador',
                              color: palette.accentPrimary,
                            ),
                        ],
                      ),
                      if (showStatusBadge ||
                          (showDraftBadge && !news.isPublished))
                        const SizedBox(height: AppSpacing.sm),
                      Text(
                        news.title,
                        style: AppTypography.cardTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        news.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.muted(context).copyWith(height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: palette.accentPrimary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            Helpers.formatDate(news.eventDate),
                            style: AppTypography.caption(
                              context,
                              color: palette.accentPrimary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (news.location != null &&
                              news.location!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.md),
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: palette.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                news.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
