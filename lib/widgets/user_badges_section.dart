import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/challenge_progress_model.dart';
import '../services/challenge_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/league_helpers.dart';

class UserBadgesSection extends StatelessWidget {
  const UserBadgesSection({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChallengeService>();
    final palette = context.palette;

    return StreamBuilder<List<UserBadgeModel>>(
      stream: service.watchUserBadges(userId),
      builder: (context, snapshot) {
        final badges = snapshot.data ?? const <UserBadgeModel>[];
        if (badges.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Insignias',
              style: AppTypography.body(context, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...badges.map(
              (badge) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.cardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: palette.accentPrimary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.badgeName,
                            style: AppTypography.body(
                              context,
                              weight: FontWeight.w700,
                            ),
                          ),
                          if (badge.periodKey != null)
                            Text(
                              LeagueHelpers.periodLabel(badge.periodKey!),
                              style: AppTypography.caption(
                                context,
                                color: palette.textMuted,
                              ),
                            ),
                          if (badge.badgeDescription != null &&
                              badge.badgeDescription!.isNotEmpty)
                            Text(
                              badge.badgeDescription!,
                              style: AppTypography.caption(context),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
