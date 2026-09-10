import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/league_standing_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/league_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/league_helpers.dart';

/// Tarjeta compacta para el Home: puntos y posición del mes.
class LeagueHomeCard extends StatefulWidget {
  const LeagueHomeCard({super.key});

  @override
  State<LeagueHomeCard> createState() => LeagueHomeCardState();
}

class LeagueHomeCardState extends State<LeagueHomeCard> {
  LeagueStandingModel? _standing;
  int? _rank;
  bool _loading = true;
  String _periodKey = LeagueHelpers.currentPeriodKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final service = context.read<LeagueService>();
      final period = LeagueHelpers.currentPeriodKey();
      final standing =
          await service.getMyStanding(userId: user.id, periodKey: period);
      int? rank;
      if (standing != null && standing.points > 0) {
        rank = await service.rankForPoints(
          periodKey: period,
          points: standing.points,
        );
      }
      if (!mounted) return;
      setState(() {
        _periodKey = period;
        _standing = standing;
        _rank = rank;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = _standing?.points ?? 0;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: AppHaptics.wrap(() => context.push('/league')),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liga SAINTS',
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_loading)
                      Text('Cargando…', style: AppTypography.body(context))
                    else
                      Text(
                        points == 0
                            ? '${LeagueHelpers.shortPeriodLabel(_periodKey)} · Sin puntos aún'
                            : '${LeagueHelpers.shortPeriodLabel(_periodKey)} · '
                                '${_rank != null ? '#$_rank · ' : ''}'
                                '$points pts',
                        style: AppTypography.body(
                          context,
                          weight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
