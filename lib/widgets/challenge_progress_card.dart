import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/challenge_progress_model.dart';
import '../models/monthly_challenge_model.dart';
import '../providers/auth_provider.dart';
import '../services/challenge_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';

/// Progreso del reto activo — pensado para Liga / Home.
class ChallengeProgressCard extends StatefulWidget {
  const ChallengeProgressCard({super.key, this.compact = false});

  final bool compact;

  @override
  State<ChallengeProgressCard> createState() => ChallengeProgressCardState();
}

class ChallengeProgressCardState extends State<ChallengeProgressCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateQuietly());
  }

  Future<void> reload() => _evaluateQuietly();

  Future<void> _evaluateQuietly() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      await context.read<ChallengeService>().evaluateMyProgress();
    } catch (_) {
      // Silencioso: la UI sigue con el stream de progreso.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final service = context.read<ChallengeService>();
    final palette = context.palette;

    return StreamBuilder<MonthlyChallengeModel?>(
      stream: service.watchActiveChallenge(),
      builder: (context, challengeSnap) {
        final challenge = challengeSnap.data;
        if (challenge == null) {
          if (widget.compact) {
            return const SizedBox.shrink();
          }
          return const SizedBox.shrink();
        }

        return StreamBuilder<ChallengeProgressModel?>(
          stream: service.watchMyProgress(
            challengeId: challenge.id,
            userId: user.id,
          ),
          builder: (context, progressSnap) {
            final progress = progressSnap.data;
            final current = progress?.currentValue ?? 0;
            final target = progress?.goalTarget ?? challenge.goalTarget;
            final fraction = target <= 0
                ? 0.0
                : (current / target).clamp(0.0, 1.0);
            final completed = progress?.completed == true;

            return Material(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: InkWell(
                onTap: AppHaptics.wrap(_evaluateQuietly),
                enableFeedback: false,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            completed
                                ? Icons.verified_rounded
                                : Icons.flag_outlined,
                            color: palette.accentPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              challenge.name,
                              style: AppTypography.body(
                                context,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (completed)
                            Text(
                              'Completado',
                              style: AppTypography.caption(
                                context,
                                color: palette.accentPrimary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        completed
                            ? 'Insignia: ${challenge.badge.name}'
                                '${progress?.isWinner == true ? ' · Reward Spot' : ''}'
                            : challenge.goalSummary,
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          backgroundColor: palette.chipBackground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$current / $target'
                        '${challenge.rewardSpots > 0 ? ' · ${challenge.rewardSpots} spots' : ''}',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
