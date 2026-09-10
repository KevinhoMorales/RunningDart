import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/monthly_challenge_model.dart';
import '../../services/challenge_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/league_helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class AdminChallengesTab extends StatelessWidget {
  const AdminChallengesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChallengeService>();
    final palette = context.palette;

    return StreamBuilder<List<MonthlyChallengeModel>>(
      stream: service.watchAllChallenges(),
      builder: (context, snapshot) {
        final challenges = snapshot.data ?? const <MonthlyChallengeModel>[];
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return HapticRefreshIndicator(
          onRefresh: () async {},
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Reto mensual',
                        style: AppTypography.sectionTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Define la meta, la insignia digital y los Reward Spots '
                        '(premios físicos). Completar el reto da insignia a todos; '
                        'los spots se asignan entre finalistas por posición en la Liga.',
                        style: AppTypography.muted(context),
                      ),
                    ],
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (challenges.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateCard(
                    icon: Icons.flag_outlined,
                    message: 'Sin retos todavía',
                    subtitle: 'Crea el reto del mes con el botón +.',
                    actionLabel: 'Nuevo reto',
                    onAction: () => context.push('/admin/challenges/new'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: challenges.length,
                    separatorBuilder: (_, i) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return Material(
                        color: palette.cardBackground,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        child: InkWell(
                          onTap: AppHaptics.wrap(
                            () => context.push(
                              '/admin/challenges/${challenge.id}',
                            ),
                          ),
                          enableFeedback: false,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        challenge.name,
                                        style: AppTypography.body(
                                          context,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      challenge.status.displayName,
                                      style: AppTypography.caption(
                                        context,
                                        color: challenge.isActive
                                            ? palette.accentPrimary
                                            : palette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  challenge.periodKey != null
                                      ? LeagueHelpers.periodLabel(
                                          challenge.periodKey!,
                                        )
                                      : challenge.goalSummary,
                                  style: AppTypography.caption(
                                    context,
                                    color: palette.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${challenge.goalSummary} · '
                                  '${challenge.rewardSpots} Reward Spots · '
                                  '+${challenge.completionPoints} pts',
                                  style: AppTypography.caption(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
