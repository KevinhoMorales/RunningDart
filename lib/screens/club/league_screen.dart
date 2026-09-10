import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/league_standing_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/league_provider.dart';
import '../../services/challenge_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/league_helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/challenge_progress_card.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({
    super.key,
    this.embedded = false,
  });

  /// Cuando es tab del shell, el AppBar lo pone HomeScreen.
  final bool embedded;

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LeagueProvider>().start(userId: user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>();
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;
    final periodLabel = LeagueHelpers.periodLabel(league.periodKey);

    final body = HapticRefreshIndicator(
      onRefresh: () async {
        final user = auth.user;
        if (user != null) {
          await context.read<LeagueProvider>().refresh();
          try {
            await context.read<ChallengeService>().evaluateMyProgress();
          } catch (_) {}
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            periodLabel,
            style: AppTypography.sectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ranking del mes · Comunidad y Oficial suman igual.',
            style: AppTypography.muted(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          _MyLeagueCard(
            rank: league.myRank,
            points: league.myPoints,
            participants: league.participantCount,
            isLoading: league.isLoading,
          ),
          const SizedBox(height: AppSpacing.md),
          const ChallengeProgressCard(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Top 10',
            style: AppTypography.body(context, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (league.isLoading && league.leaderboard.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (league.leaderboard.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Text(
                'Aún no hay puntos este mes. Haz check-in en un Social Run para aparecer en la liga.',
                style: AppTypography.muted(context),
              ),
            )
          else
            ...List.generate(league.leaderboard.length, (index) {
              final row = league.leaderboard[index];
              final isMe = row.userId == auth.user?.id;
              return _LeaderboardTile(
                rank: index + 1,
                standing: row,
                highlight: isMe,
              );
            }),
          if (league.myRank != null &&
              league.myRank! > 10 &&
              league.myStanding != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tu posición',
              style: AppTypography.body(context, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LeaderboardTile(
              rank: league.myRank!,
              standing: league.myStanding!,
              highlight: true,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Los puntos se reinician cada mes. El historial de check-ins se conserva.',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Liga SAINTS'),
      body: body,
    );
  }
}

class _MyLeagueCard extends StatelessWidget {
  const _MyLeagueCard({
    required this.rank,
    required this.points,
    required this.participants,
    required this.isLoading,
  });

  final int? rank;
  final int points;
  final int participants;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: isLoading && points == 0 && rank == null
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Posición',
                    value: rank == null ? '—' : '#$rank',
                  ),
                ),
                Container(width: 1, height: 40, color: palette.cardBorder),
                Expanded(
                  child: _Metric(
                    label: 'Tus puntos',
                    value: '$points',
                  ),
                ),
                Container(width: 1, height: 40, color: palette.cardBorder),
                Expanded(
                  child: _Metric(
                    label: 'En la liga',
                    value: '$participants',
                  ),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.sectionTitle(context),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption(context)),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.standing,
    this.highlight = false,
  });

  final int rank;
  final LeagueStandingModel standing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? palette.accentPrimary.withValues(alpha: 0.1)
            : palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: highlight ? palette.accentPrimary.withValues(alpha: 0.35) : palette.cardBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: AppTypography.body(context, weight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              standing.displayName,
              style: AppTypography.body(context, weight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${standing.points} pts',
            style: AppTypography.body(context, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
